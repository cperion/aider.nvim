local BufferManager = {}
local aider_buf = nil
local aider_context = {}

function BufferManager.setup()
    BufferManager.update_context()
    aider_buf = BufferManager.get_or_create_aider_buffer()
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
        vim.api.nvim_buf_set_option(aider_buf, "buftype", "nofile")
        vim.api.nvim_buf_set_option(aider_buf, "bufhidden", "hide")
        vim.api.nvim_buf_set_option(aider_buf, "swapfile", false)
        vim.api.nvim_buf_set_option(aider_buf, "buflisted", false)
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
    local current_buf = vim.api.nvim_get_current_buf()
    if BufferManager.should_include_in_context(current_buf) then
        return { vim.api.nvim_buf_get_name(current_buf) }
    end
    return {}
end

function BufferManager.should_include_in_context(buf)
    local bufname = vim.api.nvim_buf_get_name(buf)
    local buftype = vim.api.nvim_buf_get_option(buf, 'buftype')
    return bufname ~= "" and not bufname:match("^term://") and buftype ~= "terminal" and bufname ~= "Aider"
end

function BufferManager.update_context()
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("Updating context", correlation_id)
    local start_time = vim.loop.hrtime()
    local new_context = BufferManager.get_context_buffers()
    Logger.debug("Current context: " .. vim.inspect(aider_context), correlation_id)
    Logger.debug("New context: " .. vim.inspect(new_context), correlation_id)
    if not vim.deep_equal(aider_context, new_context) then
        Logger.info("Context changed, updating Aider", correlation_id)
        aider_context = new_context
        require("aider.command_executor").update_aider_context()
    else
        Logger.debug("Context unchanged, no update needed", correlation_id)
    end
    local end_time = vim.loop.hrtime()
    Logger.debug(string.format("Context update operation took %.3f ms", (end_time - start_time) / 1e6), correlation_id)
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
