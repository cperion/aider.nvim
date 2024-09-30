local Logger = require("aider.logger")
local BufferManager = require("aider.buffer_manager")
local ContextManager = {}

local current_context = {}
local pending_changes = {add = {}, drop = {}}

function ContextManager.update(new_context)
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("ContextManager.update: Starting context update", correlation_id)
    
    local valid_buffers = BufferManager.get_valid_buffers()
    Logger.debug("Current valid buffers: " .. vim.inspect(valid_buffers), correlation_id)
    
    Logger.debug("Current context: " .. vim.inspect(current_context), correlation_id)
    Logger.debug("New context: " .. vim.inspect(new_context), correlation_id)

    -- Calculate differences
    for _, file in ipairs(new_context) do
        if not vim.tbl_contains(current_context, file) then
            pending_changes.add[file] = true
        end
    end

    for _, file in ipairs(current_context) do
        if not vim.tbl_contains(new_context, file) then
            pending_changes.drop[file] = true
        end
    end

    current_context = new_context

    Logger.debug("Pending changes: " .. vim.inspect(pending_changes), correlation_id)
    Logger.debug("ContextManager.update: Context update complete", correlation_id)
end

function ContextManager.get_batched_commands()
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("ContextManager.get_batched_commands: Starting command generation", correlation_id)

    local commands = {}

    local files_to_add = {}
    for file, _ in pairs(pending_changes.add) do
        table.insert(files_to_add, file)
    end

    local files_to_drop = {}
    for file, _ in pairs(pending_changes.drop) do
        table.insert(files_to_drop, file)
    end

    if #files_to_add > 0 then
        local add_command = "/add " .. table.concat(files_to_add, " ")
        table.insert(commands, add_command)
    end

    if #files_to_drop > 0 then
        local drop_command = "/drop " .. table.concat(files_to_drop, " ")
        table.insert(commands, drop_command)
    end

    -- Clear pending changes after generating commands
    pending_changes = {add = {}, drop = {}}

    Logger.debug("Generated commands: " .. vim.inspect(commands), correlation_id)

    return commands
end

function ContextManager.periodic_check()
    local current_buffers = BufferManager.get_context_buffers()
    if not vim.deep_equal(current_context, current_buffers) then
        ContextManager.update(current_buffers)
        return ContextManager.get_batched_commands()
    end
    return {}
end

function ContextManager.mass_sync_context()
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("ContextManager.mass_sync_context: Starting mass context sync", correlation_id)

    -- Drop all files
    local drop_command = "/drop *"
    local commands = {drop_command}

    -- Add all current buffers
    local current_buffers = BufferManager.get_context_buffers()
    if #current_buffers > 0 then
        local add_command = "/add " .. table.concat(current_buffers, " ")
        table.insert(commands, add_command)
    end

    -- Update the current context
    current_context = current_buffers
    pending_changes = {add = {}, drop = {}}

    Logger.debug("Mass sync commands: " .. vim.inspect(commands), correlation_id)
    Logger.debug("ContextManager.mass_sync_context: Mass context sync complete", correlation_id)

    return commands
end

return ContextManager
