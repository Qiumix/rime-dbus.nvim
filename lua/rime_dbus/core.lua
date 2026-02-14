local M = {}
local uv = vim.uv or vim.loop

-- Internal state: true for ASCII mode, false for Chinese mode
local last_state_ascii = true

---@param handle uv.uv_handle_t?
local function close(handle)
  if handle and not handle:is_closing() then
    handle:close()
  end
end

--- Query current Rime ASCII state asynchronously
--- @param callback fun(is_ascii: boolean)
function M.exec_by_rime_state(callback)
  local stdout = assert(uv.new_pipe())
  local output = {}
  local timer = nil
  local handle = nil

  local function on_exit()
    close(timer)
    close(handle)
    local check = assert(uv.new_check())
    check:start(function()
      if stdout and not stdout:is_closing() then
        return
      end
      check:stop()
      close(check)
      close(stdout)
      local result = table.concat(output)
      local is_ascii = result:find("true") ~= nil
      vim.schedule_wrap(callback)(is_ascii)
    end)
  end

  -- separate opts as a single variable to disalbe lsp warning
  local opts = {
    args = { "--user", "call", "org.fcitx.Fcitx5", "/rime", "org.fcitx.Fcitx.Rime1", "IsAsciiMode" },
    stdio = { nil, stdout, nil },
    hide = true,
  }
  handle = uv.spawn("busctl", opts, function(_, _)
    on_exit()
  end)

  if not handle then
    close(stdout)
    vim.notify("Rime-DBus: busctl spawn failed", vim.log.levels.WARN)
    return
  end

  -- Timeout protection (500ms)
  timer = assert(uv.new_timer())
  timer:start(500, 0, function()
    if handle and not handle:is_closing() then
      handle:kill("sigterm")
    end
  end)

  stdout:read_start(function(err, data)
    assert(not err, err)
    if data then
      table.insert(output, data)
    else
      close(stdout)
    end
  end)
end

--- Set Rime ASCII state asynchronously
--- @param target_state boolean
local function set_rime_state(target_state)
  local opts = {
    args = {
      "--user", "call", "org.fcitx.Fcitx5", "/rime",
      "org.fcitx.Fcitx.Rime1", "SetAsciiMode", "b",
      target_state and "true" or "false"
    },
    hide = true,
  }

  local handle = uv.spawn("busctl", opts, function()
    close(handle)
  end)

  if not handle then
    vim.notify("Rime-DBus: Failed to set state", vim.log.levels.WARN)
  end
end

--- Save state and force ASCII when leaving Insert mode
function M.save_and_set_ascii()
  M.exec_by_rime_state(function(current_is_ascii)
    last_state_ascii = current_is_ascii
    if not current_is_ascii then
      set_rime_state(true)
    end
  end)
end

--- Restore state when entering Insert mode
function M.restore_state()
  M.exec_by_rime_state(function(current_is_ascii)
    if current_is_ascii ~= last_state_ascii then
      set_rime_state(last_state_ascii)
    end
  end)
end

function M.forcely_set_ascii()
  last_state_ascii = true
  set_rime_state(last_state_ascii)
end

return M
