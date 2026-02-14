local M = {}
local uv = vim.uv or vim.loop

-- Internal state: true for ASCII mode, false for Chinese mode
local rime_last_state = true

--- Query current Rime ASCII state asynchronously
--- @param callback fun(is_ascii: boolean)
function M.get_rime_state(callback)
  local stdout = uv.new_pipe(false)
  local safe_callback = vim.schedule_wrap(callback)
  local output = ""
  local callback_invoked = false

  -- Add timeout protection (500ms)
  local timeout_timer = uv.new_timer()

  local function invoke_callback_once(is_ascii)
    if not callback_invoked then
      callback_invoked = true
      if timeout_timer then
        timeout_timer:stop()
        timeout_timer:close()
      end
      safe_callback(is_ascii)
    end
  end

  -- The options table requires explicit fields to satisfy LSP [missing-fields]
  local options = {
    args = { "--user", "call", "org.fcitx.Fcitx5", "/rime", "org.fcitx.Fcitx.Rime1", "IsAsciiMode" },
    stdio = { nil, stdout, nil },
    detached = false,
    hide = true,
  }

  local handle, pid_or_err
  local spawn_handle -- Capture handle for closure
  handle, pid_or_err = uv.spawn("busctl", options, function(_, _)
    if spawn_handle and not spawn_handle:is_closing() then
      spawn_handle:close()
    end
    -- If process exits without data, assume ASCII mode
    if not callback_invoked then
      invoke_callback_once(true)
    end
  end)
  spawn_handle = handle

  -- Error handling for process spawning
  if not handle then
    vim.schedule(function()
      vim.notify("Rime-DBus: Failed to spawn busctl: " .. tostring(pid_or_err), vim.log.levels.ERROR)
    end)
    if stdout and not stdout:is_closing() then
      stdout:close()
    end
    return
  end

  -- Set timeout
  if timeout_timer then
    timeout_timer:start(500, 0, function()
      if stdout and not stdout:is_closing() then
        stdout:read_stop()
        stdout:close()
      end
      if spawn_handle and not spawn_handle:is_closing() then
        spawn_handle:kill(15)    -- SIGTERM
      end
      invoke_callback_once(true) -- Fallback to ASCII mode on timeout
    end)
  end

  if stdout then
    stdout:read_start(function(err, data)
      if err then
        if not stdout:is_closing() then
          stdout:read_stop()
          stdout:close()
        end
        return
      end

      if data then
        output = output .. data
      else
        -- EOF reached
        if not stdout:is_closing() then
          stdout:read_stop()
          stdout:close()
        end
        local is_ascii = output:find("true") ~= nil
        invoke_callback_once(is_ascii)
      end
    end)
  end
end

--- Set Rime ASCII state asynchronously
--- @param target_state boolean
local function set_rime_state(target_state)
  local options = {
    args = {
      "--user", "call", "org.fcitx.Fcitx5", "/rime",
      "org.fcitx.Fcitx.Rime1", "SetAsciiMode", "b",
      target_state and "true" or "false"
    },
    detached = true,
    hide = true,
  }

  local handle, pid_or_err
  local spawn_handle -- Capture handle for closure
  handle, pid_or_err = uv.spawn("busctl", options, function(_, _)
    if spawn_handle and not spawn_handle:is_closing() then
      spawn_handle:close()
    end
  end)
  spawn_handle = handle

  -- Error handling for spawn failure
  if not handle then
    vim.schedule(function()
      vim.notify("Rime-DBus: Failed to set state: " .. tostring(pid_or_err), vim.log.levels.WARN)
    end)
  end
end

--- Save state and force ASCII when leaving Insert mode
function M.save_and_set_ascii()
  M.get_rime_state(function(current_is_ascii)
    rime_last_state = current_is_ascii
    if not current_is_ascii then
      set_rime_state(true)
    end
  end)
end

--- Restore state when entering Insert mode
function M.restore_state()
  M.get_rime_state(function(current_is_ascii)
    if current_is_ascii ~= rime_last_state then
      set_rime_state(rime_last_state)
    end
  end)
end

function M.forcely_set_ascii()
  rime_last_state = true
  set_rime_state(rime_last_state)
end

return M
