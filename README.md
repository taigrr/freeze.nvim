# freeze.nvim

🍦 Screenshot code with [freeze](https://github.com/charmbracelet/freeze) from Neovim.

<p>
  <a href="https://github.com/taigrr/freeze.nvim/releases/latest">
    <img alt="Latest release" src="https://img.shields.io/github/v/release/taigrr/freeze.nvim?style=for-the-badge&logo=starship&color=89dceb&logoColor=D9E0EE&labelColor=302D41&include_prerelease&sort=semver">
  </a>
  <a href="https://github.com/taigrr/freeze.nvim/pulse">
    <img alt="Last commit" src="https://img.shields.io/github/last-commit/taigrr/freeze.nvim?style=for-the-badge&logo=starship&color=8bd5ca&logoColor=D9E0EE&labelColor=302D41">
  </a>
  <a href="https://github.com/taigrr/freeze.nvim/blob/master/LICENSE">
    <img alt="License" src="https://img.shields.io/github/license/taigrr/freeze.nvim?style=for-the-badge&logo=starship&color=ee999f&logoColor=D9E0EE&labelColor=302D41">
  </a>
  <a href="https://github.com/taigrr/freeze.nvim/stargazers">
    <img alt="Stars" src="https://img.shields.io/github/stars/taigrr/freeze.nvim?style=for-the-badge&logo=starship&color=c69ff5&logoColor=D9E0EE&labelColor=302D41">
  </a>
</p>

## ✨ Features

- 📸 **Screenshot code** — Select lines and generate beautiful PNG images
- 🔌 **glaze.nvim integration** — Automatic binary management via [glaze.nvim](https://github.com/taigrr/glaze.nvim)
- 🎨 **Syntax highlighting** — Automatically detects filetype for proper highlighting
- ⚡ **Zero config** — Works out of the box

## 📦 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "taigrr/freeze.nvim",
  dependencies = { "taigrr/glaze.nvim" },
  config = true,
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "taigrr/freeze.nvim",
  requires = { "taigrr/glaze.nvim" },
  config = function()
    require("freeze").setup()
  end,
}
```

## ⚡ Requirements

- Neovim >= **0.9.0**
- [freeze](https://github.com/charmbracelet/freeze) binary (auto-installed via glaze.nvim)
- [glaze.nvim](https://github.com/taigrr/glaze.nvim) for binary management

## 🚀 Usage

1. Select lines in visual mode
2. Run `:'<,'>Freeze`
3. A `freeze.png` will be created in your current working directory

Or freeze the entire buffer:

```vim
:Freeze
```

## 📖 Commands

| Command          | Description                                    |
| ---------------- | ---------------------------------------------- |
| `:[range]Freeze` | Freeze selected lines (or entire buffer) to PNG |

## 📋 API

```lua
local freeze = require("freeze")

-- Setup (called automatically with config = true)
freeze.setup()

-- Freeze specific lines programmatically
freeze.freeze(start_line, end_line)
```

## 🩺 Health Check

```vim
:checkhealth freeze
```

Verifies Neovim version, glaze.nvim availability, and freeze binary installation.

## 🤝 Related Projects

- [freeze](https://github.com/charmbracelet/freeze) — The underlying tool
- [glaze.nvim](https://github.com/taigrr/glaze.nvim) — Go binary manager for Neovim

## 📄 License

[0BSD](LICENSE) © [Tai Groot](https://github.com/taigrr)
