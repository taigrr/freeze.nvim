---@brief [[
--- freeze.nvim health check
--- Run with :checkhealth freeze
---@brief ]]

local M = {}

function M.check()
  vim.health.start("freeze.nvim")

  -- Check Neovim version
  if vim.fn.has("nvim-0.9") == 1 then
    vim.health.ok("Neovim >= 0.9")
  else
    vim.health.error("Neovim >= 0.9 required", { "Upgrade Neovim to 0.9 or later" })
  end

  -- Check glaze.nvim (optional)
  local has_glaze = pcall(require, "glaze")
  if has_glaze then
    vim.health.ok("glaze.nvim found (binary management enabled)")
  else
    vim.health.warn("glaze.nvim not found", {
      "Install glaze.nvim for automatic freeze binary management",
      "See: https://github.com/taigrr/glaze.nvim",
    })
  end

  -- Check freeze binary
  if vim.fn.executable("freeze") == 1 then
    local version = vim.fn.system("freeze --version 2>/dev/null"):gsub("%s+$", "")
    if version ~= "" then
      vim.health.ok("freeze found: " .. version)
    else
      vim.health.ok("freeze found")
    end
  else
    vim.health.error("freeze not found", {
      "Install with :GlazeInstall freeze (if glaze.nvim is installed)",
      "Or manually: go install github.com/charmbracelet/freeze@latest",
      "See: https://github.com/charmbracelet/freeze",
    })
  end
end

return M
