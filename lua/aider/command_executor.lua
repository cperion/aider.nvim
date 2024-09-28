local BufferManager = require('aider.buffer_manager')

local CommandExecutor = {}
local aider_job_id = nil

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
  
  vim.defer_fn(function()
    vim.cmd("startinsert")
  end, 100)
end

function CommandExecutor.update_aider_context()
  if aider_job_id then
    local context_buffers = BufferManager.get_aider_context()
    local update_command = table.concat(context_buffers, " ")
    vim.fn.chansend(aider_job_id, "/context " .. update_command .. "\n")
  end
end

function CommandExecutor.on_aider_exit(exit_code)
  aider_job_id = nil
  vim.schedule(function()
    vim.notify("Aider finished with exit code " .. exit_code)
  end)
end

return CommandExecutor
