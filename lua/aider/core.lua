local WindowManager = require("aider.window_manager")
local BufferManager = require("aider.buffer_manager")
local CommandExecutor = require("aider.command_executor")
local ContextManager = require("aider.context_manager")
local config = require("aider.config")
local Logger = require("aider.logger")

local Aider = {}
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

    -- Get initial context and start Aider in one step
    local initial_context = BufferManager.get_context_buffers()
    CommandExecutor.start_aider(buf, args, initial_context)

    Logger.debug("Aider window opened", correlation_id)
end

function Aider.toggle(args, layout)
    local correlation_id = Logger.generate_correlation_id()
    local is_open = WindowManager.is_window_open()
    Logger.debug("Toggling Aider window. Current state: " .. (is_open and "open" or "closed"), correlation_id)

    if is_open then
        WindowManager.hide_aider_window()
    else
        -- Get existing buffer or create new one
        local buf = BufferManager.get_aider_buffer()
        if not buf then
            Logger.error("Failed to get or create Aider buffer", correlation_id)
            return
        end

        local used_layout = layout or config.get("default_layout") or current_layout
        WindowManager.show_window(buf, used_layout)

        -- Only start Aider if it's not already running
        if not CommandExecutor.is_aider_running() then
            local aider_args = args or config.get("aider_args") or ""
            CommandExecutor.start_aider(buf, aider_args, {})
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
    -- Autocommands are now managed in autocmds.lua
end


function Aider.on_aider_buffer_enter()
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("on_aider_buffer_enter: Starting", correlation_id)

    if not BufferManager or not CommandExecutor then
        vim.notify("Core components not initialized", vim.log.levels.ERROR)
        Logger.error("Missing core components", correlation_id)
        return
    end

    local ok, err = pcall(function()
        BufferManager.update_context()
        CommandExecutor.update_aider_context()
    end)

    if not ok then
        vim.notify("Error in buffer enter handler: " .. tostring(err), vim.log.levels.ERROR)
        Logger.error("Buffer enter handler failed: " .. tostring(err), correlation_id)
    end

    Logger.debug("on_aider_buffer_enter: Complete", correlation_id)
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

function Aider.mass_sync_context()
	local correlation_id = Logger.generate_correlation_id()
	Logger.debug("Aider.mass_sync_context: Starting mass context sync", correlation_id)

	if CommandExecutor.is_aider_running() then
		local commands = ContextManager.mass_sync_context()
		if #commands > 0 then
			CommandExecutor.queue_commands(commands, true) -- Set is_context_update to true
			Logger.debug("Aider.mass_sync_context: Mass context sync complete", correlation_id)
		else
			Logger.debug("Aider.mass_sync_context: No changes to sync", correlation_id)
		end
	else
		Logger.warn("Aider.mass_sync_context: Aider is not running, skipping sync", correlation_id)
	end
end

return Aider
