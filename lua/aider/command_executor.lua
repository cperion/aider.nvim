local BufferManager = require("aider.buffer_manager")
local ContextManager = require("aider.context_manager")
local Logger = require("aider.logger")
local config = require("aider.config")
local Utils = require("aider.utils")

local M = {}
local aider_buf = nil
local terminal_job_id = nil  -- Track terminal job separately
local command_queue = {}
local is_executing = false

function M.debug_terminal_state()
    local state = {
        job_id = aider_job_id,
        buf = aider_buf,
        buf_valid = aider_buf and vim.api.nvim_buf_is_valid(aider_buf) or false,
        terminal_job_id = aider_buf and vim.api.nvim_buf_is_valid(aider_buf) and 
            pcall(function() return vim.api.nvim_buf_get_var(aider_buf, "terminal_job_id") end)
    }
    Logger.debug("Terminal state: " .. vim.inspect(state))
    return state
end

function M.scroll_to_bottom()
	if aider_buf and vim.api.nvim_buf_is_valid(aider_buf) then
		local window = vim.fn.bufwinid(aider_buf)
		if window ~= -1 then
			local line_count = vim.api.nvim_buf_line_count(aider_buf)
			vim.api.nvim_win_set_cursor(window, { line_count, 0 })
		end
	end
end

function M.setup()
    -- Autocommands are now managed in autocmds.lua
end

function M.is_aider_running()
    -- Check three-way validity:
    return terminal_job_id ~= nil and          -- We have a job ID
           aider_buf and                       -- Buffer reference exists
           vim.api.nvim_buf_is_valid(aider_buf) and  -- Buffer is valid
           pcall(function()
               -- Buffer's terminal job matches our ID
               return vim.api.nvim_buf_get_var(aider_buf, "terminal_job_id") == terminal_job_id
           end)
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
        return
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

    -- Clear previous job reference
    terminal_job_id = nil
    
    -- Start new terminal job
    local job_id = vim.fn.termopen(command, {
        on_exit = function(job_id, exit_code, event_type)
            M.on_aider_exit(exit_code)
        end,
    })

    if job_id <= 0 then
        Logger.error("Failed to start Aider job. Job ID: " .. tostring(job_id), correlation_id)
        return
    end

    -- Store new job reference
    terminal_job_id = job_id
    aider_buf = buf

    -- Set terminal options after terminal is opened
    BufferManager.set_terminal_options(buf)

    Logger.debug("Aider job started with job_id: " .. tostring(aider_job_id), correlation_id)
    
    ContextManager.update(initial_context)
    Logger.debug("Context updated", correlation_id)

    Logger.info("Aider started successfully", correlation_id)

    -- Scroll to the bottom after starting Aider if auto_scroll is enabled
    if config.get("auto_scroll") then
        vim.schedule(function()
            M.scroll_to_bottom()
        end)
    end
end

function M.update_aider_context()
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("update_aider_context: Starting context update", correlation_id)
    
    if not M.is_aider_running() then
        vim.notify("Aider is not running", vim.log.levels.DEBUG)
        Logger.debug("Aider not running, skipping context update", correlation_id)
        return
    end

    -- Guard against missing functions
    if not BufferManager.get_context_buffers then
        vim.notify("Buffer manager not properly initialized", vim.log.levels.ERROR)
        Logger.error("Buffer manager missing required function", correlation_id)
        return
    end

    local new_context = BufferManager.get_context_buffers()
    if not new_context then
        vim.notify("Failed to get buffer context", vim.log.levels.ERROR)
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
    if is_executing or #command_queue == 0 or not M.is_aider_running() or not aider_buf then
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
            for _, input in ipairs(context_update_inputs) do
                success = success and pcall(M.send_input, input)
            end
            if success then
                Logger.debug("Context update inputs sent to Aider: " .. vim.inspect(context_update_inputs))
            end
        end

        -- Process user inputs
        if success and #inputs_to_send > 0 then
            for _, input in ipairs(inputs_to_send) do
                success = success and pcall(M.send_input, input)
            end
            if success then
                Logger.debug("User inputs sent to Aider: " .. vim.inspect(inputs_to_send))
            end
        end

        return success
    end

    local function retry_processing()
        if not process_batch() and retry_count < max_retries then
            retry_count = retry_count + 1
            Logger.debug("Retrying command processing, attempt " .. retry_count)
            vim.defer_fn(retry_processing, 100 * retry_count)
        else
            command_queue = {}
            is_executing = false
            vim.defer_fn(M.process_command_queue, 500)
        end
    end

    retry_processing()
end

function M.send_input(input)
    if not M.is_aider_running() then
        Logger.warn("Cannot send input - Aider is not running")
        return
    end

    Logger.debug("Sending input to Aider: " .. input)
    
    -- Ensure input ends with newline
    if not input:match("\n$") then
        input = input .. "\n"
    end

    -- Try different methods to send input to ensure it works
    local success = false
    
    -- Method 1: Using job_id
    if aider_job_id then
        success = pcall(function()
            vim.fn.chansend(aider_job_id, input)
        end)
    end
    
    -- Method 2: Using terminal buffer directly if Method 1 failed
    if not success and aider_buf and vim.api.nvim_buf_is_valid(aider_buf) then
        success = pcall(function()
            vim.api.nvim_chan_send(vim.api.nvim_buf_get_var(aider_buf, "terminal_job_id"), input)
        end)
    end

    if not success then
        Logger.error("Failed to send input to Aider terminal")
        return
    end

    -- Scroll to the bottom after sending input if auto_scroll is enabled
    if config.get("auto_scroll") then
        vim.schedule(function()
            M.scroll_to_bottom()
        end)
    end
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
    if not bufname or bufname == "" or 
       bufname:match("^term://") or 
       buftype == "terminal" or
       buftype == "nofile" or
       BufferManager.is_aider_buffer(bufnr) then
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

    -- Get buffer info before it's deleted
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
    
    -- Skip special buffers
    if not bufname or bufname == "" or 
       bufname:match("^term://") or 
       buftype == "terminal" or
       buftype == "nofile" or
       BufferManager.is_aider_buffer(bufnr) then
        Logger.debug("Skipping special buffer: " .. tostring(bufname), correlation_id)
        return
    end

    local relative_filename = Utils.get_relative_path(bufname)
    Logger.debug("Dropping file from context: " .. relative_filename, correlation_id)
    
    -- Queue the drop command with high priority
    M.queue_commands({ "/drop " .. relative_filename }, true)
    
    -- Process the command queue immediately
    vim.schedule(function()
        M.process_command_queue()
    end)
end

function M.on_aider_exit(exit_code)
    -- Clear job state but preserve buffer
    terminal_job_id = nil
    command_queue = {}
    is_executing = false
    ContextManager.update({})
    
    vim.schedule(function()
        Logger.info("Aider finished" .. (exit_code and " with exit code "..tostring(exit_code) or ""))
        -- Optional: Add visual feedback here
    end)
end

return M
