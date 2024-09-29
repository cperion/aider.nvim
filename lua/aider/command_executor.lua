local BufferManager = require("aider.buffer_manager")
local ContextManager = require("aider.context_manager")
local Logger = require("aider.logger")

local CommandExecutor = {}
local aider_job_id = nil
local aider_buf = nil

function CommandExecutor.setup()
    -- No setup needed for now
end

function CommandExecutor.clear_input_line()
    if aider_buf and vim.api.nvim_buf_is_valid(aider_buf) then
        local line_count = vim.api.nvim_buf_line_count(aider_buf)
        vim.api.nvim_buf_set_lines(aider_buf, line_count - 1, line_count, false, {""})
    end
end

function CommandExecutor.start_aider(buf, args)
    local correlation_id = Logger.generate_correlation_id()
    args = args or ""
    local context_buffers = BufferManager.get_aider_context()
    local command = "aider " .. args .. " " .. table.concat(context_buffers, " ")

    Logger.info("CommandExecutor.start_aider: Starting Aider [CorrelationID: " .. correlation_id .. "]")
    Logger.debug("CommandExecutor.start_aider: Command: " .. command)
    Logger.debug("CommandExecutor.start_aider: Context buffers: " .. vim.inspect(context_buffers))
    aider_buf = buf

    -- Ensure the buffer is modifiable
    vim.bo[buf].modifiable = true

    -- Clear the buffer content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

    -- Set the buffer as unmodified
    vim.bo[buf].modified = false

    -- Create a terminal in the buffer
    aider_job_id = vim.api.nvim_open_term(buf, {
        on_exit = function(_, exit_code, _)
            Logger.debug("CommandExecutor.start_aider: Aider job exited with code: " .. tostring(exit_code) .. " [CorrelationID: " .. correlation_id .. "]")
            CommandExecutor.on_aider_exit(exit_code)
        end,
    })

    -- Set terminal-specific options
    vim.api.nvim_buf_set_option(buf, 'buftype', 'terminal')
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'buflisted', false)
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)
    vim.api.nvim_buf_set_name(buf, "Aider")

    -- Initialize the context
    ContextManager.update(context_buffers)

    vim.schedule(function()
        vim.cmd("startinsert")
    end)
    Logger.info("CommandExecutor.start_aider: Aider started successfully [CorrelationID: " .. correlation_id .. "]")
end

function CommandExecutor.update_aider_context()
    local correlation_id = Logger.generate_correlation_id()
    if aider_job_id then
        local new_context = BufferManager.get_aider_context()
        local commands = ContextManager.get_batched_commands()

        Logger.info("CommandExecutor.update_aider_context: Updating Aider context [CorrelationID: " .. correlation_id .. "]")
        Logger.debug("CommandExecutor.update_aider_context: New context: " .. vim.inspect(new_context))
        Logger.debug("CommandExecutor.update_aider_context: Generated commands: " .. vim.inspect(commands))

        if #commands > 0 then
            CommandExecutor.execute_commands(commands)
        else
            Logger.debug("CommandExecutor.update_aider_context: No commands to execute [CorrelationID: " .. correlation_id .. "]")
        end
    else
        Logger.warn("CommandExecutor.update_aider_context: Aider job is not running, context update skipped [CorrelationID: " .. correlation_id .. "]")
    end
end

function CommandExecutor.execute_commands(commands)
    if aider_job_id then
        CommandExecutor.clear_input_line()
        local command_string = table.concat(commands, "\n") .. "\n"
        vim.api.nvim_chan_send(aider_job_id, command_string)
    else
        vim.notify("Aider job is not running", vim.log.levels.WARN)
    end
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
