# AGENTS.md

AI agent guide for working in freeze.nvim.

## Project Overview

**freeze.nvim** is a Neovim plugin for creating code screenshots using charmbracelet/freeze. It integrates with glaze.nvim for automatic binary management.

- **Language**: Lua (Neovim plugin)
- **Requirements**: Neovim >= 0.9, glaze.nvim
- **Author**: Tai Groot (taigrr)

## Directory Structure

```
freeze.nvim/
├── lua/freeze/
│   ├── init.lua      # Main module: setup, freeze command, glaze registration
│   └── health.lua    # Health check: :checkhealth freeze
├── doc/
│   └── freeze.txt    # Vim help documentation
├── .github/
│   └── FUNDING.yml   # GitHub Sponsors config
├── .editorconfig     # Editor formatting rules
├── .gitattributes    # Git LFS tracking
├── .gitignore        # Ignored files
├── .luarc.json       # Lua LSP configuration
├── LICENSE           # 0BSD license
├── Makefile          # Demo recording commands
└── README.md         # User documentation
```

## Commands

| Command          | Description                                    |
| ---------------- | ---------------------------------------------- |
| `:[range]Freeze` | Freeze selected lines (or entire buffer) to PNG |
| `:checkhealth freeze` | Run health check                          |

## Code Patterns

### Module Pattern

Uses standard Neovim plugin pattern with `M` table:

```lua
local M = {}
function M.setup(opts) end
function M.freeze(start_line, end_line) end
return M
```

### Type Annotations

Uses LuaCATS (`---@param`, `---@return`, `---@class`) for type hints.

### Async Patterns

- `vim.loop` for libuv bindings
- `vim.schedule_wrap()` for deferred main-loop execution
- Pipe-based stdout/stderr capture

### glaze.nvim Integration

Plugin registers with glaze.nvim at load time (not in setup):

```lua
local ok, glaze = pcall(require, "glaze")
if ok then
  glaze.register("freeze", "github.com/charmbracelet/freeze", {
    plugin = "freeze.nvim",
  })
end
```

## Testing

**No automated tests.** Manual testing workflow:

```vim
:luafile %              " Reload current file
:checkhealth freeze     " Verify setup
:'<,'>Freeze            " Test freeze command
```

## Code Conventions

- 2-space indentation (see .editorconfig)
- LuaCATS type annotations
- Private functions use `local function name()`
- Public API via `M.function_name()`
- Notifications via `vim.notify()` with log levels

## Gotchas

1. **vim global**: LSP warnings about undefined `vim` are expected for Neovim plugins. The `.luarc.json` configures this.

2. **glaze.nvim registration**: Happens at module load, not in `setup()`. This ensures the binary is registered even if `setup()` is called later.

3. **Output reset**: `output` table is reset at the start of each `freeze()` call to avoid accumulating data from previous runs.

## API Reference

Main module (`require("freeze")`):

- `setup(opts)` - Initialize plugin, create `:Freeze` command
- `freeze(start_line, end_line)` - Freeze lines to image

## Dependencies

- **Required**: glaze.nvim (binary management)
- **Runtime**: freeze binary (installed via glaze.nvim)
