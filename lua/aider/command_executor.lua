local BufferManager = require("aider.buffer_manager")
local ContextManager = require("aider.context_manager")

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
	vim.bo[buf].modifiable = true

	-- Clear the buffer content
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

	-- Set the buffer as unmodified
	vim.bo[buf].modified = false

	-- Create a terminal in the buffer
	aider_job_id = vim.fn.termopen(command, {
		on_exit = function(_, exit_code, _)
			CommandExecutor.on_aider_exit(exit_code)
		end,
	})

	-- Set terminal-specific options
	vim.bo[buf].buftype = "terminal"
	vim.bo[buf].modifiable = false

	-- Initialize the context
	ContextManager.update(context_buffers)

	vim.defer_fn(function()
		vim.cmd("startinsert")
	end, 100)
end

function CommandExecutor.update_aider_context()
    if aider_job_id then
        local new_context = BufferManager.get_aider_context()
        local files_to_drop = BufferManager.get_files_to_drop()
        ContextManager.update(new_context)
        local commands = ContextManager.get_batched_commands()

        if #files_to_drop > 0 then
            table.insert(commands, "/drop " .. table.concat(files_to_drop, " "))
        end

        if #commands > 0 then
            CommandExecutor.execute_commands(commands)
        end
    end
end

function CommandExecutor.execute_commands(commands)
	if aider_job_id then
		local command_string = table.concat(commands, "\n") .. "\n"
		vim.api.nvim_chan_send(aider_job_id, command_string)
	else
		vim.notify("Aider job is not running", vim.log.levels.WARN)
	end
end

function CommandExecutor.on_aider_exit(exit_code)
	aider_job_id = nil
	ContextManager.update({})
	vim.schedule(function()
		if exit_code ~= nil then
			vim.notify("Aider finished with exit code " .. tostring(exit_code))
		else
			vim.notify("Aider finished")
		end
	end)
end

return CommandExecutor
