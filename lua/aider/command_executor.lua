local BufferManager = require("aider.buffer_manager")
local ContextManager = require("aider.context_manager")
local Logger = require("aider.logger")

local M = {}
local aider_buf = nil
M.aider_job_id = nil
local command_queue = {}
local is_executing = false

function M.setup()
    vim.api.nvim_create_autocmd("BufReadPost", {
        callback = function(args)
            M.on_buffer_open(args.buf)
        end,
    })
    
    vim.api.nvim_create_autocmd("BufDelete", {
        callback = function(args)
            M.on_buffer_close(args.buf)
        end,
    })
end

function M.is_aider_running()
    return M.aider_job_id ~= nil and M.aider_job_id > 0
end

function M.start_aider(buf, args)
    local correlation_id = Logger.generate_correlation_id()
    args = args or ""
    local context_buffers = BufferManager.get_context_buffers()
    
    Logger.debug("start_aider: Starting with buffer " .. tostring(buf) .. " and args: " .. args, correlation_id)
    Logger.debug("start_aider: Context buffers: " .. vim.inspect(context_buffers), correlation_id)

    -- Construct the command
    local command = "aider " .. args

    -- Add each file to the command, properly escaped
    for _, file in ipairs(context_buffers) do
        command = command .. " " .. vim.fn.shellescape(file)
    end

    Logger.info("Starting Aider", correlation_id)
    Logger.debug("Command: " .. command, correlation_id)

    -- Start the job using vim.fn.termopen
    M.aider_job_id = vim.fn.termopen(command, {
        on_exit = function(job_id, exit_code, event_type)
            M.on_aider_exit(exit_code)
        end,
    })

    if M.aider_job_id <= 0 then
        Logger.error("Failed to start Aider job. Job ID: " .. tostring(M.aider_job_id), correlation_id)
        return
    end

    Logger.debug("Aider job started with job_id: " .. tostring(M.aider_job_id), correlation_id)

    aider_buf = buf
    ContextManager.update(context_buffers)
    Logger.debug("Context updated", correlation_id)

    Logger.info("Aider started successfully", correlation_id)
end

function M.update_aider_context()
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("update_aider_context: Starting context update", correlation_id)
    
    if M.is_aider_running() then
        local new_context = BufferManager.get_aider_context()
        local commands = ContextManager.get_batched_commands()

        Logger.info("Updating Aider context", correlation_id)
        Logger.debug("New context: " .. vim.inspect(new_context), correlation_id)
        Logger.debug("Generated commands: " .. vim.inspect(commands), correlation_id)

        if #commands > 0 then
            M.queue_commands(commands)
            Logger.debug("Commands queued", correlation_id)
        else
            Logger.debug("No commands to execute", correlation_id)
        end
    else
        Logger.warn("Aider job is not running, context update skipped", correlation_id)
    end
    
    Logger.debug("update_aider_context: Context update finished", correlation_id)
end

function M.queue_commands(commands)
    for _, command in ipairs(commands) do
        table.insert(command_queue, command)
    end
    M.process_command_queue()
end

function M.process_command_queue()
    if is_executing or #command_queue == 0 or not M.is_aider_running() then
        return
    end

    is_executing = true
    local command = table.remove(command_queue, 1)
    
    Logger.debug("Sending command: " .. vim.inspect(command))
    vim.fn.chansend(M.aider_job_id, command .. "\n")

    -- Wait for a short time before processing the next command
    vim.defer_fn(function()
        is_executing = false
        M.process_command_queue()
    end, 100)  -- 100ms delay
end

function M.on_buffer_open(bufnr)
    if not M.is_aider_running() then
        return
    end
    
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')
    if not bufname or bufname:match("^term://") or buftype == "terminal" then
        return
    end
    
    local relative_filename = vim.fn.fnamemodify(bufname, ":~:.")
    M.queue_commands({"/add " .. relative_filename})
    
    Logger.debug("Buffer opened: " .. relative_filename)
end

function M.on_buffer_close(bufnr)
    if not M.is_aider_running() then
        return
    end
    
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if not bufname or bufname:match("^term://") then
        return
    end
    
    local relative_filename = vim.fn.fnamemodify(bufname, ":~:.")
    M.queue_commands({"/drop " .. relative_filename})
    
    Logger.debug("Buffer closed: " .. relative_filename)
end

function M.on_aider_exit(exit_code)
    M.aider_job_id = nil
    aider_buf = nil
    command_queue = {}
    is_executing = false
    ContextManager.update({})
    vim.schedule(function()
        if exit_code ~= nil then
            Logger.info("Aider finished with exit code " .. tostring(exit_code))
        else
            Logger.info("Aider finished")
        end
    end)
end

return M
