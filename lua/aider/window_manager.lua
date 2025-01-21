local Logger = require("aider.logger")
local BufferManager = require("aider.buffer_manager")
local session = require("aider.session")

local WindowManager = {}

local function is_aider_window(win_id)
    -- Protected window and buffer checks
    local ok, buf = pcall(vim.api.nvim_win_get_buf, win_id)
    if not ok or not buf then
        return false
    end
    
    return BufferManager.is_aider_buffer(buf)
end

function WindowManager.setup()
    -- No setup needed as dimensions are now initialized in session.lua
end

function WindowManager.save_layout()
    local correlation_id = Logger.generate_correlation_id()
    local state = session.get()
    
    -- Find valid aider window and get its dimensions
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win) and is_aider_window(win) then
            -- Protected dimension gathering
            local ok, layout_dims = pcall(function()
                return {
                    width = vim.api.nvim_win_get_width(win),
                    height = vim.api.nvim_win_get_height(win),
                    pos = vim.fn.win_screenpos(win)
                }
            end)
            
            if ok and layout_dims then
                -- Save dimensions for current layout
                session.update({
                    dimensions = layout_dims
                })
                
                Logger.debug("Saved window dimensions: " .. vim.inspect(layout_dims), correlation_id)
                return layout_dims
            else
                Logger.warn("Failed to get window dimensions", correlation_id)
                return nil
            end
        end
    end

    Logger.debug("No valid aider window found to save layout", correlation_id)
    return nil
end

function WindowManager.show_window(buf, layout)
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("show_window: Starting with layout " .. tostring(layout), correlation_id)

    -- Validate buffer first
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
        Logger.error("Invalid buffer in show_window", correlation_id)
        buf = BufferManager.get_or_create_aider_buffer()
        if not buf then
            Logger.error("Failed to create buffer", correlation_id)
            return
        end
    end
    
    -- Restore terminal state if available
    BufferManager.restore_terminal_state(buf)
    Logger.debug("Terminal state restored for buffer", correlation_id)

    -- Check for existing aider window and reuse if valid
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win) and is_aider_window(win) then
            -- Update buffer in existing window
            pcall(vim.api.nvim_win_set_buf, win, buf)
            vim.api.nvim_set_current_win(win)
            Logger.debug("Reusing existing window", correlation_id)
            return
        end
    end

    -- Get layout dimensions
    local state = session.get()
    local dims = state.dimensions[layout] or {}
    local new_win

    -- Create new window based on layout with error handling
    local ok, err = pcall(function()
        if layout == "float" then
            local width = vim.o.columns
            local height = vim.o.lines

            local win_width = dims.width or math.ceil(width * 0.8)
            local win_height = dims.height or math.ceil(height * 0.8 - 4)
            local win_row = dims.pos and dims.pos[1] or math.ceil((height - win_height) / 2 - 1)
            local win_col = dims.pos and dims.pos[2] or math.ceil((width - win_width) / 2)

            local opts = {
                style = "minimal",
                relative = "editor",
                border = "rounded",
                width = win_width,
                height = win_height,
                row = win_row,
                col = win_col,
            }
            new_win = vim.api.nvim_open_win(buf, true, opts)
        else
            if layout == "vsplit" then
                local total_width = vim.api.nvim_win_get_width(0)
                vim.cmd("botright vsplit")
                new_win = vim.api.nvim_get_current_win()
                local new_width = dims.width or math.floor(total_width / 2)
                vim.api.nvim_win_set_width(new_win, new_width)
            else -- hsplit
                local total_height = vim.api.nvim_win_get_height(0)
                vim.cmd("botright split")
                new_win = vim.api.nvim_get_current_win()
                local new_height = dims.height or math.floor(total_height / 2)
                vim.api.nvim_win_set_height(new_win, new_height)
            end
            
            -- Set the buffer in the window
            vim.api.nvim_win_set_buf(new_win, buf)
        end

        -- Set window options if window was created successfully
        if new_win and vim.api.nvim_win_is_valid(new_win) then
            vim.wo[new_win].winfixheight = true
            vim.wo[new_win].winfixwidth = true
            vim.wo[new_win].number = false
            vim.wo[new_win].relativenumber = false

            -- Update session state only on success
            session.update({
                visible = true,
                layout = layout
            })

            -- Save current dimensions
            WindowManager.save_layout()
            
            Logger.debug("Created new window successfully", correlation_id)
        end
    end)

    if not ok then
        Logger.error("Failed to create window: " .. tostring(err), correlation_id)
        return
    end
end

function WindowManager.hide_aider_window()
    local current_win = vim.api.nvim_get_current_win()
    local correlation_id = Logger.generate_correlation_id()
    
    -- Get state and buffer reference first
    local state = session.get()
    local buf = state.buf_id
    
    -- Preserve terminal state before any window operations
    if buf and vim.api.nvim_buf_is_valid(buf) then
        Logger.debug("Preserving terminal state before hiding window", correlation_id)
        local ok, err = pcall(BufferManager.preserve_terminal_state, buf)
        if not ok then
            Logger.error("Failed to preserve terminal state: " .. tostring(err), correlation_id)
        end
    end
    
    -- Save layout before closing any windows
    local layout_saved = pcall(WindowManager.save_layout)
    if not layout_saved then
        Logger.warn("Failed to save window layout", correlation_id)
    end
    
    -- Find and close all aider windows
    local closed_count = 0
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win) and is_aider_window(win) then
            local ok = pcall(vim.api.nvim_win_close, win, true)
            if ok then
                closed_count = closed_count + 1
            end
        end
    end
    
    -- Update session state
    session.update({ visible = false })
    
    -- Restore focus to previous window if valid
    if current_win and vim.api.nvim_win_is_valid(current_win)
       and not is_aider_window(current_win) then
        pcall(vim.api.nvim_set_current_win, current_win)
    end

    Logger.debug(string.format("Closed %d aider windows, process state preserved",
        closed_count), correlation_id)
    return true
end

function WindowManager.is_window_open()
    local wins = vim.api.nvim_tabpage_list_wins(0)
    return #vim.tbl_filter(is_aider_window, wins) > 0
end

return WindowManager
