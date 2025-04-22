-- Debug helper for magenta-interpreter
local M = {}

-- Set up logger
local log = {}
function log.info(msg) print("[DEBUG-INFO] " .. msg) end
function log.error(msg) print("[DEBUG-ERROR] " .. msg) end

-- Check dependencies are available
function M.check_dependencies()
  log.info("Checking dependencies...")
  
  -- Check for plenary
  local has_plenary, plenary = pcall(require, "plenary")
  if not has_plenary then
    log.error("plenary.nvim is required but not found")
    return false
  end
  log.info("Found plenary.nvim")
  
  -- Check for curl module
  local has_curl, curl = pcall(require, "plenary.curl")
  if not has_curl then
    log.error("plenary.curl module not found")
    return false
  end
  log.info("Found plenary.curl module")
  
  -- Check for magenta
  local has_magenta = pcall(require, "magenta")
  if not has_magenta then
    log.error("magenta.nvim is required but not found")
    return false
  end
  log.info("Found magenta.nvim")
  
  -- Check for magenta.tools
  local has_magenta_tools = pcall(require, "magenta.tools")
  if not has_magenta_tools then
    log.error("magenta.tools module not found. Check magenta.nvim version compatibility")
    return false
  end
  log.info("Found magenta.tools module")
  
  return true
end

-- Check module paths
function M.check_modules()
  log.info("Checking module paths...")
  
  -- Check our own modules
  local modules_to_check = {
    "magenta-interpreter",
    "magenta.tools.interpreter_shell",
    "magenta.tools.init"
  }
  
  for _, module in ipairs(modules_to_check) do
    local success = pcall(require, module)
    if not success then
      log.error("Failed to load module: " .. module)
    else
      log.info("Successfully loaded module: " .. module)
    end
  end
end

-- Run all checks
function M.run_diagnostics()
  log.info("Starting diagnostics for magenta-interpreter")
  M.check_dependencies()
  M.check_modules()
  log.info("Diagnostics complete")
end

return M
