local WindowManager = require("aider.window_manager")
local BufferManager = require("aider.buffer_manager")
local CommandExecutor = require("aider.command_executor")
local config = require("aider.config")
local Logger = require("aider.logger")

local Aider = {}
local update_timer = nil
local current_layout = "vsplit"

function Aider.setup()
    Logger.debug("Aider.setup: Starting Aider setup")
    WindowManager.setup()
    Logger.debug("Aider.setup: WindowManager setup complete")
    BufferManager.setup()
    Logger.debug("Aider.setup: BufferManager setup complete")
    CommandExecutor.setup()
    Logger.debug("Aider.setup: CommandExecutor setup complete")

    Aider.setup_autocommands()
    Logger.debug("Aider.setup: Autocommands setup complete")
    Aider.setup_keybindings()
    Logger.debug("Aider.setup: Keybindings setup complete")
    Logger.debug("Aider.setup: Aider setup complete")
end

function Aider.open(args, layout)
	local correlation_id = Logger.generate_correlation_id()
	Logger.debug("Opening Aider window", correlation_id)

	local buf = BufferManager.get_aider_buffer()
	local used_layout = layout or current_layout
	WindowManager.show_window(buf, used_layout)

	CommandExecutor.start_aider(buf, args)
	Logger.debug("Aider window opened", correlation_id)
end

function Aider.toggle(args, layout)
    local correlation_id = Logger.generate_correlation_id()
    local is_open = WindowManager.is_window_open()
    Logger.debug("Toggling Aider window. Current state: " .. (is_open and "open" or "closed"), correlation_id)

    if is_open then
        WindowManager.hide_aider_window()
    else
        local buf = BufferManager.get_aider_buffer()
        local used_layout = layout or config.get("default_layout") or current_layout
        WindowManager.show_window(buf, used_layout)
        
        -- Start the Aider job if it's not already running
        if not CommandExecutor.is_aider_running() then
            local aider_args = args or config.get("aider_args") or ""
            CommandExecutor.start_aider(buf, aider_args)
            Logger.debug("Aider started with args: " .. aider_args, correlation_id)
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
			require("aider.core").debounce_update()
		end,
	})

	vim.api.nvim_create_autocmd("BufEnter", {
		group = aider_group,
		pattern = "Aider",
		callback = function()
			require("aider.core").on_aider_buffer_enter()
		end,
	})
end

function Aider.debounce_update()
	if update_timer then
		update_timer:stop()
	end

	if not update_timer then
		update_timer = vim.uv.new_timer()
	end

	local debounce_ms = config.get("update_debounce_ms") or 1000

	update_timer:start(
		debounce_ms,
		0,
		vim.schedule_wrap(function()
			local new_context = BufferManager.get_context_buffers()
			if not vim.deep_equal(BufferManager.get_aider_context(), new_context) then
				BufferManager.update_context()
				CommandExecutor.update_aider_context()
			end
			update_timer:stop()
		end)
	)
end

function Aider.on_aider_buffer_enter()
	BufferManager.update_context()
	CommandExecutor.update_aider_context()
end

function Aider.setup_keybindings()
	local open_key = config.get("keys.open") or "<leader>ao"
	local toggle_key = config.get("keys.toggle") or "<leader>at"

	vim.keymap.set("n", tostring(open_key), function()
		require("aider.core").open()
	end, { silent = true })

	vim.keymap.set("n", tostring(toggle_key), function()
		require("aider.core").toggle()
	end, { silent = true })
end

return Aider
