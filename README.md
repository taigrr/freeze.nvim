# freeze.nvim

A tool for using [freeze](https://github.com/charmbracelet/freeze) right from
Neovim!

## Requirements

- [freeze](https://github.com/charmbracelet/freeze)
- (Optional) [glaze.nvim](https://github.com/taigrr/glaze.nvim) — centralized Go binary manager. If installed, freeze.nvim auto-registers its binary with Glaze.

## Installation

[lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "taigrr/freeze.nvim",
    config = true,
}
```

## Usage

Highlight the lines you want to freeze and run `:'<'>Freeze`, a freeze.png will
be added to your current working directory!
