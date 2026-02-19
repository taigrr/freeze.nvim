---@brief [[
--- freeze.nvim - Screenshot code with charmbracelet/freeze
--- Main plugin module
---@brief ]]

local M = {}

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

--- Freeze the specified line range to an image
---@param start_line number
---@param end_line number
function M.freeze(start_line, end_line)
  output = { stdout = "", stderr = "" }
  local language = vim.api.nvim_get_option_value("filetype", { buf = 0 })
  local file = vim.api.nvim_buf_get_name(0)
  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)
  local handle = vim.loop.spawn("freeze", {
    args = { "--language", language, "--lines", start_line .. "," .. end_line, file },
    stdio = { nil, stdout, stderr },
  }, on_exit(stdout, stderr))
  if not handle then
    vim.notify("Failed to spawn freeze", vim.log.levels.ERROR, { title = "Freeze" })
    return
  end
  vim.loop.read_start(stdout, on_stdout)
  vim.loop.read_start(stderr, on_stderr)
end

--- Setup freeze.nvim
---@param opts table|nil Optional configuration (reserved for future use)
function M.setup(opts)
  opts = opts or {}
  vim.api.nvim_create_user_command("Freeze", function(cmd_opts)
    M.freeze(cmd_opts.line1, cmd_opts.line2)
  end, { range = "%", desc = "Freeze selected lines to an image" })
end

return M
