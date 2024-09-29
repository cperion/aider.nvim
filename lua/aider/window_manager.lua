local WindowManager = {}
local aider_win = nil
local current_layout = nil

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
    current_layout = layout
end

function WindowManager.create_window(buf, layout)
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
    Logger.debug("Creating floating window for buffer: " .. tostring(buf))
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
        Logger.error("Invalid buffer handle: " .. tostring(buf))
        vim.notify("Invalid buffer handle", vim.log.levels.ERROR)
        return
    end

    local width = vim.api.nvim_get_option('columns')
    local height = vim.api.nvim_get_option('lines')
    local win_height = math.ceil(height * 0.8 - 4)
    local win_width = math.ceil(width * 0.8)
    local row = math.ceil((height - win_height) / 2 - 1)
    local col = math.ceil((width - win_width) / 2)

    local opts = {
        style = "minimal",
        relative = "editor",
        width = win_width,
        height = win_height,
        row = row,
        col = col,
        border = "rounded",
    }

    Logger.debug("Window options: " .. vim.inspect(opts))

    aider_win = vim.api.nvim_open_win(buf, true, opts)
    if not aider_win then
        Logger.error("Failed to create Aider window")
        vim.notify("Failed to create Aider window", vim.log.levels.ERROR)
    else
        Logger.debug("Aider window created successfully: " .. tostring(aider_win))
    end
end

function WindowManager.create_split_window(buf, direction)
    local width = vim.api.nvim_get_option('columns')
    local height = vim.api.nvim_get_option('lines')

    local opts = {
        style = "minimal",
        relative = "editor",
        width = direction == "vertical" and math.ceil(width / 2) or width,
        height = direction == "horizontal" and math.ceil(height / 2) or height,
        row = direction == "horizontal" and 0 or 0,
        col = direction == "vertical" and math.ceil(width / 2) or 0,
    }

    aider_win = vim.api.nvim_open_win(buf, true, opts)
end

function WindowManager.hide_aider_window()
    if aider_win and vim.api.nvim_win_is_valid(aider_win) then
        vim.api.nvim_win_close(aider_win, true)
    end
    aider_win = nil
end

function WindowManager.is_aider_window_open()
    return aider_win ~= nil and vim.api.nvim_win_is_valid(aider_win)
end

function WindowManager.is_window_open()
    return aider_win ~= nil and vim.api.nvim_win_is_valid(aider_win)
end

return WindowManager
