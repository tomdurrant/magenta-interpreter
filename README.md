# Magenta Interpreter

An extension for [magenta.nvim](https://github.com/magenta-nvim/magenta.nvim) that integrates Open Interpreter to enable autonomous shell command execution.

## Features

- ✅ Allows magenta.nvim to execute shell commands and parse their output
- ✅ Securable with an allowlist of approved commands
- ✅ Direct invocation via `:MagentaInterpreter` command
- ✅ LLM delegation through the magenta.tools interface
- ✅ Optional automatic Open Interpreter server startup
- ✅ Configurable output display

## Motivation

This plugin addresses a core limitation in the current LLM-based development workflow - the inability for Magenta to autonomously execute shell commands and reason about their output. With Magenta Interpreter, the assistant can now:

- Run linters/formatters and act on results
- Compile code and debug build errors
- Execute test suites and analyze failures
- Inspect files, logs and environment state
- Query system information needed for problem-solving

This creates a more agent-like development assistant that can reason and act over dynamic, stateful environments.

## Requirements

- Neovim >= 0.7.0
- [magenta.nvim](https://github.com/magenta-nvim/magenta.nvim)
- [Open Interpreter](https://github.com/KillianLucas/open-interpreter) (`pip install open-interpreter`)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (dependency for HTTP requests)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "tomdurrant/magenta-interpreter",
  dependencies = {
    "magenta-nvim/magenta.nvim",
    "nvim-lua/plenary.nvim"
  },
  config = function()
    require("magenta-interpreter").setup({
      server_url = "http://localhost:3000",  -- Open Interpreter server URL
      auto_start = false,                    -- Auto-start Open Interpreter server?
      approved_commands = {},                -- List of allowed command patterns (empty = all allowed)
      timeout = 30000,                       -- Request timeout in milliseconds
      show_command_output = true             -- Show command output in a buffer
    })
  end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "tomdurrant/magenta-interpreter",
  requires = {
    "magenta-nvim/magenta.nvim",
    "nvim-lua/plenary.nvim"
  },
  config = function()
    require("magenta-interpreter").setup({
      server_url = "http://localhost:3000",
      auto_start = false,
      approved_commands = {},
      timeout = 30000,
      show_command_output = true
    })
  end
}
```

## Usage

### Direct Invocation

You can directly execute shell commands via the `:MagentaInterpreter` command:

```vim
:MagentaInterpreter ls -la
```

### LLM Delegation

Once installed and configured, the `interpreter_shell` tool will be available to the Magenta LLM. This allows the assistant to proactively run shell commands when needed to answer your questions or complete tasks.

Example prompts that would trigger shell execution:

- "What's the current memory usage on my system?"
- "Run the tests for this project and tell me what's failing."
- "Show me all Python processes running right now."
- "Format this file with Black."

### Starting the Open Interpreter Server

The Open Interpreter server must be running for this plugin to work. You can:

1. **Manual start**: Run `interpreter --server` in a terminal
2. **Auto-start**: Set `auto_start = true` in the configuration

## Security Considerations

This plugin allows for arbitrary command execution on your system. For security:

1. Consider restricting which commands can be executed with the `approved_commands` option:

```lua
approved_commands = {
  "^ls", -- Allow listing directories
  "^grep", -- Allow text search
  "^cat", -- Allow viewing files
  "^pytest", -- Allow running tests
}
```

2. Run Open Interpreter with limited privileges when possible
3. Consider setting up a sandboxed environment for command execution

## API

The plugin exposes several Lua functions for programmatic use:

```lua
-- Execute a shell command and get the result
local result = require("magenta-interpreter").execute_command("ls -la")

-- Check if the Open Interpreter server is running
local is_running = require("magenta-interpreter").is_server_running()

-- Start the Open Interpreter server manually
require("magenta-interpreter").start_server()
```

## Troubleshooting

If you encounter issues when setting up the plugin, try these steps:

1. **Run diagnostic command**: The plugin provides a built-in diagnostic tool that can help identify common issues:
   ```vim
   :MagentaInterpreterDebug
   ```
   This will check for required dependencies and proper module loading.

2. **Check dependencies**: Make sure both `plenary.nvim` and `magenta.nvim` are properly installed and loaded.

3. **Verify Open Interpreter**: Ensure Open Interpreter is installed and can run in server mode:
   ```bash
   pip install open-interpreter
   interpreter --server
   ```

4. **Check for configuration conflicts**: If you're using other plugins that modify Magenta's behavior, there might be conflicts.

5. **Debug logs**: You can enable more verbose logging by adding this to your config:
   ```lua
   vim.g.magenta_interpreter_debug = true
   ```

6. **Common issues**:
   - **"Module not found"**: Ensure your plugin manager is properly loading the plugin
   - **"Failed to connect to Open Interpreter"**: Check that the server is running on the configured port
   - **"Failed to register with Magenta"**: This may indicate an incompatible version of magenta.nvim

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT
