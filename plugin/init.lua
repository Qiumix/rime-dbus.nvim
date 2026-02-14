-- Only with both linux and dbus
if vim.fn.has("linux") == 0 or vim.fn.executable("busctl") == 0 then
  return
end

-- Mark plugin loading
if vim.g.loaded_rime_dbus then return end
vim.g.loaded_rime_dbus = true

local core = require("rime_dbus.core")

local rime_group = vim.api.nvim_create_augroup("RimeAutoMode", { clear = true })

vim.api.nvim_create_autocmd("InsertLeave", {
  group = rime_group,
  callback = core.save_and_set_ascii,
})

vim.api.nvim_create_autocmd("InsertEnter", {
  group = rime_group,
  callback = core.restore_state,
})
