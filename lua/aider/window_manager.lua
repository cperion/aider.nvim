local WindowManager = {}

local aider_win = nil

function WindowManager.setup()
	-- Any setup needed for window management
end

function WindowManager.show_aider_window(buf, layout)
	if layout == "float" then
		WindowManager.create_float_window(buf)
	elseif layout == "vsplit" then
		WindowManager.create_split_window(buf, "vertical")
	elseif layout == "hsplit" then
		WindowManager.create_split_window(buf, "horizontal")
	else
		error("Invalid layout: " .. layout)
	end
end

function WindowManager.create_float_window(buf)
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local opts = {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	}

	aider_win = vim.api.nvim_open_win(buf, true, opts)
	vim.api.nvim_win_set_option(aider_win, "winblend", 0)
end

function WindowManager.create_split_window(buf, direction)
    local width = vim.o.columns
    local height = vim.o.lines
    local opts = {
        relative = 'editor',
        style = 'minimal',
        focusable = true,
        border = 'none',
    }

    if direction == "vertical" then
        opts.width = math.floor(width / 2)
        opts.height = height
        opts.row = 0
        opts.col = 0
    else -- horizontal split
        opts.width = width
        opts.height = math.floor(height / 2)
        opts.row = 0
        opts.col = 0
    end

    aider_win = vim.api.nvim_open_win(buf, true, opts)
    vim.api.nvim_win_set_option(aider_win, "winblend", 0)
end

function WindowManager.hide_aider_window()
    if aider_win and vim.api.nvim_win_is_valid(aider_win) then
        vim.api.nvim_win_close(aider_win, true)
        aider_win = nil
    end
end

function WindowManager.is_aider_window_open()
	return aider_win ~= nil and vim.api.nvim_win_is_valid(aider_win)
end

return WindowManager
