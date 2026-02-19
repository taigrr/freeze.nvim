# AGENTS.md - freeze.nvim

## Overview

Neovim plugin that wraps [charmbracelet/freeze](https://github.com/charmbracelet/freeze) for creating code screenshots directly from Neovim. Uses [glaze.nvim](https://github.com/taigrr/glaze.nvim) for automatic binary management.

## Project Structure

```
freeze.nvim/
├── README.md
└── lua/freeze/
    ├── init.lua      # Main plugin entry point, setup, and core freeze command
    ├── health.lua    # :checkhealth integration
    └── install.lua   # Binary installation via `go install`
```

## Commands Provided

| Command          | Description                                           |
|------------------|-------------------------------------------------------|
| `:Freeze`        | Freeze selected lines (visual range) to `freeze.png` |
| `:FreezeInstall` | Install freeze binary via `go install`               |
| `:FreezeUpdate`  | Update freeze binary to latest version               |

## Code Patterns

### Module Structure

Each Lua file follows the standard Neovim plugin pattern:

```lua
local M = {}
-- functions
return M
```

Or a table literal return:

```lua
return {
  install = install,
  update = update,
  -- ...
}
```

### Neovim API Usage

- `vim.loop` (libuv) for async process spawning
- `vim.fn.system()` and `vim.fn.jobstart()` for shell commands
- `vim.api.nvim_create_user_command()` for command registration
- `vim.notify()` for user notifications with log levels
- `vim.health.*` for health check integration

### Async Pattern

The main freeze operation uses libuv pipes for non-blocking execution:

```lua
local stdout = loop.new_pipe(false)
local stderr = loop.new_pipe(false)
local handle = loop.spawn("freeze", { args = {...}, stdio = {...} }, onExit)
loop.read_start(stdout, onReadStdOut)
loop.read_start(stderr, onReadStdErr)
```

### glaze.nvim Integration

Plugin registers with glaze.nvim for binary management:

```lua
local ok, glaze = pcall(require, "glaze")
if ok then
  glaze.register("freeze", "github.com/charmbracelet/freeze", {
    plugin = "freeze.nvim",
  })
end
```

## Testing

No automated test suite. Manual testing:

1. Load plugin in Neovim
2. Run `:checkhealth freeze` to verify setup
3. Select lines and run `:'<,'>Freeze`
4. Verify `freeze.png` created in cwd

## Development Notes

### Missing File

`init.lua` imports `freeze.utils` but `utils.lua` does not exist in the repository. This is a bug - the file is either missing or the import is stale.

### LSP Warnings

lua_ls reports `undefined-global 'vim'` warnings throughout. This is expected for Neovim plugins since `vim` is injected at runtime. To suppress, add to workspace settings:

```lua
-- .luarc.json
{
  "diagnostics": {
    "globals": ["vim"]
  }
}
```

### Global Reference

`install.lua` references `_GO_NVIM_CFG` (line 112-113), a leftover from the go.nvim codebase this was adapted from. Not used in practice.

### Dependencies

- **Runtime**: `freeze` binary (from charmbracelet/freeze)
- **Optional**: `glaze.nvim` for automatic binary management
- **Build**: Go toolchain (for `go install`)

## Style Conventions

- Tabs for indentation
- Local variables with descriptive names
- Functions defined as `function module.name()` or `local function name()`
- Notifications via `vim.notify()` with appropriate log levels
- Error handling via `pcall()` for optional dependencies
