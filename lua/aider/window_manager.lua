local Logger = require("aider.logger")

local WindowManager = {}
local aider_win = nil

function WindowManager.setup()
	-- Any setup needed for window management
end

function WindowManager.show_window(buf, layout)
	if aider_win and vim.api.nvim_win_is_valid(aider_win) then
		vim.api.nvim_set_current_win(aider_win)
		vim.api.nvim_win_set_buf(aider_win, buf)
	else
		WindowManager.create_window(buf, layout)
	end
end

function WindowManager.create_window(buf, layout)
	local width = vim.o.columns
	local height = vim.o.lines

	local opts = {
		style = "minimal",
		relative = "editor",
		border = "rounded",
	}

	if layout == "float" then
		opts.width = math.ceil(width * 0.8)
		opts.height = math.ceil(height * 0.8 - 4)
		opts.row = math.ceil((height - opts.height) / 2 - 1)
		opts.col = math.ceil((width - opts.width) / 2)
	elseif layout == "vsplit" then
		opts.width = math.ceil(width / 2)
		opts.height = height
		opts.row = 0
		opts.col = math.ceil(width / 2)
	elseif layout == "hsplit" then
		opts.width = width
		opts.height = math.ceil(height / 2)
		opts.row = math.ceil(height / 2)
		opts.col = 0
	else
		error("Invalid layout: " .. layout)
	end

	aider_win = vim.api.nvim_open_win(buf, true, opts)
	if not aider_win then
		Logger.error("Failed to create Aider window")
		vim.notify("Failed to create Aider window", vim.log.levels.ERROR)
	else
		Logger.debug("Aider window created successfully: " .. tostring(aider_win))
	end
end

function WindowManager.hide_aider_window()
	if aider_win and vim.api.nvim_win_is_valid(aider_win) then
		vim.api.nvim_win_close(aider_win, true)
	end
	aider_win = nil
end

function WindowManager.is_window_open()
	return aider_win ~= nil and vim.api.nvim_win_is_valid(aider_win)
end

return WindowManager
