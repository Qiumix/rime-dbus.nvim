local M = {}

-- True for ascii mode
local rime_last_state = true

--- Get current rime's ascii state, asynchronously.
--- @param callback fun(is_ascii: boolean)
local function get_rime_state(callback)
  local stdout = vim.uv.new_pipe(false)
  local handle

  handle = vim.uv.spawn("busctl", {
    args = { "--user", "call", "org.fcitx.Fcitx5", "/rime", "org.fcitx.Fcitx.Rime1", "IsAsciiMode" },
    stdio = { nil, stdout, nil }
  }, function()
    if stdout then stdout:close() end
    if handle then handle:close() end
  end)

  if stdout then
    stdout:read_start(function(err, data)
      if err then return end
      if data then
        local is_ascii = data:find("true") ~= nil
        vim.schedule(function()
          callback(is_ascii)
        end)
      end
      stdout:read_stop()
    end)
  end
end

--- Set current rime's ascii state, asynchronously.
--- @param target_state boolean
local function set_rime_state(target_state)
  vim.uv.spawn("busctl", {
    args = {
      "--user", "call", "org.fcitx.Fcitx5", "/rime",
      "org.fcitx.Fcitx.Rime1", "SetAsciiMode", "b",
      target_state and "true" or "false"
    },
    detach = true
  }, nil)
end

--- Leave Insert mode, memory current state
--- and forcely set ascii mode
function M.save_and_set_ascii()
  get_rime_state(function(current_is_ascii)
    rime_last_state = current_is_ascii
    -- Lazy set
    if not current_is_ascii then
      set_rime_state(true)
    end
  end)
end

--- Enter Insert mode, set mode if memorized
--- mode is not equal to current mode.
function M.restore_state()
  get_rime_state(function(current_is_ascii)
    if current_is_ascii ~= rime_last_state then
      set_rime_state(rime_last_state)
    end
  end)
end

return M
