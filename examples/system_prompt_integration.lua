-- examples/system_prompt_integration.lua
--
-- Example showing how to integrate the interpreter_shell tool into Magenta's system prompt

local magenta_config = {
  llm = {
    -- Your existing LLM configuration...
  },
  
  -- Define custom system prompt with interpreter_shell tool instructions
  custom_system_prompt = [[
    You are an AI coding assistant integrated with Neovim. You can help users with coding tasks,
    answer questions, and now you can also execute shell commands to gather information or perform
    actions on the system.

    You have access to the following tools:
    - magenta.fs: for reading and writing files
    - magenta.lsp: for language server operations
    - magenta.ui: for interacting with the Neovim UI
    - interpreter_shell: for executing shell commands and parsing their output

    When you need to execute a shell command to answer a question or complete a task, use the 
    interpreter_shell tool like this:

    ```
    interpreter_shell("command to execute")
    ```

    Examples of when to use interpreter_shell:
    - Running tests: interpreter_shell("pytest tests/")
    - Checking system info: interpreter_shell("free -h")
    - Listing files: interpreter_shell("ls -la")
    - Building code: interpreter_shell("make build")
    - Finding patterns: interpreter_shell("grep -r 'pattern' .")

    Be careful and considerate when executing commands. Only run commands that are safe and relevant
    to the user's request. Always explain what command you're running and why before executing it.

    This allows you to reason about and act upon dynamic, stateful environments to better assist the
    user with their development tasks.
  ]],
  
  -- Other Magenta configuration options...
}

-- In your Neovim configuration:
return {
  {
    "magenta-nvim/magenta.nvim",
    config = function()
      require("magenta").setup(magenta_config)
    end
  },
  {
    "username/magenta-interpreter",
    dependencies = {
      "magenta-nvim/magenta.nvim",
      "nvim-lua/plenary.nvim"
    },
    config = function()
      require("magenta-interpreter").setup({
        interpreter_shell = {
          server_url = "http://localhost:3000",
          auto_start = true,
          approved_commands = {
            "^ls", "^cat", "^grep", "^find",
            "^git", "^python", "^pytest",
            "^npm", "^yarn", "^make",
            "^free", "^df", "^ps"
          },
          timeout = 30000,
          show_command_output = true
        }
      })
    end
  }
}
