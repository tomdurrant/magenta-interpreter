-- magenta-interpreter.lua
--
-- Main entry point for the magenta-interpreter plugin that integrates
-- Open Interpreter with magenta.nvim for executing shell commands

-- This is just a shim that forwards to the actual implementation in magenta_interpreter/init.lua
-- This makes the plugin code organization cleaner while maintaining a simple API for users

return require("magenta_interpreter")
