local M = {}

-- Internal state: true for ASCII mode, false for Chinese mode
local rime_last_state = true

--- Query current Rime ASCII state asynchronously
--- @param callback fun(is_ascii: boolean)
local function get_rime_state(callback)
  local stdout = vim.uv.new_pipe(false)
  local safe_callback = vim.schedule_wrap(callback)

  -- The options table requires explicit fields to satisfy LSP [missing-fields]
  local options = {
    args = { "--user", "call", "org.fcitx.Fcitx5", "/rime", "org.fcitx.Fcitx.Rime1", "IsAsciiMode" },
    stdio = { nil, stdout, nil },
    env = vim.fn.environ(),
    cwd = vim.uv.cwd(),
    detached = false,
    hide = true,
  }

  local handle, pid_or_err
  handle, pid_or_err = vim.uv.spawn("busctl", options, function(code, signal)
    if handle then handle:close() end
  end)

  -- Error handling for process spawning
  if not handle then
    vim.schedule(function()
      vim.notify("Rime-DBus: Failed to spawn busctl: " .. tostring(pid_or_err), vim.log.levels.ERROR)
    end)
    if stdout then stdout:close() end
    return
  end

  if stdout then
    stdout:read_start(function(err, data)
      if data then
        local is_ascii = data:find("true") ~= nil
        safe_callback(is_ascii)
      end
      -- Immediately stop and close to prevent leaks
      stdout:read_stop()
      stdout:close()
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
    env = vim.fn.environ(),
    cwd = vim.uv.cwd(),
    detached = true,
    hide = true,
  }

  vim.uv.spawn("busctl", options, function(code, signal)
    -- handle is ignored here as we detach
  end)
end

--- Save state and force ASCII when leaving Insert mode
function M.save_and_set_ascii()
  get_rime_state(function(current_is_ascii)
    rime_last_state = current_is_ascii
    if not current_is_ascii then
      set_rime_state(true)
    end
  end)
end

--- Restore state when entering Insert mode
function M.restore_state()
  get_rime_state(function(current_is_ascii)
    if current_is_ascii ~= rime_last_state then
      set_rime_state(rime_last_state)
    end
  end)
end

return M
