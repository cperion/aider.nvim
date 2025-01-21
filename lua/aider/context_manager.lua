local Logger = require("aider.logger")
local BufferManager = require("aider.buffer_manager")
local Utils = require("aider.utils")
local session = require("aider.session")
local ContextManager = {}

-- Only keep pending_changes local as it's temporary state
local pending_changes = { add = {}, drop = {} }

function ContextManager.sync_on_toggle()
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("Starting context sync on toggle", correlation_id)
    
    local current_files = BufferManager.get_context_buffers()
    local state = session.get()
    local last_files = state.context or {}
    
    -- Calculate files to add and drop
    local to_add = vim.tbl_filter(function(f)
        return not vim.tbl_contains(last_files, f)
    end, current_files)
    
    local to_drop = vim.tbl_filter(function(f)
        return not vim.tbl_contains(current_files, f)
    end, last_files)
    
    Logger.debug("Files to add: " .. vim.inspect(to_add), correlation_id)
    Logger.debug("Files to drop: " .. vim.inspect(to_drop), correlation_id)
    
    -- Generate and queue commands if needed
    if #to_add > 0 or #to_drop > 0 then
        local commands = {}
        if #to_drop > 0 then
            table.insert(commands, "/drop " .. table.concat(to_drop, " "))
        end
        if #to_add > 0 then
            table.insert(commands, "/add " .. table.concat(to_add, " "))
        end
        
        -- Update session state
        session.update({ context = current_files })
        
        -- Queue commands with high priority
        require("aider.command_executor").queue_commands(commands, true)
        Logger.debug("Queued context update commands: " .. vim.inspect(commands), correlation_id)
    else
        Logger.debug("No context changes needed", correlation_id)
    end
    
    return #to_add > 0 or #to_drop > 0
end

function ContextManager.update(new_context)
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("Starting context update", correlation_id)

    -- Validate input
    if type(new_context) ~= "table" then
        Logger.error("Invalid context provided: " .. vim.inspect(new_context), correlation_id)
        return false
    end

    local state = session.get()
    local current_context = state.context or {}

    -- Normalize paths
    local normalized_new = vim.tbl_map(function(path)
        return Utils.get_relative_path(path)
    end, new_context)

    Logger.debug("Current context: " .. vim.inspect(current_context), correlation_id)
    Logger.debug("New context: " .. vim.inspect(normalized_new), correlation_id)

    -- Calculate differences
    local changes = false
    for _, file in ipairs(normalized_new) do
        if not vim.tbl_contains(current_context, file) then
            pending_changes.add[file] = true
            changes = true
        end
    end

    for _, file in ipairs(current_context) do
        if not vim.tbl_contains(normalized_new, file) then
            pending_changes.drop[file] = true
            changes = true
        end
    end

    -- Update session state with new context
    session.update({ context = normalized_new })

    if changes then
        Logger.debug("Context changes detected: " .. vim.inspect(pending_changes), correlation_id)
    else
        Logger.debug("No context changes needed", correlation_id)
    end

    return changes
end

function ContextManager.get_batched_commands()
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("ContextManager.get_batched_commands: Starting command generation", correlation_id)

    local commands = {}

    local files_to_add = {}
    for file, _ in pairs(pending_changes.add) do
        table.insert(files_to_add, Utils.get_relative_path(file))
    end

    local files_to_drop = {}
    for file, _ in pairs(pending_changes.drop) do
        table.insert(files_to_drop, Utils.get_relative_path(file))
    end

    if #files_to_add > 0 then
        local add_command = "/add " .. table.concat(files_to_add, " ")
        table.insert(commands, add_command)
        Logger.debug("Adding files: " .. vim.inspect(files_to_add), correlation_id)
    end

    if #files_to_drop > 0 then
        local drop_command = "/drop " .. table.concat(files_to_drop, " ")
        table.insert(commands, drop_command)
        Logger.debug("Dropping files: " .. vim.inspect(files_to_drop), correlation_id)
    end

    -- Clear pending changes after generating commands
    pending_changes = { add = {}, drop = {} }

    if #commands == 0 then
        Logger.debug("No changes in context, no commands generated", correlation_id)
    else
        Logger.debug("Generated commands: " .. vim.inspect(commands), correlation_id)
    end

    return commands
end

function ContextManager.periodic_check()
    local correlation_id = Logger.generate_correlation_id()
    local current_buffers = BufferManager.get_context_buffers()
    local state = session.get()
    
    if not vim.deep_equal(state.context or {}, current_buffers) then
        Logger.debug("Context change detected during periodic check", correlation_id)
        ContextManager.update(current_buffers)
        return ContextManager.get_batched_commands()
    end
    
    Logger.debug("No context changes in periodic check", correlation_id)
    return {}
end

function ContextManager.mass_sync_context()
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("ContextManager.mass_sync_context: Starting mass context sync", correlation_id)

    local inputs = { "/drop *" }

    -- Add all current buffers
    local current_buffers = BufferManager.get_context_buffers()
    if #current_buffers > 0 then
        local relative_paths = {}
        for _, file in ipairs(current_buffers) do
            table.insert(relative_paths, Utils.get_relative_path(file))
        end
        table.insert(inputs, "/add " .. table.concat(relative_paths, " "))
        Logger.debug("Adding files to context: " .. vim.inspect(relative_paths), correlation_id)
    end

    -- Add the /token message instead of a carriage return
    table.insert(inputs, "/token")

    -- Update session state with new context
    session.update({ context = current_buffers })
    pending_changes = { add = {}, drop = {} }

    Logger.debug("Mass sync inputs: " .. vim.inspect(inputs), correlation_id)
    Logger.debug("ContextManager.mass_sync_context: Mass context sync complete", correlation_id)

    return inputs
end

return ContextManager
