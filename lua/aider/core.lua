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
    vim.cmd([[
    augroup AiderSync
      autocmd!
      autocmd BufEnter,BufLeave,BufWritePost * lua require('aider.core').debounce_update()
      autocmd BufEnter Aider lua require('aider.core').on_aider_buffer_enter()
    augroup END
  ]])
end

function Aider.debounce_update()
    if update_timer then
        vim.fn.timer_stop(update_timer)
    end
    update_timer = vim.fn.timer_start(1000, function()
        BufferManager.update_context()
        CommandExecutor.update_aider_context()
    end)
end

function Aider.on_aider_buffer_enter()
    BufferManager.update_context()
    CommandExecutor.update_aider_context()
end

function Aider.setup_keybindings()
    local keymap = vim.api.nvim_set_keymap
    local opts = { noremap = true, silent = true }

    local open_key = config.get("keys.open") or "<leader> "
    local toggle_key = config.get("keys.toggle") or "<leader>at"

    keymap("n", open_key, ':lua require("aider.core").open()<CR>', opts)
    keymap("n", toggle_key, ':lua require("aider.core").toggle()<CR>', opts)
end

return Aider
