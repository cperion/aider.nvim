local WindowManager = require("aider.window_manager")
local BufferManager = require("aider.buffer_manager")
local CommandExecutor = require("aider.command_executor")
local config = require("aider.config")
local Logger = require("aider.logger")

local Aider = {}
local update_timer = nil

function Aider.setup()
    Logger.setup()
    Logger.debug("Aider.setup: Starting Aider setup")
    Logger.debug("Aider.setup: User config: " .. vim.inspect(config.get_all()))
    WindowManager.setup()
    BufferManager.setup()
    CommandExecutor.setup()

    Aider.setup_autocommands()
    Aider.setup_keybindings()
    Logger.debug("Aider.setup: Aider setup complete")
end

function Aider.open(args, layout)
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("Opening Aider window", correlation_id)
    Logger.debug("Args: " .. vim.inspect(args) .. ", Layout: " .. tostring(layout), correlation_id)
    local buf = BufferManager.get_aider_buffer()
    WindowManager.show_window(buf, layout or config.get("default_layout"))

    if vim.api.nvim_buf_line_count(buf) == 1 and vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] == "" then
        CommandExecutor.start_aider(buf, args)
    end
    Logger.debug("Aider window opened", correlation_id)
end

function Aider.toggle()
    local correlation_id = Logger.generate_correlation_id()
    local is_open = WindowManager.is_window_open()
    Logger.debug("Toggling Aider window. Current state: " .. (is_open and "open" or "closed"), correlation_id)
    if is_open then
        WindowManager.hide_aider_window()
    else
        local buf = BufferManager.get_aider_buffer()
        local default_layout = config.get("default_layout")
        if default_layout then
            WindowManager.show_window(buf, default_layout)
        else
            Logger.warn("Default layout is not configured. Using 'float' as fallback.", correlation_id)
            WindowManager.show_window(buf, "float")
        end
    end
    Logger.debug("New state: " .. (WindowManager.is_window_open() and "open" or "closed"), correlation_id)
end

function Aider.cleanup()
    Logger.info("Cleaning up Aider")
    WindowManager.hide_aider_window()
    CommandExecutor.stop_aider()
    Logger.cleanup()
    -- Clear any other resources or state
    Logger.info("Aider cleanup complete")
end

function Aider.setup_autocommands()
    local aider_group = vim.api.nvim_create_augroup("AiderSync", { clear = true })

    vim.api.nvim_create_autocmd({ "BufEnter", "BufLeave", "BufWritePost" }, {
        group = aider_group,
        pattern = "*",
        callback = function()
            require('aider.core').debounce_update()
        end,
    })

    vim.api.nvim_create_autocmd("BufEnter", {
        group = aider_group,
        pattern = "Aider",
        callback = function()
            require('aider.core').on_aider_buffer_enter()
        end,
    })
end

function Aider.debounce_update()
    if update_timer then
        update_timer:stop()
    end
    local timer_ok, new_timer = pcall(vim.loop.new_timer)
    if not timer_ok then
        Logger.error("Failed to create timer: " .. tostring(new_timer))
        return
    end
    update_timer = new_timer
    update_timer:start(1000, 0, vim.schedule_wrap(function()
        local new_context = BufferManager.get_context_buffers()
        if not vim.deep_equal(BufferManager.get_aider_context(), new_context) then
            BufferManager.update_context()
            CommandExecutor.update_aider_context()
        end
    end))
end

function Aider.on_aider_buffer_enter()
    BufferManager.update_context()
    CommandExecutor.update_aider_context()
end

function Aider.setup_keybindings()
    local open_key = config.get("keys.open") or "<leader> "
    local toggle_key = config.get("keys.toggle") or "<leader>at"

    vim.keymap.set("n", open_key, function()
        require("aider.core").open()
    end, { silent = true })

    vim.keymap.set("n", toggle_key, function()
        require("aider.core").toggle()
    end, { silent = true })
end

return Aider
