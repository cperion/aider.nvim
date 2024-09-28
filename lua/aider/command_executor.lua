local config = require('aider.config')
local BufferManager = require('aider.buffer_manager')

local CommandExecutor = {}

local aider_job_id = nil

function CommandExecutor.setup()
  -- Any setup needed for command execution
end

function CommandExecutor.start_aider(buf, args)
  if aider_job_id then
    return  -- Aider is already running
  end

  args = args or ""
  local command = "aider " .. args .. " " .. table.concat(BufferManager.get_context_buffers(), " ")
  
  -- Ensure the buffer is modifiable
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  
  -- Clear the buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  
  -- Set the buffer as unmodified
  vim.api.nvim_buf_set_option(buf, "modified", false)
  
  aider_job_id = vim.fn.termopen(command, {
    on_exit = function(job_id, exit_code, event_type)
      CommandExecutor.on_aider_exit(exit_code)
    end
  })

  -- Set the buffer as non-modifiable after setup
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  
  vim.defer_fn(function()
    vim.cmd("startinsert")
  end, 100)
end

function CommandExecutor.stop_aider()
  if aider_job_id then
    vim.fn.jobstop(aider_job_id)
    aider_job_id = nil
  end
end

function CommandExecutor.run_aider_background(args, message)
  args = args or ""
  message = message or "Complete as many todo items as you can and remove the comment for any item you complete."
  
  local command = string.format('aider --msg "%s" %s %s', 
    message, 
    args, 
    table.concat(BufferManager.get_context_buffers(), " ")
  )

  vim.fn.jobstart({"bash", "-c", command}, {
    on_exit = function(job_id, exit_code, event_type)
      CommandExecutor.on_aider_background_exit(exit_code)
    end
  })

  vim.notify("Aider started in background " .. (args ~= "" and "with args: " .. args or ""))
end

function CommandExecutor.send_to_aider(command)
  if aider_job_id then
    vim.fn.chansend(aider_job_id, command .. "\n")
  end
end

function CommandExecutor.on_aider_exit(exit_code)
  vim.schedule(function()
    vim.notify("Aider finished with exit code " .. exit_code)
    aider_job_id = nil
  end)
end

function CommandExecutor.on_aider_background_exit(exit_code)
  vim.schedule(function()
    vim.notify("Background Aider finished with exit code " .. exit_code)
  end)
end

return CommandExecutor
