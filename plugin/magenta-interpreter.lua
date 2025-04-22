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
