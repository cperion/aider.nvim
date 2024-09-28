local BufferManager = {}
local aider_buf = nil
local aider_context = {}

function BufferManager.setup()
  BufferManager.update_context()
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
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local bufname = vim.api.nvim_buf_get_name(buf)
    local buftype = vim.api.nvim_buf_get_option(buf, "buftype")
    if BufferManager.should_include_in_context(bufname, buftype) then
      table.insert(context_buffers, bufname)
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

function BufferManager.update_context()
  aider_context = BufferManager.get_context_buffers()
end

function BufferManager.get_aider_context()
  return vim.deepcopy(aider_context)
end

return BufferManager
