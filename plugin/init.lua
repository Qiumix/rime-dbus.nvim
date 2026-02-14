vim.api.nvim_create_user_command("RimeDbusToggle", function()
  require("rime_dbus").toggle()
end, { desc = "Toggle Rime D-Bus auto ASCII mode" })
