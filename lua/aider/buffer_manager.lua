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
        -- Skip if buffer is invalid
        if not vim.api.nvim_buf_is_valid(buf) then
            goto continue
        end

        -- Get buffer info
        local bufname = vim.api.nvim_buf_get_name(buf)
        local buftype = vim.api.nvim_buf_get_option(buf, "buftype")

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
                    filetype = vim.api.nvim_buf_get_option(buf, "filetype"),
                    modified = vim.api.nvim_buf_get_option(buf, "modified")
                })
            end
        end

        ::continue::
    end
    return valid_buffers
end

function BufferManager.get_or_create_aider_buffer()
    if aider_buf and vim.api.nvim_buf_is_valid(aider_buf) then
        return aider_buf
    end

    -- Create new buffer
    local buf = vim.api.nvim_create_buf(false, true)
    if not buf then
        Logger.error("Failed to create Aider buffer")
        return nil
    end

    -- Set initial buffer options
    vim.api.nvim_buf_set_name(buf, "Aider")
    vim.api.nvim_buf_set_option(buf, "swapfile", false)
    vim.api.nvim_buf_set_option(buf, "buflisted", true)

    aider_buf = buf
    
    -- Set up the 'q' keybinding for the Aider buffer
    vim.keymap.set("n", "q", function()
        require("aider.core").toggle()
    end, { silent = true, buffer = buf })
    
    return buf
end

-- New function to set terminal options
function BufferManager.set_terminal_options(buf)
    if buf and vim.api.nvim_buf_is_valid(buf) then
        vim.schedule(function()
            pcall(vim.api.nvim_buf_set_option, buf, "buftype", "terminal")
        end)
    end
end

function BufferManager.get_aider_buffer()
    return aider_buf
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
    
    local new_context = BufferManager.get_context_buffers()
    require("aider.context_manager").update(new_context)
    
    local commands = require("aider.context_manager").get_batched_commands()
    if #commands > 0 then
        require("aider.command_executor").queue_commands(commands, true)
    end
    
    Logger.debug("Context update complete", correlation_id)
end

return BufferManager
