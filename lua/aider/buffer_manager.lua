local Logger = require("aider.logger")
local config = require("aider.config")
local session = require("aider.session")
local BufferManager = {}

function BufferManager.setup()
    local buf = BufferManager.get_or_create_aider_buffer()
    session.update({ buf_id = buf })
    Logger.debug("BufferManager setup complete")
end

function BufferManager.get_valid_buffers()
    local valid_buffers = {}
    local aider_buf = session.get().buf_id
    
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        -- Skip if buffer is invalid or hidden
        if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].bufhidden == "hide" then
            goto continue
        end

        -- Get buffer info
        local bufname = vim.api.nvim_buf_get_name(buf)
        local buftype = vim.bo[buf].buftype

        -- Skip special buffers and Aider buffer
        if buftype ~= "" or buf == aider_buf then
            goto continue
        end

        -- Only include real files under size limit
        if bufname ~= "" and vim.fn.filereadable(bufname) == 1 then
            local filesize = vim.fn.getfsize(bufname)
            if filesize > 0 and filesize < config.get("max_context_file_size") then
                table.insert(valid_buffers, {
                    id = buf,
                    name = bufname,
                    filetype = vim.bo[buf].filetype,
                    modified = vim.bo[buf].modified
                })
            end
        end

        ::continue::
    end
    return valid_buffers
end

function BufferManager.get_or_create_aider_buffer()
    local state = session.get()
    local buf_id = state.buf_id
    
    if buf_id and not vim.api.nvim_buf_is_valid(buf_id) then
        buf_id = nil
        session.update({ buf_id = nil })
    end
    
    if not buf_id then
        local buf = vim.api.nvim_create_buf(false, true)
        if not buf then return nil end
        
        local unique_id = string.format("%d_%d", os.time(), math.random(1000,9999))
        pcall(vim.api.nvim_buf_set_name, buf, "Aider_"..unique_id)
        
        vim.bo[buf].swapfile = false
        vim.bo[buf].bufhidden = "hide"
        vim.bo[buf].buflisted = false

        session.update({ buf_id = buf })
        vim.keymap.set("n", "q", function()
            require("aider.window_manager").hide_aider_window()
        end, { silent = true, buffer = buf })
        
        buf_id = buf
    end
    
    return buf_id
end

function BufferManager.preserve_terminal_state(buf)
    local correlation_id = Logger.generate_correlation_id()
    if buf and vim.api.nvim_buf_is_valid(buf) then
        Logger.debug("Preserving terminal state for buffer: " .. tostring(buf), correlation_id)
        
        -- Save terminal mode
        vim.api.nvim_buf_call(buf, function()
            vim.cmd("stopinsert")
        end)
        
        -- Preserve terminal options
        vim.bo[buf].bufhidden = "hide"
        
        -- Cache terminal state
        local state = {
            scrollback = vim.bo[buf].scrollback,
            channel = pcall(vim.api.nvim_buf_get_var, buf, "terminal_job_id")
        }
        
        session.update({
            terminal_state = state
        })
        
        Logger.debug("Terminal state preserved: " .. vim.inspect(state), correlation_id)
        return state
    end
    Logger.debug("No valid buffer to preserve terminal state", correlation_id)
    return nil
end

function BufferManager.restore_terminal_state(buf)
    local correlation_id = Logger.generate_correlation_id()
    if buf and vim.api.nvim_buf_is_valid(buf) then
        local state = session.get().terminal_state
        if state then
            Logger.debug("Restoring terminal state: " .. vim.inspect(state), correlation_id)
            
            vim.bo[buf].buftype = "terminal"
            vim.bo[buf].bufhidden = "hide"
            if state.scrollback then
                vim.bo[buf].scrollback = state.scrollback
            end
            
            -- Reset terminal mode to normal
            vim.api.nvim_buf_call(buf, function()
                vim.cmd("stopinsert")
            end)
        else
            Logger.debug("No terminal state to restore", correlation_id)
        end
    else
        Logger.debug("No valid buffer to restore terminal state", correlation_id)
    end
end

function BufferManager.set_terminal_options(buf)
    local correlation_id = Logger.generate_correlation_id()
    if buf and vim.api.nvim_buf_is_valid(buf) then
        Logger.debug("Setting terminal options for buffer: " .. tostring(buf), correlation_id)
        vim.schedule(function()
            vim.bo[buf].buftype = "terminal"
            vim.bo[buf].bufhidden = "hide"
            vim.bo[buf].swapfile = false
            vim.bo[buf].buflisted = false
        end)
    end
end

function BufferManager.get_aider_buffer()
    return session.get().buf_id
end

function BufferManager.reset_aider_buffer()
    local state = session.get()
    if state.buf_id then
        if vim.api.nvim_buf_is_valid(state.buf_id) then
            pcall(vim.api.nvim_buf_delete, state.buf_id, { force = true })
        end
        session.update({ buf_id = nil })
    end
end

function BufferManager.is_aider_buffer(buf)
    return buf == session.get().buf_id
end

function BufferManager.get_context_buffers()
    local valid_buffers = {}
    for _, buf in ipairs(BufferManager.get_valid_buffers()) do
        table.insert(valid_buffers, buf.name)
    end
    return valid_buffers
end

function BufferManager.update_context()
    local correlation_id = Logger.generate_correlation_id()
    Logger.debug("Updating context", correlation_id)
    
    local state = session.get()
    if not state.active then
        Logger.debug("Skipping context update - Aider not running", correlation_id)
        return
    end
    
    local new_context = BufferManager.get_context_buffers()
    local current_context = state.context or {}
    
    -- Check for actual changes in context
    local has_changes = false
    if #new_context ~= #current_context then
        has_changes = true
    else
        for i, path in ipairs(new_context) do
            if path ~= current_context[i] then
                has_changes = true
                break
            end
        end
    end
    
    if has_changes then
        require("aider.context_manager").update(new_context)
        local commands = require("aider.context_manager").get_batched_commands()
        if #commands > 0 then
            Logger.debug("Sending context update commands: " .. vim.inspect(commands), correlation_id)
            require("aider.command_executor").queue_commands(commands, true)
            session.update({ context = new_context })
        end
    else
        Logger.debug("No context changes to send", correlation_id)
    end
    
    Logger.debug("Context update complete", correlation_id)
    return new_context
end

return BufferManager
