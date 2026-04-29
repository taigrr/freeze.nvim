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
---@field clipboard? boolean Copy image to system clipboard after freeze (default: false)
---@field extra_args? string[] Additional arguments passed to freeze CLI
local defaults = {
  output = nil,
  filename = "freeze.png",
  theme = nil,
  clipboard = false,
  extra_args = {},
}

---@type FreezeConfig
local config = vim.deepcopy(defaults)

-- Register with glaze.nvim if available
local ok, glaze = pcall(require, "glaze")
if ok then
  glaze.register("freeze", "github.com/charmbracelet/freeze", {
    plugin = "freeze.nvim",
  })
end

--- Build the output file path from config
---@return string
local function get_output_path()
  local dir = config.output or vim.fn.getcwd()
  return dir .. "/" .. config.filename
end

--- Ensure the output directory exists
---@param filepath string Full output file path
---@return boolean
local function ensure_output_dir(filepath)
  local dir = vim.fn.fnamemodify(filepath, ":h")
  if vim.fn.isdirectory(dir) == 1 then
    return true
  end

  local created, err = pcall(vim.fn.mkdir, dir, "p")
  if created and vim.fn.isdirectory(dir) == 1 then
    return true
  end

  vim.notify(
    "Failed to create output directory: " .. dir .. (err and " (" .. tostring(err) .. ")" or ""),
    vim.log.levels.ERROR,
    { title = "Freeze" }
  )
  return false
end

--- Copy an image file to the system clipboard
---@param filepath string Path to the image file
local function copy_to_clipboard(filepath)
  local cmd
  if vim.fn.has("mac") == 1 then
    cmd = {
      "osascript",
      "-e",
      'set the clipboard to (read (POSIX file "' .. filepath .. '") as TIFF picture)',
    }
  elseif vim.fn.has("wsl") == 1 then
    -- WSL: use clip.exe via PowerShell
    cmd = { "powershell.exe", "-Command", "Set-Clipboard", "-Path", filepath }
  elseif vim.fn.executable("xclip") == 1 then
    cmd = { "xclip", "-selection", "clipboard", "-target", "image/png", "-i", filepath }
  elseif vim.fn.executable("xsel") == 1 then
    cmd = { "xsel", "--clipboard", "--input", "--type", "image/png", filepath }
  elseif vim.fn.executable("wl-copy") == 1 then
    cmd = { "wl-copy", "--type", "image/png" }
  else
    vim.notify(
      "No clipboard tool found (xclip, xsel, or wl-copy)",
      vim.log.levels.WARN,
      { title = "Freeze" }
    )
    return
  end

  -- For wl-copy, we need to pipe the file content via stdin
  if cmd[1] == "wl-copy" then
    local f = io.open(filepath, "rb")
    if not f then
      vim.notify(
        "Cannot read file for clipboard: " .. filepath,
        vim.log.levels.ERROR,
        { title = "Freeze" }
      )
      return
    end
    local data = f:read("*a")
    f:close()

    local stdin = uv.new_pipe(false)
    local handle = uv.spawn(cmd[1], {
      args = { cmd[2], cmd[3] },
      stdio = { stdin, nil, nil },
    }, function() end)
    if handle then
      stdin:write(data, function()
        stdin:shutdown()
        stdin:close()
      end)
    end
    return
  end

  uv.spawn(cmd[1], {
    args = vim.list_slice(cmd, 2),
    stdio = { nil, nil, nil },
  }, function(code)
    vim.schedule(function()
      if code == 0 then
        vim.notify("Copied to clipboard", vim.log.levels.INFO, { title = "Freeze" })
      else
        vim.notify("Failed to copy to clipboard", vim.log.levels.WARN, { title = "Freeze" })
      end
    end)
  end)
end

--- Freeze the specified line range to an image
---@param start_line number
---@param end_line number
function M.freeze(start_line, end_line)
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" or vim.bo.modified then
    vim.notify("Save the buffer before freezing", vim.log.levels.WARN, { title = "Freeze" })
    return
  end

  local language = vim.api.nvim_get_option_value("filetype", { buf = 0 })
  local out_path = get_output_path()
  if not ensure_output_dir(out_path) then
    return
  end

  local stdout_pipe = uv.new_pipe(false)
  local stderr_pipe = uv.new_pipe(false)
  local collected = { stdout = "", stderr = "" }

  local args = {
    "--language",
    language,
    "--lines",
    start_line .. "," .. end_line,
    "--output",
    out_path,
  }

  if config.theme then
    table.insert(args, "--theme")
    table.insert(args, config.theme)
  end

  for _, arg in ipairs(config.extra_args) do
    table.insert(args, arg)
  end

  table.insert(args, file)

  local handle = uv.spawn(
    "freeze",
    {
      args = args,
      stdio = { nil, stdout_pipe, stderr_pipe },
    },
    vim.schedule_wrap(function(code, _)
      stdout_pipe:read_stop()
      stderr_pipe:read_stop()
      stdout_pipe:close()
      stderr_pipe:close()

      if code == 0 then
        vim.notify("Frozen: " .. out_path .. " 🍦", vim.log.levels.INFO, { title = "Freeze" })
        if config.clipboard then
          copy_to_clipboard(out_path)
        end
      else
        local msg = collected.stderr ~= "" and collected.stderr or collected.stdout
        vim.notify(
          "freeze failed (exit " .. code .. "): " .. msg,
          vim.log.levels.ERROR,
          { title = "Freeze" }
        )
      end
    end)
  )

  if not handle then
    vim.notify(
      "Failed to spawn freeze — is it installed?",
      vim.log.levels.ERROR,
      { title = "Freeze" }
    )
    stdout_pipe:close()
    stderr_pipe:close()
    return
  end

  uv.read_start(stdout_pipe, function(err, data)
    if err then
      vim.schedule(function()
        vim.notify(err, vim.log.levels.ERROR, { title = "Freeze" })
      end)
    end
    if data then
      collected.stdout = collected.stdout .. data
    end
  end)

  uv.read_start(stderr_pipe, function(err, data)
    if err then
      vim.schedule(function()
        vim.notify(err, vim.log.levels.ERROR, { title = "Freeze" })
      end)
    end
    if data then
      collected.stderr = collected.stderr .. data
    end
  end)
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
