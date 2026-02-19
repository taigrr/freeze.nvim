local loop = vim.loop
local freeze = {}
local output = { stdout = "", stderr = "" }
local utils = require("freeze.utils")
local install = require("freeze.install")

-- Register with glaze.nvim if available
local ok, glaze = pcall(require, "glaze")
if ok then
  glaze.register("freeze", "github.com/charmbracelet/freeze", {
    plugin = "freeze.nvim",
  })
end

local function onReadStdOut(err, data)
	if err then
		vim.notify(err, vim.log.levels.ERROR, { title = "Freeze" })
	end
	if data then
		output.stdout = output.stdout .. data
	end
end

local function onReadStdErr(err, data)
	if err then
		vim.notify(err, vim.log.levels.ERROR, { title = "Freeze" })
	end
	if data then
		output.stderr = output.stderr .. data
	end
end

local function onExit(stdout, stderr)
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

function freeze.freeze(start_line, end_line)
	local language = vim.api.nvim_buf_get_option(0, "filetype")
	local file = vim.api.nvim_buf_get_name(0)
	local stdout = loop.new_pipe(false)
	local stderr = loop.new_pipe(false)
	local handle = loop.spawn("freeze", {
		args = { "--language", language, "--lines", start_line .. "," .. end_line, file },
		stdio = { nil, stdout, stderr },
	}, onExit(stdout, stderr))
	if not handle then
		vim.notify("Failed to spawn freeze", vim.log.levels.ERROR, { title = "Freeze" })
	end
	loop.read_start(stdout, onReadStdOut)
	loop.read_start(stderr, onReadStdErr)
end
local create_cmd = function(cmd, func, opt)
	opt = vim.tbl_extend("force", { desc = "freeze.nvim " .. cmd }, opt or {})
	vim.api.nvim_create_user_command(cmd, func, opt)
end
function freeze.setup()
	vim.api.nvim_create_user_command("Freeze", function(opts)
		freeze.freeze(opts.line1, opts.line2)
	end, { range = "%" })
	create_cmd("FreezeInstall", function(_)
		install.install_all()
	end)
	create_cmd("FreezeUpdate", function(_)
		install.update_all()
	end)
end

return freeze
