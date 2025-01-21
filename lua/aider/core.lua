local config = require("aider.config")
local Logger = require("aider.logger")
local WindowManager = require("aider.window_manager")
local BufferManager = require("aider.buffer_manager")
local CommandExecutor = require("aider.command_executor")
local ContextManager = require("aider.context_manager")

local Aider = {}
local session = require("aider.session")

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
    local used_layout = layout or session.get().layout or config.get("default_layout")

    if not CommandExecutor.is_aider_running() then
        local initial_context = BufferManager.get_context_buffers()
        if CommandExecutor.start_aider(buf, final_args, initial_context) then
            session.update({
                active = true,
                buf_id = buf,
                layout = used_layout,
                context = initial_context,
            })
        end
    end

    WindowManager.show_window(buf, used_layout)

    Logger.debug("Aider window opened", correlation_id)
end

function Aider.toggle(args, layout)
    local correlation_id = Logger.generate_correlation_id()
    local state = session.get()
    Logger.debug("Toggling Aider. Current state: " .. vim.inspect(state), correlation_id)

    -- Check if window is currently visible
    if WindowManager.is_window_open() then
        Logger.debug("Hiding Aider window while preserving process state", correlation_id)
        
        -- Save window layout before hiding
        WindowManager.save_layout()

        -- Hide window but preserve process and terminal state
        WindowManager.hide_aider_window()
        
        -- Verify process state after hiding
        if state.job_id then
            local is_running = vim.fn.jobwait({ state.job_id }, 0)[1] == -1
            Logger.debug("Process state after hide: " .. (is_running and "running" or "stopped"), correlation_id)
        end
    else
        if state.active then
            -- Restore existing session
            local buf = BufferManager.get_or_create_aider_buffer()
            
            -- Show window with saved layout
            local used_layout = layout or state.layout or config.get("default_layout")
            WindowManager.show_window(buf, used_layout)

            -- Restore terminal state
            BufferManager.restore_terminal_state(buf)

            -- Ensure context is synced
            BufferManager.update_context()
        else
            -- Start new session
            BufferManager.reset_aider_buffer()
            local buf = BufferManager.get_or_create_aider_buffer()

            if not buf or not vim.api.nvim_buf_is_valid(buf) then
                Logger.error("Buffer creation failed", correlation_id)
                return
            end

            local used_layout = layout or config.get("default_layout")
            WindowManager.show_window(buf, used_layout)

            if not CommandExecutor.is_aider_running() then
                local final_args = table.concat({
                    config.get("aider_args"),
                    args or "",
                }, " ")
                    :gsub("^%s+", "")
                    :gsub("%s+$", "")

                if CommandExecutor.start_aider(buf, final_args, BufferManager.get_context_buffers()) then
                    -- Wait for terminal to be ready
                    if CommandExecutor.wait_until_ready(5000) then
                        session.update({
                            active = true,
                            visible = true,
                            buf_id = buf,
                            layout = used_layout,
                            context = BufferManager.get_context_buffers(),
                        })
                        Logger.debug("New Aider session started", correlation_id)
                    else
                        Logger.error("Aider failed to start within timeout", correlation_id)
                        CommandExecutor.handle_error("Startup timeout")
                        return
                    end
                else
                    Logger.error("Failed to start Aider process", correlation_id)
                    return
                end
            end
        end
    end
end

function Aider.cleanup_instance()
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("Starting instance cleanup", correlation_id)

    local state = session.get()

    -- Preserve UI and terminal state
    local preserved_state = {
        layout = state.layout,
        dimensions = state.dimensions,
        terminal_state = state.terminal_state
    }
    
    -- Save current window layout if visible
    if WindowManager.is_window_open() then
        WindowManager.save_layout()
        preserved_state.layout = state.layout
        preserved_state.dimensions = state.dimensions
    end

    -- Preserve terminal state if possible
    if state.buf_id and vim.api.nvim_buf_is_valid(state.buf_id) then
        BufferManager.preserve_terminal_state(state.buf_id)
        preserved_state.terminal_state = session.get().terminal_state
    end

    -- Stop the Aider process if running
    if state.active then
        Logger.debug("Stopping active Aider process", correlation_id)
        CommandExecutor.stop_aider()
        
        -- Verify process termination
        if state.job_id then
            local wait_result = vim.fn.jobwait({ state.job_id }, 1000)[1]
            Logger.debug("Process termination result: " .. tostring(wait_result), correlation_id)
        end
    end

    -- Hide window if visible (after process termination)
    if WindowManager.is_window_open() then
        WindowManager.hide_aider_window()
    end

    -- Reset buffer state only if process was active
    if state.active and state.buf_id then
        BufferManager.reset_aider_buffer()
    end

    -- Clear session state while preserving UI configuration
    session.clear()
    session.update({
        layout = preserved_state.layout,
        dimensions = preserved_state.dimensions,
        terminal_state = preserved_state.terminal_state
    })

    Logger.debug(
        "Instance cleanup completed with preserved state: " .. vim.inspect(preserved_state),
        correlation_id
    )
end

function Aider.cleanup()
    local correlation_id = Logger.generate_correlation_id()
    Logger.info("Cleaning up Aider", correlation_id)

    -- Perform full cleanup
    local complete_cleanup = vim.g.aider_shutting_down
    if complete_cleanup then
        Logger.debug("Performing complete cleanup due to shutdown", correlation_id)
        session.clear()
    else
        Aider.cleanup_instance()
    end

    Logger.cleanup()
    Logger.info("Aider cleanup complete" .. (complete_cleanup and " (full cleanup)" or ""), correlation_id)
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
        local context = BufferManager.update_context()
        if context then
            session.update({ context = context })

            if session.get().active then
                CommandExecutor.update_aider_context()
            end
        end
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
