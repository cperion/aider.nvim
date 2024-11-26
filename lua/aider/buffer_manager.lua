local Logger = require("aider.logger")
local config = require("aider.config")
local BufferManager = {}
local aider_buf = nil
local aider_context = {}

function BufferManager.setup()
	BufferManager.update_context()
	aider_buf = BufferManager.get_or_create_aider_buffer()
end

function BufferManager.get_valid_buffers()
    local valid_buffers = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and BufferManager.should_include_in_context(buf) then
            local bufname = vim.api.nvim_buf_get_name(buf)
            table.insert(valid_buffers, {
                id = buf,
                name = bufname,
                filetype = vim.api.nvim_buf_get_option(buf, "filetype"),
                modified = vim.api.nvim_buf_get_option(buf, "modified"),
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
		
		-- Set buffer options
		vim.api.nvim_set_option_value("buftype", "nofile", { buf = aider_buf })
		vim.api.nvim_set_option_value("bufhidden", "hide", { buf = aider_buf })
		vim.api.nvim_set_option_value("swapfile", false, { buf = aider_buf })
		vim.api.nvim_set_option_value("buflisted", false, { buf = aider_buf })
		vim.api.nvim_set_option_value("modifiable", true, { buf = aider_buf })

		-- Add the 'q' keybinding for the Aider buffer
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

function BufferManager.get_active_buffers()
    local valid_buffers = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if BufferManager.should_include_in_context(buf) then
            local bufname = vim.api.nvim_buf_get_name(buf)
            table.insert(valid_buffers, bufname)
        end
    end
    return valid_buffers
end

function BufferManager.get_context_buffers()
    return BufferManager.get_active_buffers()
end

function BufferManager.should_include_in_context(buf)
    local bufname = vim.api.nvim_buf_get_name(buf)
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
    local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf })
    local filesize = vim.fn.getfsize(bufname)
    local buflisted = vim.api.nvim_get_option_value("buflisted", { buf = buf })
    local hidden = vim.api.nvim_get_option_value("bufhidden", { buf = buf })
    
    -- Check if buffer is a regular listed buffer that should be included
    local is_regular_buffer = buflisted 
        and hidden ~= "delete"
        and buftype == ""  -- Only regular files
        and not BufferManager.is_aider_buffer(buf)
    
    -- Only include files that exist and are within size limits
    local is_valid_file = bufname ~= ""
        and vim.fn.filereadable(bufname) == 1
        and filesize > 0
        and filesize < config.get("max_context_file_size")
    
    return is_regular_buffer and is_valid_file
end

function BufferManager.update_context()
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("Updating context", correlation_id)
    local start_time = os.clock() * 1000

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
