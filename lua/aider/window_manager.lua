local Logger = require("aider.logger")
local BufferManager = require("aider.buffer_manager")
local session = require("aider.session")

local WindowManager = {}

local function is_aider_window(win_id)
    local buf = vim.api.nvim_win_get_buf(win_id)
    return BufferManager.is_aider_buffer(buf)
end

function WindowManager.setup()
    -- No setup needed as dimensions are now initialized in session.lua
end

function WindowManager.save_layout()
    local correlation_id = Logger.generate_correlation_id()
    local state = session.get()

    -- Find current aider window if any
    local wins = vim.api.nvim_tabpage_list_wins(0)
    for _, win in ipairs(wins) do
        if is_aider_window(win) then
            local layout_dims = {
                width = vim.api.nvim_win_get_width(win),
                height = vim.api.nvim_win_get_height(win),
                pos = vim.fn.win_screenpos(win)
            }

            -- Save dimensions for current layout
            session.update({
                dimensions = layout_dims
            })
            
            Logger.debug("Saved window dimensions: " .. vim.inspect(layout_dims), correlation_id)
            return layout_dims
        end
    end

    Logger.debug("No aider window found to save layout", correlation_id)
    return nil
end

function WindowManager.show_window(buf, layout)
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("show_window: Starting with layout " .. tostring(layout), correlation_id)

    -- Always get fresh buffer reference
    buf = BufferManager.get_or_create_aider_buffer()
    
    -- Restore terminal state if available
    BufferManager.restore_terminal_state(buf)
    Logger.debug("Terminal state restored for buffer", correlation_id)

    -- Check for existing aider window
    local wins = vim.api.nvim_tabpage_list_wins(0)
    for _, win in ipairs(wins) do
        if is_aider_window(win) then
            vim.api.nvim_set_current_win(win)
            Logger.debug("Reusing existing window", correlation_id)
            return
        end
    end

    local win_id
    local state = session.get()
    local dims = state.dimensions[layout] or {}

    -- Create new window based on layout
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
        win_id = vim.api.nvim_open_win(buf, true, opts)
    else
        if layout == "vsplit" then
            local total_width = vim.api.nvim_win_get_width(0)
            vim.cmd("botright vsplit")
            win_id = vim.api.nvim_get_current_win()
            local new_width = dims.width or math.floor(total_width / 2)
            vim.api.nvim_win_set_width(win_id, new_width)
        else -- hsplit
            local total_height = vim.api.nvim_win_get_height(0)
            vim.cmd("botright split")
            win_id = vim.api.nvim_get_current_win()
            local new_height = dims.height or math.floor(total_height / 2)
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
        visible = true,
        layout = layout
    })

    -- Save current dimensions
    WindowManager.save_layout()
end

function WindowManager.hide_aider_window()
    local current_win = vim.api.nvim_get_current_win()
    local correlation_id = Logger.generate_correlation_id()
    
    local state = session.get()
    -- Preserve terminal state before hiding
    if state.buf_id then
        Logger.debug("Preserving terminal state before hiding window", correlation_id)
        BufferManager.preserve_terminal_state(state.buf_id)
    end
    
    -- Find and close all aider windows
    vim.tbl_map(function(win)
        if is_aider_window(win) then
            -- Save dimensions before closing
            WindowManager.save_layout()
            pcall(vim.api.nvim_win_close, win, true)
        end
    end, vim.api.nvim_tabpage_list_wins(0))

    -- Update session state - only UI visibility changes
    session.update({ visible = false })

    -- Restore focus to previous window if valid
    if current_win and vim.api.nvim_win_is_valid(current_win) and not is_aider_window(current_win) then
        pcall(vim.api.nvim_set_current_win, current_win)
    end

    Logger.debug("Aider window hidden, process state preserved", correlation_id)
    return true
end

function WindowManager.is_window_open()
    local wins = vim.api.nvim_tabpage_list_wins(0)
    return #vim.tbl_filter(is_aider_window, wins) > 0
end

return WindowManager
