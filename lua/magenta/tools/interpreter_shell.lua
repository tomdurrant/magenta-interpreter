-- magenta/tools/interpreter_shell.lua
--
-- Integration with Open Interpreter's server mode for executing shell commands
-- and getting structured output back.

local M = {}
local curl = require("plenary.curl")
local json = vim.json

-- Default configuration values
local config = {
  server_url = "http://localhost:3000",
  auto_start = false,
  approved_commands = {}, -- Empty means all commands allowed (not recommended for security)
  timeout = 30000,        -- Timeout in milliseconds
  show_command_output = true,
}

-- Initialize the tool with user configuration
function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
end

-- Start the Open Interpreter server if auto_start is enabled
function M.ensure_server_running()
  if not config.auto_start then
    return true
  end
  
  -- Check if server is already running
  local is_running = os.execute("curl -s " .. config.server_url .. " > /dev/null 2>&1") == 0
  
  if not is_running then
    vim.notify("Starting Open Interpreter server...", vim.log.levels.INFO)
    vim.fn.jobstart({
      "interpreter", "--server",
      "--port", tostring(vim.fn.split(config.server_url, ":")[3]),
    }, {
      detach = true,
      on_exit = function(_, code)
        if code ~= 0 then
          vim.notify("Failed to start Open Interpreter server", vim.log.levels.ERROR)
        end
      end
    })
    
    -- Wait for server to become available
    local attempts = 0
    local max_attempts = 10
    while attempts < max_attempts do
      vim.cmd("sleep 500m") -- Sleep for 500ms
      is_running = os.execute("curl -s " .. config.server_url .. " > /dev/null 2>&1") == 0
      if is_running then
        vim.notify("Open Interpreter server started successfully", vim.log.levels.INFO)
        return true
      end
      attempts = attempts + 1
    end
    
    vim.notify("Timed out waiting for Open Interpreter server to start", vim.log.levels.ERROR)
    return false
  end
  
  return true
end

-- Check if a command is allowed to run based on configured approved_commands
function M.is_command_allowed(command)
  if vim.tbl_isempty(config.approved_commands) then
    return true -- All commands allowed if list is empty
  end
  
  for _, pattern in ipairs(config.approved_commands) do
    if string.match(command, pattern) then
      return true
    end
  end
  
  return false
end

-- Execute a shell command via Open Interpreter
function M.execute_command(command, opts)
  opts = opts or {}
  local stream = opts.stream or false
  
  if not M.ensure_server_running() then
    return { success = false, output = "Open Interpreter server is not running" }
  end
  
  if not M.is_command_allowed(command) then
    local msg = "Command not allowed: " .. command
    vim.notify(msg, vim.log.levels.ERROR)
    return { success = false, output = msg }
  end
  
  -- Prepare request payload
  local payload = {
    prompt = command,
    stream = stream
  }
  
  -- Send request to Open Interpreter server
  local response = curl.post(config.server_url, {
    body = json.encode(payload),
    headers = {
      ["Content-Type"] = "application/json"
    },
    timeout = config.timeout
  })
  
  if response.status ~= 200 then
    local error_msg = "Error from Open Interpreter server: " .. (response.body or "Unknown error")
    vim.notify(error_msg, vim.log.levels.ERROR)
    return { success = false, output = error_msg }
  end
  
  local result
  local ok, decoded = pcall(json.decode, response.body)
  if ok and decoded then
    result = { success = true, output = decoded.output or "" }
    
    -- Display the command output if configured to do so
    if config.show_command_output and result.output ~= "" then
      vim.defer_fn(function()
        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(result.output, "\n"))
        vim.api.nvim_buf_set_option(bufnr, "filetype", "sh")
        vim.api.nvim_buf_set_name(bufnr, "Interpreter Output")
        
        -- Open in a split window
        vim.cmd("vsplit")
        local win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, bufnr)
        
        -- Make it read-only
        vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
      end, 10)
    end
  else
    result = { success = false, output = "Failed to parse response from Open Interpreter" }
    vim.notify(result.output, vim.log.levels.ERROR)
  end
  
  return result
end

-- Register the tool with Magenta
function M.register_with_magenta()
  -- Ensure magenta.tools exists
  if not package.loaded["magenta.tools"] then
    return false
  end
  
  -- Register the tool
  local magenta_tools = require("magenta.tools")
  magenta_tools.register("interpreter_shell", {
    name = "interpreter_shell",
    description = "Execute shell commands using Open Interpreter and get the results",
    handler = function(args)
      local command = args.args or args[1]
      if not command or command == "" then
        return { success = false, output = "No command provided" }
      end
      return M.execute_command(command)
    end
  })
  
  return true
end

return M
