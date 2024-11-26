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
    if layout == "vsplit" then
        -- Create a vertical split
        vim.cmd("botright vsplit")
        aider_win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(aider_win, buf)
    elseif layout == "hsplit" then
        -- Create a horizontal split
        vim.cmd("botright split")
        aider_win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(aider_win, buf)
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
            col = math.ceil((width - math.ceil(width * 0.8)) / 2)
        }

        aider_win = vim.api.nvim_open_win(buf, true, opts)
    end
	if not aider_win then
		Logger.error("Failed to create Aider window")
		vim.notify("Failed to create Aider window", vim.log.levels.ERROR)
	else
		Logger.debug("Aider window created successfully: " .. tostring(aider_win))
	end
end

function WindowManager.hide_aider_window()
    if aider_win and vim.api.nvim_win_is_valid(aider_win) then
        -- Get the window count before closing
        local window_count = vim.fn.winnr('$')
        
        -- If this is not the last window, close it normally
        if window_count > 1 then
            pcall(vim.api.nvim_win_close, aider_win, true)
        else
            -- If it's the last window, create a new empty buffer first
            vim.cmd('enew')
        end
    end
    aider_win = nil
end

function WindowManager.is_window_open()
	return aider_win ~= nil and vim.api.nvim_win_is_valid(aider_win)
end

return WindowManager
