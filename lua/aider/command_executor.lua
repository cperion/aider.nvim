local BufferManager = require("aider.buffer_manager")

local CommandExecutor = {}
local aider_job_id = nil
local current_context = {}
local is_updating_context = false

function CommandExecutor.setup()
	-- No setup needed for now
end

function CommandExecutor.start_aider(buf, args)
    args = args or ""
    local context_buffers = BufferManager.get_aider_context()
    local command = "aider " .. args .. " " .. table.concat(context_buffers, " ")

    -- Ensure the buffer is modifiable
    vim.bo[buf].modifiable = true

    -- Clear the buffer content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

    -- Set the buffer as unmodified
    vim.bo[buf].modified = false

    -- Create a terminal in the buffer
    aider_job_id = vim.fn.termopen(command, {
        on_exit = function(_, exit_code, _)
            CommandExecutor.on_aider_exit(exit_code)
        end,
    })

    -- Set terminal-specific options
    vim.bo[buf].buftype = "terminal"
    vim.bo[buf].modifiable = false

    -- Initialize the current_context
    current_context = vim.deepcopy(context_buffers)

    vim.defer_fn(function()
        vim.cmd("startinsert")
    end, 100)
end

function CommandExecutor.update_aider_context()
    if aider_job_id and not is_updating_context then
        is_updating_context = true
        local new_context = BufferManager.get_aider_context()

        -- Disable input
        vim.api.nvim_chan_send(aider_job_id, "\x1b") -- Send ESC to exit insert mode

        local commands = {}

        -- Files to add (in new_context but not in current_context)
        for _, file in ipairs(new_context) do
            if not vim.tbl_contains(current_context, file) then
                table.insert(commands, "/add " .. file)
            end
        end

        -- Files to drop (in current_context but not in new_context)
        for _, file in ipairs(current_context) do
            if not vim.tbl_contains(new_context, file) then
                table.insert(commands, "/drop " .. file)
            end
        end

        -- Execute commands sequentially
        CommandExecutor.execute_commands(commands, function()
            -- Update the current_context
            current_context = vim.deepcopy(new_context)
            is_updating_context = false

            -- Re-enable input
            vim.api.nvim_chan_send(aider_job_id, "i") -- Enter insert mode
        end)
    end
end

function CommandExecutor.execute_commands(commands, callback)
    if #commands == 0 then
        callback()
        return
    end

    local command = table.remove(commands, 1)
    
    if aider_job_id then
        vim.api.nvim_chan_send(aider_job_id, command .. "\n")

        -- Wait for command to complete (adjust timeout as needed)
        vim.defer_fn(function()
            CommandExecutor.execute_commands(commands, callback)
        end, 500) -- 500ms delay between commands
    else
        vim.notify("Aider job is not running", vim.log.levels.WARN)
        callback()
    end
end

function CommandExecutor.on_aider_exit(exit_code)
    aider_job_id = nil
    current_context = {}
    vim.schedule(function()
        if exit_code ~= nil then
            vim.notify("Aider finished with exit code " .. tostring(exit_code))
        else
            vim.notify("Aider finished")
        end
    end)
end

return CommandExecutor
