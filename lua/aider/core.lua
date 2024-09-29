local WindowManager = require("aider.window_manager")
local BufferManager = require("aider.buffer_manager")
local CommandExecutor = require("aider.command_executor")
local ContextManager = require("aider.context_manager")
local config = require("aider.config")

local Aider = {}
local update_timer = nil

function Aider.setup()
    WindowManager.setup()
    BufferManager.setup()
    CommandExecutor.setup()
    ContextManager.setup()

    Aider.setup_autocommands()
    Aider.setup_keybindings()
end

function Aider.open(args, layout)
    local buf = BufferManager.get_aider_buffer()
    WindowManager.show_window(buf, layout or config.get("default_layout"))

    if vim.api.nvim_buf_line_count(buf) == 1 and vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] == "" then
        CommandExecutor.start_aider(buf, args)
    end
end

function Aider.toggle()
    if WindowManager.is_window_open() then
        WindowManager.hide_aider_window()
    else
        local buf = BufferManager.get_aider_buffer()
        local default_layout = config.get("default_layout")
        if default_layout then
            WindowManager.show_window(buf, default_layout)
        else
            -- Handle the case when default_layout is nil
            vim.notify("Default layout is not configured. Using 'float' as fallback.", vim.log.levels.WARN)
            WindowManager.show_window(buf, "float")
        end
    end
end

function Aider.cleanup()
    WindowManager.hide_window()
    CommandExecutor.stop_aider()
    -- Clear any other resources or state
end

function Aider.setup_autocommands()
    local aider_group = vim.api.nvim_create_augroup("AiderSync", { clear = true })

    vim.api.nvim_create_autocmd({ "BufEnter", "BufLeave", "BufWritePost" }, {
        group = aider_group,
        pattern = "*",  -- Change this to match all buffers
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
    update_timer = vim.loop.new_timer()
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
