vim.api.nvim_create_user_command("RimeToggle", function()
  require("rime_toggle").toggle()
end, { desc = "Toggle Rime auto ASCII mode" })

vim.api.nvim_create_user_command("RimeEnable", function()
  require("rime_toggle").enable()
end, { desc = "Enable Rime auto ASCII mode" })

vim.api.nvim_create_user_command("RimeDisalbe", function()
  require("rime_toggle").disable()
end, { desc = "Disalbe Rime auto ASCII mode" })
