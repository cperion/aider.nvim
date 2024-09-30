local BufferManager = require("aider.buffer_manager")
local ContextManager = require("aider.context_manager")
local Logger = require("aider.logger")

local CommandExecutor = {}
local aider_job_id = nil
local aider_buf = nil

function CommandExecutor.setup()
    -- No setup needed for now
end

function CommandExecutor.is_aider_running()
    return aider_job_id ~= nil and aider_job_id > 0
end

function CommandExecutor.start_aider(buf, args)
    local correlation_id = Logger.generate_correlation_id()
    args = args or ""
    local context_buffers = BufferManager.get_aider_context()
    
    Logger.debug("start_aider: Starting with buffer " .. tostring(buf) .. " and args: " .. args, correlation_id)
    Logger.debug("start_aider: Context buffers: " .. vim.inspect(context_buffers), correlation_id)

    -- Construct the command
    local command = "aider " .. args
    command = CommandExecutor.add_buffers_to_command(command, context_buffers)

    Logger.info("Starting Aider", correlation_id)
    Logger.debug("Command: " .. command, correlation_id)

    -- Start the job using vim.fn.termopen
    aider_job_id = vim.fn.termopen(command, {
        on_exit = function(job_id, exit_code, event_type)
            CommandExecutor.on_aider_exit(exit_code)
        end,
    })

    if aider_job_id <= 0 then
        Logger.error("Failed to start Aider job. Job ID: " .. tostring(aider_job_id), correlation_id)
        return
    end

    Logger.debug("Aider job started with job_id: " .. tostring(aider_job_id), correlation_id)

    aider_buf = buf
    ContextManager.update(context_buffers)
    Logger.debug("Context updated", correlation_id)

    Logger.info("Aider started successfully", correlation_id)
end

function CommandExecutor.add_buffers_to_command(command, buffers)
    for _, file in ipairs(buffers) do
        command = command .. " " .. vim.fn.shellescape(file)
    end
    return command
end

-- Function removed as it's no longer needed with termopen

function CommandExecutor.update_aider_context()
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("update_aider_context: Starting context update", correlation_id)
    
    if aider_job_id and aider_job_id > 0 then
        local new_context = BufferManager.get_aider_context()
        local commands = ContextManager.get_batched_commands()

        Logger.info("Updating Aider context", correlation_id)
        Logger.debug("New context: " .. vim.inspect(new_context), correlation_id)
        Logger.debug("Generated commands: " .. vim.inspect(commands), correlation_id)

        if #commands > 0 then
            CommandExecutor.execute_commands(commands)
            Logger.debug("Commands executed", correlation_id)
        else
            Logger.debug("No commands to execute", correlation_id)
        end
    else
        Logger.warn("Aider job is not running, context update skipped", correlation_id)
    end
    
    Logger.debug("update_aider_context: Context update finished", correlation_id)
end

function CommandExecutor.execute_commands(commands)
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("execute_commands: Starting command execution", correlation_id)
    
    if aider_job_id and aider_job_id > 0 then
        local command_string = table.concat(commands, "\n") .. "\n"
        Logger.debug("Sending commands: " .. vim.inspect(command_string), correlation_id)
        vim.api.nvim_chan_send(aider_job_id, command_string)
        Logger.debug("Commands sent successfully", correlation_id)
    else
        Logger.warn("Aider job is not running, commands not sent", correlation_id)
    end
    
    Logger.debug("execute_commands: Command execution finished", correlation_id)
end

function CommandExecutor.on_aider_exit(exit_code)
    aider_job_id = nil
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

return CommandExecutor
