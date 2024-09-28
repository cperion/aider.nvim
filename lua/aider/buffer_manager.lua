local config = require('aider.config')

local BufferManager = {}

local aider_buf = nil

function BufferManager.setup()
  -- Any setup needed for buffer management
end

function BufferManager.get_or_create_aider_buffer()
  if aider_buf and vim.api.nvim_buf_is_valid(aider_buf) then
    -- Clear the existing buffer
    vim.api.nvim_buf_set_lines(aider_buf, 0, -1, false, {})
    vim.api.nvim_buf_set_option(aider_buf, "modified", false)
  else
    aider_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(aider_buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(aider_buf, "buflisted", false)
    vim.api.nvim_buf_set_name(aider_buf, "Aider")
  end

  return aider_buf
end

function BufferManager.on_buffer_open(bufnr)
  if not config.get('auto_manage_context') then return end
  
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
  
  if BufferManager.should_include_in_context(bufname, buftype) then
    local relative_filename = vim.fn.fnamemodify(bufname, ":~:.")
    CommandExecutor.send_to_aider("/add " .. relative_filename)
  end
end

function BufferManager.on_buffer_close(bufnr)
  if not config.get('auto_manage_context') then return end
  
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
  
  if BufferManager.should_include_in_context(bufname, buftype) then
    local relative_filename = vim.fn.fnamemodify(bufname, ":~:.")
    CommandExecutor.send_to_aider("/drop " .. relative_filename)
  end
end

function BufferManager.should_include_in_context(bufname, buftype)
  return bufname ~= "" and
         not bufname:match("^term://") and
         buftype ~= "terminal" and
         bufname ~= "Aider"
end

function BufferManager.get_context_buffers()
  local context_buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local bufname = vim.api.nvim_buf_get_name(buf)
    local buftype = vim.api.nvim_buf_get_option(buf, "buftype")
    if BufferManager.should_include_in_context(bufname, buftype) and buf ~= aider_buf then
      table.insert(context_buffers, bufname)
    end
  end
  return context_buffers
end

return BufferManager
