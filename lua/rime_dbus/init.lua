local M = {}
local api = vim.api

local core = require("rime_dbus.core")

-- Plugin enabled state
local enabled = false
local smart_esc = true
local augroup_name = "RimeAutoMode"

local function smart_esc_fun()
  -- Run your force function first
  core.get_rime_state(function(not_ascii)
    if not_ascii then core.forcely_set_ascii() end
  end)

  -- Return the actual Esc key to trigger original behavior
  -- Use nvim_replace_termcodes to handle the key properly
  return api.nvim_replace_termcodes("<Esc>", true, true, true)
end

M.enable = function()
  if vim.fn.executable("busctl") == 0 then
    vim.notify("Rime-DBus: busctl not found", vim.log.levels.ERROR)
    return
  end

  enabled = true

  local group = api.nvim_create_augroup(augroup_name, { clear = true })

  vim.keymap.set({ "n", "v" }, "<Esc>", smart_esc_fun, {
    silent = true,
    expr = true,
    desc = "Force Rime ASCII and then Esc"
  })

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

M.disable = function()
  enabled = false
  api.nvim_del_augroup_by_name(augroup_name)
  vim.keymap.del({ "n", "v" }, "<Esc>")
end

M.toggle = function()
  M[enabled and "close" or "open"]()
end

M.setup = function(opts)
  if opts then
    enabled = opts.enabled and opts.enabled or enabled
    smart_esc = opts.smart_esc and opts.smart_esc or smart_esc
  end
  if enabled then
    M.enable()
  end
end

return M
