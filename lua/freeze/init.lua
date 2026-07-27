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

--- Close a libuv handle when the current runtime supports it
---@param handle any
local function close_handle(handle)
  if not (handle and handle.close) then
    return
  end
  if handle.is_closing and handle:is_closing() then
    return
  end
  handle:close()
end

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
  local out = config.output
  if out == nil or out == "" then
    out = vim.fn.getcwd()
  else
    -- Expand a leading ~ and env vars only (no %, backtick, or glob expansion)
    out = out:gsub("^~", vim.env.HOME or "~")
    out = out:gsub("%${([%w_]+)}", function(v)
      return vim.env[v] or ("${" .. v .. "}")
    end)
    out = out:gsub("%$([%w_]+)", function(v)
      return vim.env[v] or ("$" .. v)
    end)
  end
  local dir = vim.fn.fnamemodify(out, ":p"):gsub("/+$", "")
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
    -- Escape embedded quotes/backslashes for the AppleScript string literal
    local escaped = filepath:gsub("\\", "\\\\"):gsub('"', '\\"')
    cmd = {
      "osascript",
      "-e",
      'set the clipboard to (read (POSIX file "' .. escaped .. '") as «class PNGf»)',
    }
  elseif vim.fn.has("wsl") == 1 then
    -- WSL: convert to a Windows path and copy image bytes via .NET
    local win_path = vim.trim(vim.fn.system({ "wslpath", "-w", filepath }))
    if vim.v.shell_error ~= 0 or win_path == "" then
      win_path = filepath
    end
    local ps = table.concat({
      "Add-Type -AssemblyName System.Windows.Forms,System.Drawing;",
      "[System.Windows.Forms.Clipboard]::SetImage(",
      "[System.Drawing.Image]::FromFile('" .. win_path:gsub("'", "''") .. "'))",
    }, " ")
    cmd = { "powershell.exe", "-NoProfile", "-Command", ps }
  elseif vim.fn.executable("xclip") == 1 then
    cmd = { "xclip", "-selection", "clipboard", "-target", "image/png", "-i", filepath }
  elseif vim.fn.executable("wl-copy") == 1 then
    cmd = { "wl-copy", "--type", "image/png" }
  else
    vim.notify(
      "No clipboard tool found (xclip or wl-copy)",
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
    local handle
    handle = uv.spawn(cmd[1], {
      args = { cmd[2], cmd[3] },
      stdio = { stdin, nil, nil },
    }, function(code)
      vim.schedule(function()
        close_handle(handle)
        if code == 0 then
          vim.notify("Copied to clipboard", vim.log.levels.INFO, { title = "Freeze" })
        else
          vim.notify("Failed to copy to clipboard", vim.log.levels.WARN, { title = "Freeze" })
        end
      end)
    end)
    if handle then
      stdin:write(data, function()
        stdin:shutdown(function()
          stdin:close()
        end)
      end)
    else
      stdin:close()
      vim.schedule(function()
        vim.notify("Failed to spawn wl-copy", vim.log.levels.WARN, { title = "Freeze" })
      end)
    end
    return
  end

  local handle
  handle = uv.spawn(cmd[1], {
    args = vim.list_slice(cmd, 2),
    stdio = { nil, nil, nil },
  }, function(code)
    vim.schedule(function()
      close_handle(handle)
      if code == 0 then
        vim.notify("Copied to clipboard", vim.log.levels.INFO, { title = "Freeze" })
      else
        vim.notify("Failed to copy to clipboard", vim.log.levels.WARN, { title = "Freeze" })
      end
    end)
  end)
  if not handle then
    vim.notify(
      "Failed to spawn clipboard command: " .. cmd[1],
      vim.log.levels.WARN,
      { title = "Freeze" }
    )
  end
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
  local state =
    { exited = false, code = nil, stdout_done = false, stderr_done = false, done = false }

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

  local handle

  -- Notify only once the process has exited AND both pipes have reached EOF,
  -- so collected stderr/stdout is complete before we build the message.
  local function finalize()
    if state.done then
      return
    end
    if not (state.exited and state.stdout_done and state.stderr_done) then
      return
    end
    state.done = true
    close_handle(handle)
    close_handle(stdout_pipe)
    close_handle(stderr_pipe)

    if state.code == 0 then
      vim.notify("Frozen: " .. out_path .. " 🍦", vim.log.levels.INFO, { title = "Freeze" })
      if config.clipboard then
        copy_to_clipboard(out_path)
      end
    else
      local msg = collected.stderr ~= "" and collected.stderr or collected.stdout
      vim.notify(
        "freeze failed (exit " .. state.code .. "): " .. msg,
        vim.log.levels.ERROR,
        { title = "Freeze" }
      )
    end
  end

  handle = uv.spawn(
    "freeze",
    {
      args = args,
      stdio = { nil, stdout_pipe, stderr_pipe },
    },
    vim.schedule_wrap(function(code, _)
      state.exited = true
      state.code = code
      finalize()
    end)
  )

  if not handle then
    vim.notify(
      "Failed to spawn freeze — is it installed?",
      vim.log.levels.ERROR,
      { title = "Freeze" }
    )
    close_handle(stdout_pipe)
    close_handle(stderr_pipe)
    return
  end

  local function on_read(pipe, key)
    return function(err, data)
      if err then
        vim.schedule(function()
          vim.notify(err, vim.log.levels.ERROR, { title = "Freeze" })
        end)
      end
      if data then
        collected[key] = collected[key] .. data
      else
        pipe:read_stop()
        state[key .. "_done"] = true
        vim.schedule(finalize)
      end
    end
  end

  uv.read_start(stdout_pipe, on_read(stdout_pipe, "stdout"))
  uv.read_start(stderr_pipe, on_read(stderr_pipe, "stderr"))
end

--- Setup freeze.nvim
---@param opts FreezeConfig|nil Optional configuration
function M.setup(opts)
  config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})

  pcall(vim.api.nvim_del_user_command, "Freeze")
  vim.api.nvim_create_user_command("Freeze", function(cmd_opts)
    M.freeze(cmd_opts.line1, cmd_opts.line2)
  end, { range = "%", desc = "Freeze selected lines to an image" })
end

return M
