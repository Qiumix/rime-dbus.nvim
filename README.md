# fcitx5-rime-dbus.nvim

Auto toggle ASCII mode of Rime with fcitx5 in Neovim, through D-Bus.

## Features

- Automatically switches Rime to ASCII mode when leaving Insert mode
- Restores previous input state when entering Insert mode
- Works via D-Bus communication with fcitx5
- No configuration needed - works out of the box

## Requirements

- Linux system
- fcitx5 with Rime input method
- `busctl` command (usually from systemd package)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "fcitx5-rime-dbus.nvim",
  event = "InsertEnter",
}
```

Using Neovim's built-in package manager(neovim version >= 0.12):

```lua
vim.pack.add({
  { src = "https://github.com/Qiumix/fcitx5-rime-dbus.nvim") },
})
```

## How It Works

When you leave Insert mode, the plugin:
1. Queries the current Rime input state via D-Bus
2. Saves the state internally
3. Switches Rime to ASCII mode if it was in Chinese mode

When you enter Insert mode again, the plugin:
1. Queries the current state
2. Restores the previously saved state if different

This ensures you can navigate Neovim in ASCII mode while preserving your preferred input state for editing.
