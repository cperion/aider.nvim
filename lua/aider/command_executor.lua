local BufferManager = require("aider.buffer_manager")
local ContextManager = require("aider.context_manager")
local Logger = require("aider.logger")

local M = {}
local aider_buf = nil
M.aider_job_id = nil

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
    local context_buffers = BufferManager.get_context_buffers()  -- Changed from get_aider_context
    
    Logger.debug("start_aider: Starting with buffer " .. tostring(buf) .. " and args: " .. args, correlation_id)
    Logger.debug("start_aider: Context buffers: " .. vim.inspect(context_buffers), correlation_id)

    -- Construct the command
    local command = "aider " .. args
    command = M.add_buffers_to_command(command, context_buffers)

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
    Logger.debug("Aider job_id after starting: " .. tostring(M.aider_job_id), correlation_id)

    aider_buf = buf
    ContextManager.update(context_buffers)
    Logger.debug("Context updated", correlation_id)

    Logger.info("Aider started successfully", correlation_id)
end

function M.add_buffers_to_command(command, buffers)
    for _, file in ipairs(buffers) do
        command = command .. " " .. vim.fn.shellescape(file)
    end
    return command
end

function M.update_aider_context()
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("update_aider_context: Starting context update", correlation_id)
    
    if M.aider_job_id and M.aider_job_id > 0 then
        local new_context = BufferManager.get_aider_context()
        local commands = ContextManager.get_batched_commands()

        Logger.info("Updating Aider context", correlation_id)
        Logger.debug("New context: " .. vim.inspect(new_context), correlation_id)
        Logger.debug("Generated commands: " .. vim.inspect(commands), correlation_id)

        if #commands > 0 then
            M.execute_commands(commands)
            Logger.debug("Commands executed", correlation_id)
        else
            Logger.debug("No commands to execute", correlation_id)
        end
    else
        Logger.warn("Aider job is not running, context update skipped", correlation_id)
    end
    
    Logger.debug("update_aider_context: Context update finished", correlation_id)
end

function M.execute_commands(commands)
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("execute_commands: Starting command execution", correlation_id)
    
    if M.aider_job_id and M.aider_job_id > 0 then
        for _, command in ipairs(commands) do
            Logger.debug("Sending command: " .. vim.inspect(command), correlation_id)
            vim.fn.chansend(M.aider_job_id, command .. "\n")
        end
        Logger.debug("Commands sent successfully", correlation_id)
    else
        Logger.warn("Aider job is not running, commands not sent", correlation_id)
    end
    
    Logger.debug("execute_commands: Command execution finished", correlation_id)
end

function M.on_buffer_open(bufnr)
    if not M.aider_job_id or M.aider_job_id <= 0 then
        return
    end
    
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')
    if not bufname or bufname:match("^term://") or buftype == "terminal" then
        return
    end
    
    local relative_filename = vim.fn.fnamemodify(bufname, ":~:.")
    local line_to_add = "/add " .. relative_filename
    vim.fn.chansend(M.aider_job_id, line_to_add .. "\n")
    
    Logger.debug("Buffer opened: " .. relative_filename)
end

function M.on_buffer_close(bufnr)
    if not M.aider_job_id or M.aider_job_id <= 0 then
        return
    end
    
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if not bufname or bufname:match("^term://") then
        return
    end
    
    local relative_filename = vim.fn.fnamemodify(bufname, ":~:.")
    local line_to_drop = "/drop " .. relative_filename
    vim.fn.chansend(M.aider_job_id, line_to_drop .. "\n")
    
    Logger.debug("Buffer closed: " .. relative_filename)
end

function M.on_aider_exit(exit_code)
    M.aider_job_id = nil
    aider_buf = nil
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
