local Logger = require("aider.logger")
local BufferManager = {}
local aider_buf = nil
local aider_context = {}

function BufferManager.setup()
	BufferManager.update_context()
	aider_buf = BufferManager.get_or_create_aider_buffer()

	-- Set up autocommands for buffer events
	vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete" }, {
		callback = function(ev)
			-- Check if the buffer is valid and should be included in the context
			if BufferManager.should_include_in_context(ev.buf) then
				vim.schedule(BufferManager.update_context)
			end
		end,
	})
end

function BufferManager.get_valid_buffers()
	local valid_buffers = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if BufferManager.should_include_in_context(buf) then
			local bufname = vim.api.nvim_buf_get_name(buf)
			table.insert(valid_buffers, {
				id = buf,
				name = bufname,
				filetype = vim.api.nvim_get_option_value("filetype", { buf = buf }),
				modified = vim.api.nvim_get_option_value("modified", { buf = buf }),
			})
		end
	end
	return valid_buffers
end

function BufferManager.get_or_create_aider_buffer()
	if aider_buf and vim.api.nvim_buf_is_valid(aider_buf) then
		return aider_buf
	else
		aider_buf = vim.api.nvim_create_buf(false, true)
		if not aider_buf then
			vim.notify("Failed to create Aider buffer", vim.log.levels.ERROR)
			return nil
		end
		vim.api.nvim_buf_set_name(aider_buf, "Aider")
		vim.api.nvim_set_option_value("buftype", "nofile", { buf = aider_buf })
		vim.api.nvim_set_option_value("bufhidden", "hide", { buf = aider_buf })
		vim.api.nvim_set_option_value("swapfile", false, { buf = aider_buf })
		vim.api.nvim_set_option_value("buflisted", false, { buf = aider_buf })

		-- Add this line to set up the 'q' keybinding for the Aider buffer
		vim.api.nvim_buf_set_keymap(
			aider_buf,
			"n",
			"q",
			'<cmd>lua require("aider.core").toggle()<CR>',
			{ silent = true }
		)

		return aider_buf
	end
end

function BufferManager.get_aider_buffer()
	return BufferManager.get_or_create_aider_buffer()
end

function BufferManager.is_aider_buffer(buf)
	return buf == aider_buf
end

function BufferManager.get_context_buffers()
	local context_buffers = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if BufferManager.should_include_in_context(buf) then
			table.insert(context_buffers, vim.api.nvim_buf_get_name(buf))
		end
	end
	return context_buffers
end

function BufferManager.should_include_in_context(buf)
	local bufname = vim.api.nvim_buf_get_name(buf)
	local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
	return bufname ~= ""
		and not bufname:match("^term://")
		and buftype ~= "terminal"
		and not BufferManager.is_aider_buffer(buf)
end

function BufferManager.update_context()
	local correlation_id = Logger.generate_correlation_id()
	Logger.debug("Updating context", correlation_id)
	local start_time = os.clock() * 1000

	local valid_buffers = BufferManager.get_valid_buffers()
	Logger.debug("Current valid buffers: " .. vim.inspect(valid_buffers), correlation_id)

	local new_context = BufferManager.get_context_buffers()
	Logger.debug("Current context: " .. vim.inspect(aider_context), correlation_id)
	Logger.debug("New context: " .. vim.inspect(new_context), correlation_id)

	if not vim.deep_equal(aider_context, new_context) then
		Logger.debug("Context changed, updating Aider", correlation_id)
		aider_context = new_context
		require("aider.context_manager").update(new_context)
		local commands = require("aider.context_manager").get_batched_commands()
		if #commands > 0 then
			require("aider.command_executor").queue_commands(commands, true)
		end
	else
		Logger.debug("Context unchanged, no update needed", correlation_id)
	end

	local end_time = os.clock() * 1000
	Logger.debug(string.format("Context update operation took %.3f ms", (end_time - start_time)), correlation_id)
end

function BufferManager.get_aider_context()
	return vim.deepcopy(aider_context)
end

function BufferManager.get_files_to_drop()
	local current_buffers = BufferManager.get_context_buffers()
	local files_to_drop = {}
	for _, file in ipairs(aider_context) do
		if not vim.tbl_contains(current_buffers, file) then
			table.insert(files_to_drop, file)
		end
	end
	return files_to_drop
end

return BufferManager
