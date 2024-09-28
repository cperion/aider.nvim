local WindowManager = require('aider.window_manager')
local BufferManager = require('aider.buffer_manager')
local CommandExecutor = require('aider.command_executor')
local config = require('aider.config')

local Aider = {}

local aider_started = false

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
  
  if not aider_started then
    CommandExecutor.start_aider(buf, args)
    aider_started = true
  end
end

function Aider.toggle(layout)
  if WindowManager.is_aider_window_open() then
    WindowManager.hide_aider_window()
  else
    Aider.open(nil, layout)
  end
end

function Aider.stop()
  CommandExecutor.stop_aider()
  aider_started = false
  WindowManager.hide_aider_window()
end

function Aider.background(args, message)
  CommandExecutor.run_aider_background(args, message)
end

function Aider.setup_autocommands()
  vim.api.nvim_create_autocmd({"BufReadPost"}, {
    callback = function(ev)
      BufferManager.on_buffer_open(ev.buf)
    end,
  })
  
  vim.api.nvim_create_autocmd({"BufDelete"}, {
    callback = function(ev)
      BufferManager.on_buffer_close(ev.buf)
    end,
  })
end

function Aider.setup_keybindings()
  local keymap = vim.api.nvim_set_keymap
  local opts = {noremap = true, silent = true}
  
  keymap('n', config.get('keys.open'), ':lua require("aider.core").open()<CR>', opts)
  keymap('n', config.get('keys.toggle'), ':lua require("aider.core").toggle()<CR>', opts)
  keymap('n', config.get('keys.background'), ':lua require("aider.core").background()<CR>', opts)
  keymap('n', config.get('keys.stop'), ':lua require("aider.core").stop()<CR>', opts)
end

return Aider
