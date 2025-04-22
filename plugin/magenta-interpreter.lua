-- plugin/magenta-interpreter.lua
--
-- Plugin bootstrap for magenta-interpreter
-- This file is loaded automatically by Neovim when plugin is installed

if vim.fn.has("nvim-0.7.0") == 0 then
  vim.api.nvim_err_writeln("magenta-interpreter requires at least Neovim v0.7.0")
  return
end

-- Prevent loading the plugin multiple times
if vim.g.loaded_magenta_interpreter == 1 then
  return
end
vim.g.loaded_magenta_interpreter = 1

-- This allows the plugin to be loaded without error even if something fails
local ok, err = pcall(function()
  -- The plugin doesn't need to do anything on initial load
  -- The setup function will be called by the user's configuration
  
  -- Create a helper command to run diagnostics if there are issues
  vim.api.nvim_create_user_command("MagentaInterpreterDebug", function()
    local debug = require("magenta-interpreter-debug")
    debug.run_diagnostics()
  end, {
    desc = "Run diagnostics for magenta-interpreter plugin"
  })
end)

if not ok then
  vim.notify("Error loading magenta-interpreter plugin: " .. tostring(err), vim.log.levels.ERROR)
end
