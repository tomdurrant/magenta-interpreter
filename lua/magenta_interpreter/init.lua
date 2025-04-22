-- magenta_interpreter/init.lua
--
-- Main entry point for the magenta-interpreter plugin that integrates
-- Open Interpreter with magenta.nvim for executing shell commands

local M = {}

-- Store plugin configuration
M.config = {
  server_url = "http://localhost:3000",
  auto_start = false,
  approved_commands = {}, -- Empty means all commands allowed (not recommended)
  timeout = 30000,
  show_command_output = true,
}

-- Default configuration values
local default_config = M.config

-- Internal state
local curl = nil
local json = nil
local is_initialized = false

-- Initialize required modules
local function init_modules()
  if is_initialized then return true end
  
  local has_plenary, plenary = pcall(require, "plenary")
  if not has_plenary then
    vim.notify("magenta-interpreter requires plenary.nvim", vim.log.levels.ERROR)
    return false
  end
  
  local has_curl, plenary_curl = pcall(require, "plenary.curl")
  if not has_curl then
    vim.notify("magenta-interpreter requires plenary.curl", vim.log.levels.ERROR)
    return false
  end
  curl = plenary_curl
  json = vim.json
  
  is_initialized = true
  return true
end

-- Start the Open Interpreter server if auto_start is enabled
function M.ensure_server_running()
  if not init_modules() then return false end
  
  if vim.g.magenta_interpreter_debug then
    vim.notify("magenta-interpreter debug: ensure_server_running called", vim.log.levels.INFO)
    vim.notify("magenta-interpreter debug: auto_start is " .. tostring(M.config.auto_start), vim.log.levels.INFO)
  end
  
  if not M.config.auto_start then
    return true
  end
  
  -- Check if server is already running
  local is_running = os.execute("curl -s " .. M.config.server_url .. " > /dev/null 2>&1") == 0
  
  if not is_running then
    vim.notify("Starting Open Interpreter server...", vim.log.levels.INFO)
    vim.fn.jobstart({
      "interpreter", "--server",
      "--port", tostring(vim.fn.split(M.config.server_url, ":")[3]),
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
      is_running = os.execute("curl -s " .. M.config.server_url .. " > /dev/null 2>&1") == 0
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
  if vim.tbl_isempty(M.config.approved_commands) then
    return true -- All commands allowed if list is empty
  end
  
  for _, pattern in ipairs(M.config.approved_commands) do
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
  
  if not init_modules() then
    return { success = false, output = "Failed to initialize required modules" }
  end
  
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
  local response = curl.post(M.config.server_url, {
    body = json.encode(payload),
    headers = {
      ["Content-Type"] = "application/json"
    },
    timeout = M.config.timeout
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
    if M.config.show_command_output and result.output ~= "" then
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
  -- First make sure Magenta is loaded
  local has_magenta, magenta = pcall(require, "magenta")
  if not has_magenta then
    vim.notify("magenta.nvim is required for registering the tool", vim.log.levels.ERROR)
    return false
  end
  
  if vim.g.magenta_interpreter_debug then
    vim.notify("Attempting to register with magenta.nvim", vim.log.levels.INFO)
    vim.notify("magenta module found: " .. tostring(has_magenta), vim.log.levels.INFO)
    vim.notify("magenta.register_tool exists: " .. tostring(magenta.register_tool ~= nil), vim.log.levels.INFO)
    if magenta.tools then
      vim.notify("magenta.tools exists and magenta.tools.register exists: " .. tostring(magenta.tools.register ~= nil), vim.log.levels.INFO)
    else
      vim.notify("magenta.tools does not exist", vim.log.levels.INFO)
    end
  end
  
  -- Define our tool specification
  local tool_spec = {
    name = "interpreter_shell",
    description = "Execute shell commands using Open Interpreter and get the results",
    handler = function(args)
      -- Handle both table and string inputs
      local command = ""
      if type(args) == "table" then
        command = args.args or args[1] or ""
      else
        command = tostring(args) or ""
      end
      
      if command == "" then
        return { success = false, output = "No command provided" }
      end
      
      if vim.g.magenta_interpreter_debug then
        vim.notify("interpreter_shell called with command: " .. command, vim.log.levels.INFO)
      end
      
      return M.execute_command(command)
    end
  }
  
  -- Try different registration methods
  local registered = false
  local err_msg = ""
  
  -- Method 1: Direct registration if available
  if magenta.register_tool then
    local ok, err = pcall(function()
      magenta.register_tool("interpreter_shell", tool_spec)
    end)
    if ok then
      registered = true
      if vim.g.magenta_interpreter_debug then
        vim.notify("Registered tool using magenta.register_tool", vim.log.levels.INFO)
      end
    else
      err_msg = err_msg .. "\nFailed with magenta.register_tool: " .. tostring(err)
    end
  end
  
  -- Method 2: Using tools module if available
  if not registered and magenta.tools and magenta.tools.register then
    local ok, err = pcall(function()
      magenta.tools.register("interpreter_shell", tool_spec)
    end)
    if ok then
      registered = true
      if vim.g.magenta_interpreter_debug then
        vim.notify("Registered tool using magenta.tools.register", vim.log.levels.INFO)
      end
    else
      err_msg = err_msg .. "\nFailed with magenta.tools.register: " .. tostring(err)
    end
  end
  
  -- Method 3: Last resort - monkey patch the tools table
  if not registered and magenta.tools and type(magenta.tools) == "table" then
    local ok, err = pcall(function()
      if not magenta.tools._tools then
        magenta.tools._tools = {}
      end
      magenta.tools._tools.interpreter_shell = tool_spec
      if not magenta.tools.execute then
        magenta.tools.execute = function(tool_name, ...)
          if magenta.tools._tools[tool_name] and magenta.tools._tools[tool_name].handler then
            return magenta.tools._tools[tool_name].handler(...)
          end
          return { success = false, output = "Tool not found: " .. tool_name }
        end
      end
    end)
    if ok then
      registered = true
      if vim.g.magenta_interpreter_debug then
        vim.notify("Registered tool by patching magenta.tools", vim.log.levels.INFO)
      end
    else
      err_msg = err_msg .. "\nFailed with monkey patching: " .. tostring(err)
    end
  end
  
  if not registered then
    if vim.g.magenta_interpreter_debug then
      vim.notify("Failed to register tool with magenta: " .. err_msg, vim.log.levels.ERROR)
    else
      vim.notify("Failed to register interpreter_shell with magenta. Enable debug for details.", vim.log.levels.ERROR)
    end
  end
  
  return registered
end

-- Check if Open Interpreter server is running
function M.is_server_running()
  if not init_modules() then return false end
  
  local server_url = M.config.server_url
  return os.execute("curl -s " .. server_url .. " > /dev/null 2>&1") == 0
end

-- Start the Open Interpreter server manually
function M.start_server()
  return M.ensure_server_running()
end

-- Setup function to initialize the plugin with user configuration
function M.setup(opts)
  if vim.g.magenta_interpreter_debug then
    vim.notify("magenta-interpreter.setup called", vim.log.levels.INFO)
    if opts then
      vim.notify("Options received: " .. vim.inspect(opts), vim.log.levels.INFO)
    else
      vim.notify("No options received", vim.log.levels.INFO)
    end
  end
  
  -- Merge user configuration with default config
  if opts then
    -- Handle older config format that had interpreter_shell nested
    if opts.interpreter_shell then
      if vim.g.magenta_interpreter_debug then
        vim.notify("Converting from legacy interpreter_shell config format", vim.log.levels.INFO)
      end
      opts = opts.interpreter_shell
    end
    
    M.config = vim.tbl_deep_extend("force", default_config, opts)
  end
  
  if vim.g.magenta_interpreter_debug then
    vim.notify("Effective configuration: " .. vim.inspect(M.config), vim.log.levels.INFO)
  end
  
  -- Initialize modules
  if not init_modules() then
    vim.notify("Failed to initialize magenta-interpreter", vim.log.levels.ERROR)
    return
  end
  
  -- Create user command for direct execution
  vim.api.nvim_create_user_command("MagentaInterpreter", function(args)
    local command = args.args
    if command and command ~= "" then
      local result = M.execute_command(command)
      
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
  
  -- Try to register with Magenta directly (for cases when Magenta is already loaded)
  local immediate_success = M.register_with_magenta()
  if immediate_success and vim.g.magenta_interpreter_debug then
    vim.notify("Immediate registration with Magenta successful", vim.log.levels.INFO)
  end
  
  -- Also register on VimEnter for cases when Magenta loads later
  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      if vim.g.magenta_interpreter_debug then
        vim.notify("VimEnter event triggered for magenta-interpreter", vim.log.levels.INFO)
      end
      
      -- Delay the registration to ensure Magenta is fully initialized
      vim.defer_fn(function()
        -- Avoid duplicate registration if already successful
        if not immediate_success then
          local success = M.register_with_magenta()
          if success then
            if vim.g.magenta_interpreter_debug then
              vim.notify("Delayed registration with Magenta successful", vim.log.levels.INFO)
            else
              vim.notify("interpreter_shell tool registered with Magenta", vim.log.levels.INFO)
            end
          else
            vim.notify("Failed to register interpreter_shell with Magenta. Check if magenta.nvim is properly loaded.", vim.log.levels.WARN)
          end
        end
      end, 1000) -- Increased delay to 1 second for better reliability
    end,
    once = true
  })
  
  -- Also try after plugins are loaded (for lazy loading cases)
  vim.api.nvim_create_autocmd("User", {
    pattern = {"LazyDone", "PackerComplete", "VeryLazy"},
    callback = function()
      if vim.g.magenta_interpreter_debug then
        vim.notify("Plugin manager finished loading, attempting registration", vim.log.levels.INFO)
      end
      
      vim.defer_fn(function()
        if not immediate_success then
          M.register_with_magenta()
        end
      end, 500)
    end,
    once = true
  })
end

return M
