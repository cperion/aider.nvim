local Logger = require("aider.logger")

local WindowManager = {}
local aider_win = nil

function WindowManager.setup()
	-- Any setup needed for window management
end

function WindowManager.show_window(buf, layout)
	local correlation_id = Logger.generate_correlation_id()
	Logger.debug("show_window: Starting with layout " .. tostring(layout), correlation_id)

	-- If there's an existing window, just focus it
	if WindowManager.is_window_open() then
		if aider_win and vim.api.nvim_win_is_valid(aider_win) then
		    vim.api.nvim_set_current_win(aider_win)
		end
		return
	end

	-- Create new window only if one doesn't exist
	if layout == "vsplit" then
		-- Get current window width and set new width to 50%
		local width = vim.api.nvim_win_get_width(0)
		vim.cmd("botright vsplit")
		vim.api.nvim_win_set_width(vim.api.nvim_get_current_win(), math.floor(width/2))
	elseif layout == "hsplit" then
		-- Get current window height and set new height to 50%
		local height = vim.api.nvim_win_get_height(0)
		vim.cmd("botright split")
		vim.api.nvim_win_set_height(vim.api.nvim_get_current_win(), math.floor(height/2))
	else -- float layout
		local width = vim.o.columns
		local height = vim.o.lines
		local opts = {
			style = "minimal",
			relative = "editor",
			border = "rounded",
			width = math.ceil(width * 0.8),
			height = math.ceil(height * 0.8 - 4),
			row = math.ceil((height - math.ceil(height * 0.8 - 4)) / 2 - 1),
			col = math.ceil((width - math.ceil(width * 0.8)) / 2),
		}
		aider_win = vim.api.nvim_open_win(buf, true, opts)
	end

	-- Set the window and buffer
	if not aider_win then
		aider_win = vim.api.nvim_get_current_win()
	end

	-- Set the buffer in the window
	vim.api.nvim_win_set_buf(aider_win, buf)

	-- Set window options
	vim.wo[aider_win].winfixheight = true
	vim.wo[aider_win].winfixwidth = true
end

function WindowManager.hide_aider_window()
	if WindowManager.is_window_open() then
		-- Store the current window
		local current_win = vim.api.nvim_get_current_win()

		-- Close the window instead of hiding it
		if aider_win and vim.api.nvim_win_is_valid(aider_win) then
		    vim.api.nvim_win_close(aider_win, true)
		end

		-- Return to the previous window if it's still valid
		if current_win ~= aider_win and vim.api.nvim_win_is_valid(current_win) then
			vim.api.nvim_set_current_win(current_win)
		end

		-- Clear the window reference
		aider_win = nil
	end
end

function WindowManager.is_window_open()
	return aider_win ~= nil and vim.api.nvim_win_is_valid(aider_win)
end

return WindowManager
