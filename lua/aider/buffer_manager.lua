local Logger = require("aider.logger")
local config = require("aider.config")
local BufferManager = {}
local aider_buf = nil

function BufferManager.setup()
    aider_buf = BufferManager.get_or_create_aider_buffer()
    Logger.debug("BufferManager setup complete")
end

function BufferManager.get_valid_buffers()
    local valid_buffers = {}
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
    if aider_buf and not vim.api.nvim_buf_is_valid(aider_buf) then
        aider_buf = nil
    end
    
    if not aider_buf then
        local buf = vim.api.nvim_create_buf(false, true)
        if not buf then return nil end
        
        local unique_id = string.format("%d_%d", os.time(), math.random(1000,9999))
        pcall(vim.api.nvim_buf_set_name, buf, "Aider_"..unique_id)
        
        vim.bo[buf].swapfile = false
        vim.bo[buf].bufhidden = "hide"
        vim.bo[buf].buflisted = false

        aider_buf = buf
        vim.keymap.set("n", "q", function()
            require("aider.window_manager").hide_aider_window()
        end, { silent = true, buffer = buf })
    end
    
    return aider_buf
end

-- New function to set terminal options
function BufferManager.set_terminal_options(buf)
    if buf and vim.api.nvim_buf_is_valid(buf) then
        vim.schedule(function()
            vim.bo[buf].buftype = "terminal"
        end)
    end
end

function BufferManager.get_aider_buffer()
    return aider_buf
end

function BufferManager.reset_aider_buffer()
    if aider_buf then
        if vim.api.nvim_buf_is_valid(aider_buf) then
            pcall(vim.api.nvim_buf_delete, aider_buf, { force = true })
        end
        aider_buf = nil
    end
end

function BufferManager.is_aider_buffer(buf)
    return buf == aider_buf
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
    if not require("aider.command_executor").is_aider_running() then
        Logger.debug("Skipping context update - Aider not running", correlation_id)
        return
    end
    local new_context = BufferManager.get_context_buffers()
    require("aider.context_manager").update(new_context)
    local commands = require("aider.context_manager").get_batched_commands()
    if #commands > 0 then
        Logger.debug("Sending context update commands: " .. vim.inspect(commands), correlation_id)
        require("aider.command_executor").queue_commands(commands, true)
    else
        Logger.debug("No context changes to send", correlation_id)
    end
    Logger.debug("Context update complete", correlation_id)
end

return BufferManager
