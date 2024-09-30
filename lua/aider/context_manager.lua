local Logger = require("aider.logger")
local BufferManager = require("aider.buffer_manager")
local ContextManager = {}

local current_context = {}
local previous_context = {}

function ContextManager.update(new_context)
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("ContextManager.update: Starting context update", correlation_id)
    
    -- Log current valid buffers
    local valid_buffers = BufferManager.get_valid_buffers()
    Logger.debug("Current valid buffers: " .. vim.inspect(valid_buffers), correlation_id)
    
    Logger.debug("Previous context: " .. vim.inspect(previous_context), correlation_id)
    Logger.debug("Current context: " .. vim.inspect(current_context), correlation_id)
    Logger.debug("New context: " .. vim.inspect(new_context), correlation_id)

    previous_context = vim.deepcopy(current_context)
    current_context = new_context

    Logger.debug("ContextManager.update: Context update complete", correlation_id)
end

function ContextManager.get_batched_commands()
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("ContextManager.get_batched_commands: Starting command generation", correlation_id)

    local files_to_add = {}
    local files_to_drop = {}

    -- Files to add
    for _, file in ipairs(current_context) do
        if not vim.tbl_contains(previous_context, file) then
            table.insert(files_to_add, file)
        end
    end

    -- Files to drop
    for _, file in ipairs(previous_context) do
        if not vim.tbl_contains(current_context, file) then
            table.insert(files_to_drop, file)
        end
    end

    local commands = {}

    if #files_to_add > 0 then
        local add_command = "/add " .. table.concat(files_to_add, " ")
        table.insert(commands, add_command)
    end

    if #files_to_drop > 0 then
        local drop_command = "/drop " .. table.concat(files_to_drop, " ")
        table.insert(commands, drop_command)
    end

    Logger.debug("Generated commands: " .. vim.inspect(commands), correlation_id)

    return commands
end

return ContextManager
