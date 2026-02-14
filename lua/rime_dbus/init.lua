local M = {}
local api = vim.api

local core = require("rime_dbus.core")

-- Plugin enabled state
local enabled = false
local augroup_name = "RimeAutoMode"

M.setup = function(opts)
  -- Reserved for future configuration
end

M.open = function()
  if vim.fn.executable("busctl") == 0 then
    vim.notify("Rime-DBus: busctl not found", vim.log.levels.ERROR)
    return
  end

  enabled = true

  local group = api.nvim_create_augroup(augroup_name, { clear = true })

  api.nvim_create_autocmd("InsertLeave", {
    group = group,
    callback = core.save_and_set_ascii,
    desc = "Save Rime state and switch to ASCII mode",
  })

  api.nvim_create_autocmd("InsertEnter", {
    group = group,
    callback = core.restore_state,
    desc = "Restore previous Rime input state",
  })
end

M.close = function()
  enabled = false
  api.nvim_del_augroup_by_name(augroup_name)
end

M.toggle = function()
  M[enabled and "close" or "open"]()
end

M.forcely_set_ascii = core.forcely_set_ascii
return M
