local Logger = require("aider.logger")

local WindowManager = {}
local aider_win = nil

function WindowManager.setup()
	-- Any setup needed for window management
end

function WindowManager.show_window(buf, layout)
    -- If there's an existing window, close it first
    if aider_win and vim.api.nvim_win_is_valid(aider_win) then
        WindowManager.hide_aider_window()
    end
    
    -- Create new window
    WindowManager.create_window(buf, layout)
end

function WindowManager.create_window(buf, layout)
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("create_window: Starting with layout " .. tostring(layout), correlation_id)

    if not buf or not vim.api.nvim_buf_is_valid(buf) then
        vim.notify("Invalid buffer provided to window manager", vim.log.levels.ERROR)
        Logger.error("Invalid buffer provided", correlation_id)
        return
    end

    local ok, err = pcall(function()
        if layout == "vsplit" then
            vim.cmd("botright vsplit")
            aider_win = vim.api.nvim_get_current_win()
            vim.api.nvim_win_set_buf(aider_win, buf)
        elseif layout == "hsplit" then
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
    end)

    if not ok then
        vim.notify("Failed to create window: " .. tostring(err), vim.log.levels.ERROR)
        Logger.error("Window creation failed: " .. tostring(err), correlation_id)
        return
    end

    if not aider_win then
        Logger.error("Failed to create Aider window", correlation_id)
        vim.notify("Failed to create Aider window", vim.log.levels.ERROR)
    else
        Logger.debug("Window created successfully: " .. tostring(aider_win), correlation_id)
    end
end

function WindowManager.hide_aider_window()
    if aider_win and vim.api.nvim_win_is_valid(aider_win) then
        -- Store the current window
        local current_win = vim.api.nvim_get_current_win()
        
        -- Focus the Aider window before closing it
        vim.api.nvim_set_current_win(aider_win)
        
        -- Get the window count
        local window_count = vim.fn.winnr('$')
        
        if window_count > 1 then
            -- Close the window and go back to previous window
            vim.cmd("quit")
            if vim.api.nvim_win_is_valid(current_win) then
                vim.api.nvim_set_current_win(current_win)
            end
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
