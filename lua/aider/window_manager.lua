local Logger = require("aider.logger")
local BufferManager = require("aider.buffer_manager")
local session = require("aider.session")

local WindowManager = {}

function WindowManager.setup()
    -- Initialize with default dimensions
    if not session.get().dimensions then
        session.update({
            dimensions = {
                width = nil,
                height = nil,
                pos = nil
            }
        })
    end
end

function WindowManager.save_layout()
    local correlation_id = Logger.generate_correlation_id()
    local state = session.get()
    
    if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
        local layout_cache = {
            width = vim.api.nvim_win_get_width(state.win_id),
            height = vim.api.nvim_win_get_height(state.win_id),
            position = vim.fn.win_screenpos(state.win_id),
            layout = state.layout
        }
        
        session.update({ layout_cache = layout_cache })
        Logger.debug("Saved window layout: " .. vim.inspect(layout_cache), correlation_id)
        return layout_cache
    end
    
    Logger.debug("No valid window to save layout", correlation_id)
    return nil
end

function WindowManager.restore_layout(win_id, force_layout)
    local correlation_id = Logger.generate_correlation_id()
    local state = session.get()
    local layout_cache = state.layout_cache
    
    if not layout_cache then
        Logger.debug("No layout cache to restore", correlation_id)
        return
    end
    
    if win_id and vim.api.nvim_win_is_valid(win_id) then
        Logger.debug("Restoring window layout: " .. vim.inspect(layout_cache), correlation_id)
        
        -- Restore window dimensions
        pcall(vim.api.nvim_win_set_width, win_id, layout_cache.width)
        pcall(vim.api.nvim_win_set_height, win_id, layout_cache.height)
        
        -- Update session with new window ID and restored layout
        session.update({
            win_id = win_id,
            layout = force_layout or layout_cache.layout
        })
        
        Logger.debug("Window layout restored", correlation_id)
    else
        Logger.debug("No valid window to restore layout", correlation_id)
    end
end

function WindowManager.show_window(buf, layout)
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("show_window: Starting with layout " .. tostring(layout), correlation_id)
    
    -- Always get fresh buffer reference
    buf = BufferManager.get_or_create_aider_buffer()
    
    local state = session.get()
    -- If there's an existing window, just focus it
    if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
        vim.api.nvim_win_set_buf(state.win_id, buf)
        vim.api.nvim_set_current_win(state.win_id)
        Logger.debug("Reusing existing window", correlation_id)
        return
    end
    
    local win_id
    -- Create new window
    if layout == "float" then
        local width = vim.o.columns
        local height = vim.o.lines
        
        -- Use stored dimensions or calculate new ones
        local win_width = state.dimensions.width or math.ceil(width * 0.8)
        local win_height = state.dimensions.height or math.ceil(height * 0.8 - 4)
        local win_row = state.dimensions.pos and state.dimensions.pos[1] or math.ceil((height - win_height) / 2 - 1)
        local win_col = state.dimensions.pos and state.dimensions.pos[2] or math.ceil((width - win_width) / 2)
        
        local opts = {
            style = "minimal",
            relative = "editor",
            border = "rounded",
            width = win_width,
            height = win_height,
            row = win_row,
            col = win_col
        }
        win_id = vim.api.nvim_open_win(buf, true, opts)
    else
        if layout == "vsplit" then
            -- Get current window width and set new width to stored value or 50%
            local total_width = vim.api.nvim_win_get_width(0)
            vim.cmd("botright vsplit")
            local new_width = state.dimensions.width or math.floor(total_width/2)
            win_id = vim.api.nvim_get_current_win()
            vim.api.nvim_win_set_width(win_id, new_width)
        else -- hsplit
            -- Get current window height and set new height to stored value or 50%
            local total_height = vim.api.nvim_win_get_height(0)
            vim.cmd("botright split")
            local new_height = state.dimensions.height or math.floor(total_height/2)
            win_id = vim.api.nvim_get_current_win()
            vim.api.nvim_win_set_height(win_id, new_height)
        end
    end
    
    -- Set the buffer in the window
    vim.api.nvim_win_set_buf(win_id, buf)
    
    -- Set window options
    vim.wo[win_id].winfixheight = true
    vim.wo[win_id].winfixwidth = true
    vim.wo[win_id].number = false
    vim.wo[win_id].relativenumber = false
    
    -- Update session state
    session.update({
        win_id = win_id,
        visible = true,
        layout = layout
    })
end

function WindowManager.hide_aider_window()
    local state = session.get()
    if state.visible and state.win_id then
        local current_win = vim.api.nvim_get_current_win()
        local success = true
        
        -- Save window dimensions before closing
        if vim.api.nvim_win_is_valid(state.win_id) then
            local dimensions = {
                width = vim.api.nvim_win_get_width(state.win_id),
                height = vim.api.nvim_win_get_height(state.win_id),
                pos = vim.fn.win_screenpos(state.win_id)
            }
            
            success = pcall(function()
                vim.api.nvim_win_close(state.win_id, true)
            end)
            
            if success then
                session.update({
                    visible = false,
                    win_id = nil,
                    dimensions = dimensions
                })
            end
        end

        if success and current_win ~= state.win_id and vim.api.nvim_win_is_valid(current_win) then
            pcall(vim.api.nvim_set_current_win, current_win)
        end

        return success
    end
    return true
end

function WindowManager.is_window_open()
    local state = session.get()
    return state.visible and state.win_id and vim.api.nvim_win_is_valid(state.win_id)
end

return WindowManager
