local WindowManager = require("aider.window_manager")
local BufferManager = require("aider.buffer_manager")
local CommandExecutor = require("aider.command_executor")
local config = require("aider.config")

local Aider = {}
local update_timer = nil

function Aider.setup()
	WindowManager.setup()
	BufferManager.setup()
	CommandExecutor.setup()

	Aider.setup_autocommands()
	Aider.setup_keybindings()
end

function Aider.open(args, layout)
	local buf = BufferManager.get_or_create_aider_buffer()
	WindowManager.show_aider_window(buf, layout or config.get("default_layout"))

	if vim.api.nvim_buf_line_count(buf) == 1 and vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] == "" then
		CommandExecutor.start_aider(buf, args)
	end
end

function Aider.toggle(layout)
	if WindowManager.is_aider_window_open() then
		WindowManager.hide_aider_window()
	else
		Aider.open(nil, layout)
	end
end

function Aider.setup_autocommands()
    local aider_group = vim.api.nvim_create_augroup("AiderSync", { clear = true })

    vim.api.nvim_create_autocmd({ "BufEnter", "BufLeave", "BufWritePost" }, {
        group = aider_group,
        pattern = "Aider",
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
    else
        update_timer = vim.loop.new_timer()
    end

    update_timer:start(1000, 0, vim.schedule_wrap(function()
        BufferManager.update_context()
        CommandExecutor.update_aider_context()
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
