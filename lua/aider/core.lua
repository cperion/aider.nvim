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

    -- Get default args from config with more explicit logging
    local default_args = config.get("aider_args") or ""
    Logger.debug("Default args from config: " .. tostring(default_args), correlation_id)
    Logger.debug("Provided args: " .. tostring(args), correlation_id)

    local final_args = ""
    if default_args ~= "" then
        final_args = default_args
    end
    if args and args ~= "" then
        final_args = final_args .. (final_args ~= "" and " " or "") .. args
    end
    Logger.debug("Final args: " .. tostring(final_args), correlation_id)
    
    local buf = BufferManager.get_or_create_aider_buffer()
    local used_layout = layout or current_layout
    
    if not CommandExecutor.is_aider_running() then
        local initial_context = BufferManager.get_context_buffers()
        CommandExecutor.start_aider(buf, final_args, initial_context)
    end
    
    WindowManager.show_window(buf, used_layout)

    Logger.debug("Aider window opened", correlation_id)
end

function Aider.toggle(args, layout)
    local correlation_id = Logger.generate_correlation_id()
    local is_open = require("aider.window_manager").is_window_open()
    Logger.debug("Toggling Aider. Current state: " .. (is_open and "open" or "closed"), correlation_id)

    if is_open then
        Aider.cleanup_instance()
        Logger.debug("Aider closed", correlation_id)
    else
        require("aider.buffer_manager").reset_aider_buffer()
        local buf = require("aider.buffer_manager").get_or_create_aider_buffer()
        
        if not buf or not vim.api.nvim_buf_is_valid(buf) then
            Logger.error("Buffer creation failed", correlation_id)
            return
        end

        require("aider.window_manager").show_window(buf, layout or config.get("default_layout"))
        
        if not require("aider.command_executor").is_aider_running() then
            local final_args = table.concat({
                config.get("aider_args"),
                args or ""
            }, " ")
            require("aider.command_executor").start_aider(buf, final_args, require("aider.buffer_manager").get_context_buffers())
        end
    end
end

function Aider.cleanup_instance()
    Logger.debug("Starting instance cleanup")
    require("aider.command_executor").stop_aider()
    require("aider.window_manager").hide_aider_window()
    require("aider.buffer_manager").reset_aider_buffer()
    Logger.debug("Instance cleanup completed")
end

function Aider.cleanup()
    Logger.info("Cleaning up Aider")
    Aider.cleanup_instance()
    Logger.cleanup()
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
	end, { silent = true, desc = "Open Aider" })

	vim.keymap.set("n", tostring(toggle_key), function()
		require("aider.core").toggle()
	end, { silent = true, desc = "Toggle Aider" })

	-- Add buffer-local 'q' mapping for normal mode only
	local buf = BufferManager.get_aider_buffer()
	if buf then
		vim.keymap.set("n", "q", function()
			WindowManager.hide_aider_window()
		end, { silent = true, buffer = buf, desc = "Hide Aider window" })
	end
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
