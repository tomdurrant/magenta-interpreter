-- magenta-interpreter.lua
--
-- Main entry point for the magenta-interpreter plugin that integrates
-- Open Interpreter with magenta.nvim for executing shell commands

local M = {}

-- Store plugin configuration
M.config = {
  interpreter_shell = {
    server_url = "http://localhost:3000",
    auto_start = false,
    approved_commands = {}, -- Empty means all commands allowed (not recommended)
    timeout = 30000,
    show_command_output = true,
  }
}

-- Setup function to initialize the plugin with user configuration
function M.setup(opts)
  -- Merge user configuration with default config
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  
  -- Ensure magenta plugin is loaded
  if not package.loaded["magenta"] then
    vim.notify(
      "magenta.nvim plugin not found. Please ensure it's installed.",
      vim.log.levels.ERROR
    )
    return
  end
  
  -- Initialize the tools module with our configuration
  require("magenta.tools").setup(M.config)
  
  -- Create user command for direct execution
  vim.api.nvim_create_user_command("MagentaInterpreter", function(args)
    local command = args.args
    if command and command ~= "" then
      local result = require("magenta.tools.interpreter_shell").execute_command(command)
      
      -- Always show a notification with the result status
      if result.success then
        vim.notify("Command executed successfully", vim.log.levels.INFO)
      else
        vim.notify("Command failed: " .. result.output, vim.log.levels.ERROR)
      end
    else
      vim.notify("No command provided", vim.log.levels.WARN)
    end
  end, {
    nargs = "+",
    desc = "Execute shell commands via Open Interpreter",
    complete = "shellcmd"
  })
end

-- Execute a shell command directly without going through the Magenta LLM interface
function M.execute_command(command, opts)
  return require("magenta.tools.interpreter_shell").execute_command(command, opts)
end

-- Convenience function to check if Open Interpreter server is running
function M.is_server_running()
  local server_url = M.config.interpreter_shell.server_url
  return os.execute("curl -s " .. server_url .. " > /dev/null 2>&1") == 0
end

-- Start the Open Interpreter server manually
function M.start_server()
  local interpreter_shell = require("magenta.tools.interpreter_shell")
  return interpreter_shell.ensure_server_running()
end

return M
