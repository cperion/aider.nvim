local WindowManager = require('aider.window_manager')
local BufferManager = require('aider.buffer_manager')
local CommandExecutor = require('aider.command_executor')
local config = require('aider.config')

local Aider = {}

function Aider.setup()
  WindowManager.setup()
  BufferManager.setup()
  CommandExecutor.setup()
  
  Aider.setup_autocommands()
  Aider.setup_keybindings()
end

function Aider.open(args, layout)
  local buf = BufferManager.get_or_create_aider_buffer()
  WindowManager.show_aider_window(buf, layout or config.get('default_layout'))
  
  if vim.api.nvim_buf_line_count(buf) == 1 and vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] == "" then
    CommandExecutor.start_aider(buf, args)
  end
end

function Aider.toggle(layout)
  if WindowManager.is_aider_window_open() then
    WindowManager.hide_aider_window()
  else
    Aider.open(nil, layout)
  end
end

function Aider.setup_autocommands()
  -- You can keep or modify existing autocommands as needed
end

function Aider.setup_keybindings()
  local keymap = vim.api.nvim_set_keymap
  local opts = {noremap = true, silent = true}
  
  keymap('n', config.get('keys.open'), ':lua require("aider.core").open()<CR>', opts)
  keymap('n', config.get('keys.toggle'), ':lua require("aider.core").toggle()<CR>', opts)
  -- Remove the 'stop' keybinding
end

return Aider
