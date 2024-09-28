local config = require('aider.config')

local BufferManager = {}

local aider_buf = nil

function BufferManager.setup()
  -- No setup needed for now
end

function BufferManager.get_or_create_aider_buffer()
  if aider_buf and vim.api.nvim_buf_is_valid(aider_buf) then
    return aider_buf
  else
    -- Create a new buffer with 'nofile' type
    aider_buf = vim.api.nvim_create_buf(false, true)
    
    -- Set buffer name
    vim.api.nvim_buf_set_name(aider_buf, "Aider")
    
    -- Set buffer options
    vim.api.nvim_buf_set_option(aider_buf, "bufhidden", "hide")
    vim.api.nvim_buf_set_option(aider_buf, "swapfile", false)
    vim.api.nvim_buf_set_option(aider_buf, "buflisted", false)
  end

  return aider_buf
end

function BufferManager.get_context_buffers()
  local context_buffers = {}
  local current_buf = BufferManager.get_current_buffer()
  local current_bufname = vim.api.nvim_buf_get_name(current_buf)
  
  -- Add the current buffer first if it's valid
  if BufferManager.should_include_in_context(current_bufname, vim.api.nvim_buf_get_option(current_buf, "buftype")) then
    table.insert(context_buffers, current_bufname)
  end
  
  -- Get the directory of the current file
  local current_dir = vim.fn.fnamemodify(current_bufname, ":h")
  
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local bufname = vim.api.nvim_buf_get_name(buf)
    local buftype = vim.api.nvim_buf_get_option(buf, "buftype")
    if BufferManager.should_include_in_context(bufname, buftype) and buf ~= aider_buf and buf ~= current_buf then
      -- Check if the buffer is in the same directory as the current file
      if vim.fn.fnamemodify(bufname, ":h") == current_dir then
        table.insert(context_buffers, bufname)
      end
    end
  end
  return context_buffers
end

function BufferManager.should_include_in_context(bufname, buftype)
  return bufname ~= "" and
         not bufname:match("^term://") and
         buftype ~= "terminal" and
         bufname ~= "Aider"
end

function BufferManager.get_current_buffer()
  return vim.api.nvim_get_current_buf()
end

return BufferManager
