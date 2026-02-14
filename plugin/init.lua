vim.api.nvim_create_user_command("RimeDbusToggle", function()
  require("rime_dbus").toggle()
end, { desc = "Toggle Rime D-Bus auto ASCII mode" })

vim.api.nvim_create_user_command("RimeDbusEnable", function()
  require("rime_dbus").enable()
end, { desc = "Enable Rime D-Bus auto ASCII mode" })

vim.api.nvim_create_user_command("RimeDbusClose", function()
  require("rime_dbus").disable()
end, { desc = "Close Rime D-Bus auto ASCII mode" })
