local BufferManager = require("aider.buffer_manager")
local ContextManager = require("aider.context_manager")
local Logger = require("aider.logger")

local CommandExecutor = {}
local aider_job_id = nil
local aider_buf = nil

function CommandExecutor.setup()
    -- No setup needed for now
end

function CommandExecutor.start_aider(buf, args)
    local correlation_id = Logger.generate_correlation_id()
    args = args or ""
    local context_buffers = BufferManager.get_aider_context()
    
    -- Construct the command
    local command = {"aider"}
    if args ~= "" then
        for arg in args:gmatch("%S+") do
            table.insert(command, arg)
        end
    end
    for _, file in ipairs(context_buffers) do
        table.insert(command, file)
    end

    Logger.info("Starting Aider", correlation_id)
    Logger.debug("Command: " .. vim.inspect(command), correlation_id)

    -- Ensure the buffer is modifiable and clear it
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

    -- Start the job
    aider_job_id = vim.fn.jobstart(command, {
        on_stdout = function(_, data) CommandExecutor.on_output(buf, data) end,
        on_stderr = function(_, data) CommandExecutor.on_output(buf, data) end,
        on_exit = function(_, exit_code)
            Logger.debug("Aider job exited with code: " .. tostring(exit_code), correlation_id)
            CommandExecutor.on_aider_exit(exit_code)
        end,
        pty = true,
        stderr_buffered = false,
        stdout_buffered = false,
    })

    if aider_job_id <= 0 then
        Logger.error("Failed to start Aider job", correlation_id)
        return
    end

    -- Set buffer-specific options
    vim.api.nvim_buf_set_option(buf, 'buftype', 'terminal')
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)
    vim.api.nvim_buf_set_name(buf, "Aider")

    aider_buf = buf
    ContextManager.update(context_buffers)

    Logger.info("Aider started successfully", correlation_id)
end

function CommandExecutor.on_output(buf, data)
    if data then
        vim.schedule(function()
            -- Filter out empty lines
            local non_empty_lines = vim.tbl_filter(function(line)
                return line ~= ""
            end, data)
            
            if #non_empty_lines > 0 then
                vim.api.nvim_buf_set_option(buf, 'modifiable', true)
                vim.api.nvim_buf_set_lines(buf, -1, -1, false, non_empty_lines)
                vim.api.nvim_buf_set_option(buf, 'modifiable', false)
                
                -- Scroll to the bottom of the buffer
                local win = vim.fn.bufwinid(buf)
                if win ~= -1 then
                    local line_count = vim.api.nvim_buf_line_count(buf)
                    vim.api.nvim_win_set_cursor(win, {line_count, 0})
                end
            end
        end)
    end
end

function CommandExecutor.update_aider_context()
    local correlation_id = Logger.generate_correlation_id()
    if aider_job_id and aider_job_id > 0 then
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
    if aider_job_id and aider_job_id > 0 then
        local command_string = table.concat(commands, "\n") .. "\n"
        vim.fn.chansend(aider_job_id, command_string)
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
