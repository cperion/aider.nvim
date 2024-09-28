local BufferManager = require('aider.buffer_manager')

local CommandExecutor = {}
local aider_job_id = nil
local current_context = {}

function CommandExecutor.setup()
  -- No setup needed for now
end

function CommandExecutor.start_aider(buf, args)
  args = args or ""
  local context_buffers = BufferManager.get_aider_context()
  local command = "aider " .. args .. " " .. table.concat(context_buffers, " ")
  
  -- Ensure the buffer is modifiable
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  
  -- Clear the buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  
  -- Set the buffer as unmodified
  vim.api.nvim_buf_set_option(buf, "modified", false)
  
  -- Create a terminal in the buffer
  aider_job_id = vim.fn.termopen(command, {
    on_exit = function(job_id, exit_code, event_type)
      CommandExecutor.on_aider_exit(exit_code)
    end
  })

  -- Set terminal-specific options
  vim.api.nvim_buf_set_option(buf, "buftype", "terminal")
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  
  -- Initialize the current_context
  current_context = vim.deepcopy(context_buffers)
  
  vim.defer_fn(function()
    vim.cmd("startinsert")
  end, 100)
end

function CommandExecutor.update_aider_context()
  if aider_job_id then
    local new_context = BufferManager.get_aider_context()
    
    -- Files to add (in new_context but not in current_context)
    for _, file in ipairs(new_context) do
      if not vim.tbl_contains(current_context, file) then
        vim.fn.chansend(aider_job_id, "/add " .. file .. "\n")
      end
    end
    
    -- Files to drop (in current_context but not in new_context)
    for _, file in ipairs(current_context) do
      if not vim.tbl_contains(new_context, file) then
        vim.fn.chansend(aider_job_id, "/drop " .. file .. "\n")
      end
    end
    
    -- Update the current_context
    current_context = vim.deepcopy(new_context)
  end
end

function CommandExecutor.on_aider_exit(exit_code)
  aider_job_id = nil
  current_context = {}
  vim.schedule(function()
    vim.notify("Aider finished with exit code " .. exit_code)
  end)
end

return CommandExecutor
