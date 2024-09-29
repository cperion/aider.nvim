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

		-- Set buffert name
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
		if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_option(buf, "buflisted") then
			local bufname = vim.api.nvim_buf_get_name(buf)
			if BufferManager.should_include_in_context(bufname, vim.api.nvim_buf_get_option(buf, "buftype")) then
				table.insert(context_buffers, bufname)
			end
		end
	end
	return context_buffers
end

function BufferManager.should_include_in_context(bufname, buftype)
	return bufname ~= ""
		and not bufname:match("^term://")
		and buftype ~= "terminal"
		and bufname ~= "Aider"
		and vim.api.nvim_buf_get_option(0, "buflisted")
end

function BufferManager.update_context()
	local new_context = BufferManager.get_context_buffers()
	if not vim.deep_equal(aider_context, new_context) then
		aider_context = new_context
		require("aider.command_executor").update_aider_context()
	end
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
