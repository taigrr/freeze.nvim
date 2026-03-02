---@brief [[
--- freeze.nvim - Screenshot code with charmbracelet/freeze
--- Main plugin module
---@brief ]]

local M = {}

-- Compat shim: vim.uv (Neovim 0.10+) or vim.loop (0.9.x)
local uv = vim.uv or vim.loop

---@class FreezeConfig
---@field output? string Output directory for screenshots (default: cwd)
---@field filename? string Output filename (default: "freeze.png")
---@field theme? string Freeze theme name
---@field extra_args? string[] Additional arguments passed to freeze CLI
local defaults = {
  output = nil,
  filename = "freeze.png",
  theme = nil,
  extra_args = {},
}

---@type FreezeConfig
local config = vim.deepcopy(defaults)

---@class FreezeOutput
---@field stdout string
---@field stderr string
local output = { stdout = "", stderr = "" }

-- Register with glaze.nvim if available
local ok, glaze = pcall(require, "glaze")
if ok then
  glaze.register("freeze", "github.com/charmbracelet/freeze", {
    plugin = "freeze.nvim",
  })
end

---@param err string|nil
---@param data string|nil
local function on_stdout(err, data)
  if err then
    vim.notify(err, vim.log.levels.ERROR, { title = "Freeze" })
  end
  if data then
    output.stdout = output.stdout .. data
  end
end

---@param err string|nil
---@param data string|nil
local function on_stderr(err, data)
  if err then
    vim.notify(err, vim.log.levels.ERROR, { title = "Freeze" })
  end
  if data then
    output.stderr = output.stderr .. data
  end
end

---@param stdout uv_pipe_t
---@param stderr uv_pipe_t
---@return function
local function on_exit(stdout, stderr)
  return vim.schedule_wrap(function(code, _)
    if code == 0 then
      vim.notify("Successfully frozen 🍦", vim.log.levels.INFO, { title = "Freeze" })
    else
      vim.notify(output.stdout, vim.log.levels.ERROR, { title = "Freeze" })
    end
    stdout:read_stop()
    stderr:read_stop()
    stdout:close()
    stderr:close()
  end)
end

--- Build the output file path from config
---@return string
local function get_output_path()
  local dir = config.output or vim.fn.getcwd()
  return dir .. "/" .. config.filename
end

--- Freeze the specified line range to an image
---@param start_line number
---@param end_line number
function M.freeze(start_line, end_line)
  output = { stdout = "", stderr = "" }
  local language = vim.api.nvim_get_option_value("filetype", { buf = 0 })
  local file = vim.api.nvim_buf_get_name(0)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

  local args = {
    "--language", language,
    "--lines", start_line .. "," .. end_line,
    "--output", get_output_path(),
  }

  if config.theme then
    table.insert(args, "--theme")
    table.insert(args, config.theme)
  end

  for _, arg in ipairs(config.extra_args) do
    table.insert(args, arg)
  end

  table.insert(args, file)

  local handle = uv.spawn("freeze", {
    args = args,
    stdio = { nil, stdout, stderr },
  }, on_exit(stdout, stderr))
  if not handle then
    vim.notify("Failed to spawn freeze", vim.log.levels.ERROR, { title = "Freeze" })
    return
  end
  uv.read_start(stdout, on_stdout)
  uv.read_start(stderr, on_stderr)
end

--- Setup freeze.nvim
---@param opts FreezeConfig|nil Optional configuration
function M.setup(opts)
  config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  vim.api.nvim_create_user_command("Freeze", function(cmd_opts)
    M.freeze(cmd_opts.line1, cmd_opts.line2)
  end, { range = "%", desc = "Freeze selected lines to an image" })
end

return M
