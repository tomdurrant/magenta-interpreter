-- magenta/tools/init.lua
--
-- Initialization file for magenta tools

local M = {}

-- Load and expose the interpreter_shell module
M.interpreter_shell = require("magenta.tools.interpreter_shell")

-- Register all tools with the main Magenta plugin
function M.setup(opts)
  opts = opts or {}
  
  -- Configure the interpreter_shell module
  if opts.interpreter_shell then
    M.interpreter_shell.setup(opts.interpreter_shell)
  end
  
  -- Register the interpreter_shell tool with Magenta
  M.interpreter_shell.register_with_magenta()
end

return M
