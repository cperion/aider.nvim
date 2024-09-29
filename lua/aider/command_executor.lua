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

    Logger.info("Starting Aider", correlation_id)
    Logger.debug("Command: " .. command, correlation_id)
    Logger.debug("Context buffers: " .. vim.inspect(context_buffers), correlation_id)
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
            Logger.debug("Aider job exited with code: " .. tostring(exit_code), correlation_id)
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
    Logger.info("Aider started successfully", correlation_id)
end

function CommandExecutor.update_aider_context()
    local correlation_id = Logger.generate_correlation_id()
    if aider_job_id then
        local new_context = BufferManager.get_aider_context()
        local commands = ContextManager.get_batched_commands()

        Logger.info("Updating Aider context", correlation_id)
        Logger.debug("New context: " .. vim.inspect(new_context), correlation_id)
        Logger.debug("Generated commands: " .. vim.inspect(commands), correlation_id)

        if #commands > 0 then
            CommandExecutor.execute_commands(commands)
        else
            Logger.debug("No commands to execute", correlation_id)
        end
    else
        Logger.warn("Aider job is not running, context update skipped", correlation_id)
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
