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

---@class RimeProc
---@field handle? uv.uv_process_t
---@field stdout uv.uv_pipe_t
---@field timer? uv.uv_timer_t
---@field output string[]
---@field callback fun(output: string)
---@field timeout number
local Proc = {}
Proc.__index = Proc

---@param args string[]
---@param callback fun(output: string)
---@param timeout? number
---@return RimeProc
function Proc.new(args, callback, timeout)
  local self = setmetatable({}, Proc)
  self.stdout = assert(uv.new_pipe())
  self.output = {}
  self.callback = callback
  self.timeout = timeout or 500

  self:run(args)
  return self
end

function Proc:on_exit()
  close(self.timer)
  close(self.handle)

  local check = assert(uv.new_check())
  check:start(function()
    if self.stdout and not self.stdout:is_closing() then
      return
    end
    check:stop()
    close(check)
    close(self.stdout)

    local result = table.concat(self.output)
    vim.schedule_wrap(self.callback)(result)
  end)
end

function Proc:run(args)
  local opts = {
    args = args,
    stdio = { nil, self.stdout, nil },
    hide = true,
  }

  self.handle = uv.spawn("busctl", opts, function(_, _)
    self:on_exit()
  end)

  if not self.handle then
    close(self.stdout)
    vim.notify("Rime-DBus: busctl spawn failed", vim.log.levels.WARN)
    return
  end

  -- Timeout protection
  self.timer = assert(uv.new_timer())
  self.timer:start(self.timeout, 0, function()
    if self.handle and not self.handle:is_closing() then
      self.handle:kill("sigterm")
    end
  end)

  self.stdout:read_start(function(err, data)
    assert(not err, err)
    if data then
      table.insert(self.output, data)
    else
      close(self.stdout)
    end
  end)
end

--- Query current Rime ASCII state asynchronously
--- @param callback fun(is_ascii: boolean)
function M.exec_by_rime_state(callback)
  Proc.new(
    { "--user", "call", "org.fcitx.Fcitx5", "/rime", "org.fcitx.Fcitx.Rime1", "IsAsciiMode" },
    function(output)
      local is_ascii = output:find("true") ~= nil
      callback(is_ascii)
    end
  )
end

--- Set Rime ASCII state asynchronously
--- @param target_state boolean
local function set_rime_state(target_state)
  Proc.new(
    {
      "--user", "call", "org.fcitx.Fcitx5", "/rime",
      "org.fcitx.Fcitx.Rime1", "SetAsciiMode", "b",
      target_state and "true" or "false"
    },
    function(_) end -- No-op callback
  )
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
