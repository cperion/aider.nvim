local BufferManager = require("aider.buffer_manager")
local ContextManager = require("aider.context_manager")
local Logger = require("aider.logger")
local config = require("aider.config")
local Utils = require("aider.utils")
local session = require("aider.session")

local M = {}
local command_queue = {}
local is_executing = false

function M.debug_terminal_state()
    local correlation_id = Logger.generate_correlation_id()
    local state = session.get()
    local debug_info = {
        session_state = state,
        buf_valid = state.buf_id and vim.api.nvim_buf_is_valid(state.buf_id) or false,
        terminal_job_id = state.buf_id and vim.api.nvim_buf_is_valid(state.buf_id) and pcall(function()
            return vim.api.nvim_buf_get_var(state.buf_id, "terminal_job_id")
        end),
        queue_status = {
            queue_length = #command_queue,
            is_executing = is_executing,
        },
    }
    Logger.debug("Terminal state: " .. vim.inspect(debug_info), correlation_id)
    return debug_info
end

function M.scroll_to_bottom()
    local buf = BufferManager.get_aider_buffer()
    if buf and vim.api.nvim_buf_is_valid(buf) then
        -- Find window displaying the buffer
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.api.nvim_win_get_buf(win) == buf then
                local line_count = vim.api.nvim_buf_line_count(buf)
                vim.api.nvim_win_set_cursor(win, { line_count, 0 })
                break
            end
        end
    end
end

function M.setup()
    -- Autocommands are now managed in autocmds.lua
end

function M.is_aider_running()
    local state = session.get()
    if not (state.active and state.buf_id and state.job_id) then
        return false
    end

    -- Quick health check
    if not vim.api.nvim_buf_is_valid(state.buf_id) then
        return false
    end

    -- Verify terminal job is still running
    local success, job_id = pcall(vim.api.nvim_buf_get_var, state.buf_id, "terminal_job_id")
    if not success then
        return false
    end

    -- Check if job is actually alive
    return vim.fn.jobwait({ state.job_id }, 0)[1] == -1
end

function M.wait_until_ready(timeout)
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("Waiting for Aider to be ready", correlation_id)

    local start = vim.loop.now()
    while vim.loop.now() - start < (timeout or 5000) do
        if M.is_aider_running() then
            Logger.debug("Aider is ready", correlation_id)
            return true
        end
        vim.wait(100)
    end

    Logger.error("Aider failed to become ready within timeout", correlation_id)
    return false
end

function M.handle_error(err)
    local correlation_id = Logger.generate_correlation_id()
    Logger.error("Aider error: " .. tostring(err), correlation_id)

    local state = session.get()
    if not state.recovering then
        Logger.debug("Starting error recovery", correlation_id)
        session.update({ recovering = true })

        M.stop_aider()

        vim.defer_fn(function()
            require("aider").toggle()
            session.update({ recovering = false })
            Logger.debug("Error recovery complete", correlation_id)
        end, 1000)
    else
        Logger.debug("Already in recovery mode, skipping", correlation_id)
    end
end

function M.start_aider(buf, args, initial_context)
    local correlation_id = Logger.generate_correlation_id()
    args = args or ""
    initial_context = initial_context or {}

    Logger.debug("start_aider: Starting with buffer " .. tostring(buf) .. " and args: " .. args, correlation_id)
    Logger.debug("start_aider: Initial context: " .. vim.inspect(initial_context), correlation_id)

    -- If Aider is already running, don't start a new instance
    if M.is_aider_running() then
        Logger.debug("Aider already running, reusing existing instance", correlation_id)
        return true
    end

    -- Construct the command
    local command = "aider"
    if args and args ~= "" then
        command = command .. " " .. args
    end

    -- Add each file from the initial context to the command, properly escaped
    for _, file in ipairs(initial_context) do
        command = command .. " " .. vim.fn.shellescape(file)
    end

    Logger.info("Starting Aider", correlation_id)
    Logger.debug("Command: " .. command, correlation_id)

    -- Clear session state
    session.update({
        active = false,
        job_id = nil,
    })

    -- Start new terminal job
    local job_id = vim.fn.termopen(command, {
        on_exit = function(job_id, exit_code, event_type)
            M.on_aider_exit(exit_code)
        end,
    })

    if job_id <= 0 then
        Logger.error("Failed to start Aider job. Job ID: " .. tostring(job_id), correlation_id)
        return false
    end

    -- Update session state
    session.update({
        active = true,
        job_id = job_id,
        buf_id = buf,
    })

    -- Set terminal options after terminal is opened
    BufferManager.set_terminal_options(buf)

    Logger.debug("Aider job started with job_id: " .. tostring(job_id), correlation_id)

    ContextManager.update(initial_context)
    session.update({ context = initial_context })
    Logger.debug("Context updated", correlation_id)

    Logger.info("Aider started successfully", correlation_id)

    -- Scroll to the bottom after starting Aider if auto_scroll is enabled
    if config.get("auto_scroll") then
        vim.schedule(function()
            M.scroll_to_bottom()
        end)
    end

    return true
end

function M.update_aider_context()
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("update_aider_context: Starting context update", correlation_id)

    if not M.is_aider_running() then
        Logger.debug("Aider not running, skipping context update", correlation_id)
        return
    end

    local new_context = BufferManager.get_context_buffers()
    if not new_context then
        Logger.error("Failed to get buffer context", correlation_id)
        return
    end

    local commands = ContextManager.get_batched_commands()
    Logger.debug("Generated commands: " .. vim.inspect(commands), correlation_id)

    if #commands > 0 then
        M.queue_commands(commands, true)
        Logger.debug("Context update commands queued", correlation_id)
    else
        Logger.debug("No context update commands to execute", correlation_id)
    end

    Logger.debug("update_aider_context: Context update finished", correlation_id)
end

function M.queue_commands(inputs, is_context_update)
    for _, input in ipairs(inputs) do
        table.insert(command_queue, { input = input, is_context_update = is_context_update })
    end
    M.process_command_queue()
end

function M.process_command_queue()
    local correlation_id = Logger.generate_correlation_id()
    local state = session.get()

    if is_executing or #command_queue == 0 or not M.is_aider_running() or not state.buf_id then
        return
    end

    is_executing = true
    local retry_count = 0
    local max_retries = 3

    local function process_batch()
        local inputs_to_send = {}
        local context_update_inputs = {}

        -- Separate context update inputs from user inputs
        for _, input_data in ipairs(command_queue) do
            if input_data.is_context_update then
                table.insert(context_update_inputs, input_data.input)
            else
                table.insert(inputs_to_send, input_data.input)
            end
        end

        -- Try to send commands
        local success = true

        -- Process context update inputs first
        if #context_update_inputs > 0 then
            Logger.debug("Processing context update inputs: " .. vim.inspect(context_update_inputs), correlation_id)
            for _, input in ipairs(context_update_inputs) do
                success = success and M.send_input(input)
            end
            if success then
                Logger.debug("Context update inputs sent successfully", correlation_id)
            else
                Logger.error("Failed to send context update inputs", correlation_id)
            end
        end

        -- Process user inputs
        if success and #inputs_to_send > 0 then
            Logger.debug("Processing user inputs: " .. vim.inspect(inputs_to_send), correlation_id)
            for _, input in ipairs(inputs_to_send) do
                success = success and M.send_input(input)
            end
            if success then
                Logger.debug("User inputs sent successfully", correlation_id)
            else
                Logger.error("Failed to send user inputs", correlation_id)
            end
        end

        return success
    end

    local function retry_processing()
        if not process_batch() and retry_count < max_retries then
            retry_count = retry_count + 1
            Logger.debug("Retrying command processing, attempt " .. retry_count, correlation_id)
            vim.defer_fn(retry_processing, 100 * retry_count)
        else
            if retry_count >= max_retries then
                Logger.error("Failed to process command queue after " .. max_retries .. " retries", correlation_id)
            end
            command_queue = {}
            is_executing = false
            vim.defer_fn(M.process_command_queue, 500)
        end
    end

    retry_processing()
end

function M.send_input(input)
    local correlation_id = Logger.generate_correlation_id()

    if not M.is_aider_running() then
        Logger.warn("Cannot send input - Aider is not running", correlation_id)
        return false
    end

    Logger.debug("Sending input to Aider: " .. input, correlation_id)

    -- Ensure input ends with newline
    if not input:match("\n$") then
        input = input .. "\n"
    end

    -- Try different methods to send input to ensure it works
    local success = false
    local state = session.get()

    -- Method 1: Using job_id from session
    if state.job_id then
        success = pcall(function()
            vim.fn.chansend(state.job_id, input)
        end)
        if success then
            Logger.debug("Successfully sent input using job_id", correlation_id)
        end
    end

    -- Method 2: Using terminal buffer directly if Method 1 failed
    if not success and state.buf_id and vim.api.nvim_buf_is_valid(state.buf_id) then
        success = pcall(function()
            local term_job_id = vim.api.nvim_buf_get_var(state.buf_id, "terminal_job_id")
            vim.api.nvim_chan_send(term_job_id, input)
        end)
        if success then
            Logger.debug("Successfully sent input using buffer channel", correlation_id)
        end
    end

    if not success then
        Logger.error("Failed to send input to Aider terminal", correlation_id)
        return false
    end

    -- Scroll to the bottom after sending input if auto_scroll is enabled
    if config.get("auto_scroll") then
        vim.schedule(function()
            M.scroll_to_bottom()
        end)
    end

    return true
end

function M.get_aider_context()
    return BufferManager.get_context_buffers()
end

function M.on_buffer_open(bufnr)
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("on_buffer_open: Processing buffer " .. tostring(bufnr), correlation_id)

    if not M.is_aider_running() then
        Logger.debug("Aider not running, skipping buffer open handling", correlation_id)
        return
    end

    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")

    -- Skip special buffers
    if
        not bufname
        or bufname == ""
        or bufname:match("^term://")
        or buftype == "terminal"
        or buftype == "nofile"
        or BufferManager.is_aider_buffer(bufnr)
    then
        Logger.debug("Skipping special buffer: " .. tostring(bufname), correlation_id)
        return
    end

    local relative_filename = Utils.get_relative_path(bufname)
    Logger.debug("Adding file to context: " .. relative_filename, correlation_id)

    -- Queue the add command
    M.queue_commands({ "/add " .. relative_filename }, true)
end

function M.on_buffer_close(bufnr)
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("on_buffer_close: Processing buffer " .. tostring(bufnr), correlation_id)

    if not M.is_aider_running() then
        Logger.debug("Aider not running, skipping buffer close handling", correlation_id)
        return
    end

    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")

    -- Skip special buffers
    if
        not bufname
        or bufname == ""
        or bufname:match("^term://")
        or buftype == "terminal"
        or buftype == "nofile"
        or BufferManager.is_aider_buffer(bufnr)
    then
        Logger.debug("Skipping special buffer: " .. tostring(bufname), correlation_id)
        return
    end

    local relative_filename = Utils.get_relative_path(bufname)
    Logger.debug("Dropping file from context: " .. relative_filename, correlation_id)

    -- Queue the drop command
    M.queue_commands({ "/drop " .. relative_filename }, true)
end

function M.stop_aider()
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("Stopping Aider instance", correlation_id)

    local state = session.get()
    local job_id = state.job_id
    local buf_id = state.buf_id

    -- Preserve terminal state before stopping
    if buf_id and vim.api.nvim_buf_is_valid(buf_id) then
        BufferManager.preserve_terminal_state(buf_id)
        Logger.debug("Terminal state preserved", correlation_id)
    end

    -- Clear process state first to prevent race conditions
    session.update({
        active = false,
        job_id = nil,
        context = {}
    })

    -- Stop the job if it's still running
    if job_id then
        local is_running = vim.fn.jobwait({ job_id }, 0)[1] == -1
        if is_running then
            local stop_success = pcall(vim.fn.jobstop, job_id)
            Logger.debug("Stopped Aider job: " .. tostring(job_id) .. " (success: " .. tostring(stop_success) .. ")", correlation_id)
            
            -- Wait briefly for job to actually stop
            vim.wait(100, function()
                return vim.fn.jobwait({ job_id }, 0)[1] ~= -1
            end)
        end
    end

    -- Clear command queue
    command_queue = {}
    is_executing = false

    Logger.debug("Aider instance stopped", correlation_id)
end

function M.on_aider_exit(exit_code)
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("Handling Aider exit with code: " .. tostring(exit_code), correlation_id)

    -- Clear queue state
    command_queue = {}
    is_executing = false

    -- Get current state to preserve UI settings
    local state = session.get()
    local current_layout = state.layout
    local current_dimensions = state.dimensions
    local terminal_state = state.terminal_state

    -- Clear context and process state while preserving UI state
    ContextManager.update({})
    session.update({
        active = false,
        job_id = nil,
        context = {},
        -- Preserve UI state
        layout = current_layout,
        dimensions = current_dimensions,
        terminal_state = terminal_state
    })

    -- Handle buffer state based on exit condition
    if exit_code == 0 then
        -- Normal exit - preserve buffer state
        if state.buf_id and vim.api.nvim_buf_is_valid(state.buf_id) then
            BufferManager.preserve_terminal_state(state.buf_id)
            Logger.debug("Terminal state preserved on normal exit", correlation_id)
        end
    else
        -- Abnormal exit - reset buffer
        BufferManager.reset_aider_buffer()
        Logger.debug("Buffer reset due to abnormal exit", correlation_id)
        
        -- Schedule recovery if not already recovering
        if not state.recovering then
            vim.schedule(function()
                M.handle_error("Aider process terminated unexpectedly with code " .. tostring(exit_code))
            end)
        end
    end

    vim.schedule(function()
        local message = exit_code == 0
            and "Aider finished successfully"
            or "Aider terminated with exit code " .. tostring(exit_code)
        
        Logger.info(message)
        if exit_code ~= 0 then
            vim.notify(message, vim.log.levels.WARN)
        end
    end)

    Logger.debug("Aider exit handling complete", correlation_id)
end

return M
