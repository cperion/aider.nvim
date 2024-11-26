local BufferManager = require("aider.buffer_manager")
local Aider = require("aider.core")
local Logger = require("aider.logger")

local M = {}

function M.setup()
    local aider_group = vim.api.nvim_create_augroup("Aider", { clear = true })

    -- Separate handler for BufAdd to ensure proper handling of new buffers
    vim.api.nvim_create_autocmd("BufAdd", {
        group = aider_group,
        callback = function(ev)
            -- Defer the update to ensure buffer is properly loaded
            vim.defer_fn(function()
                if vim.api.nvim_buf_is_valid(ev.buf) then
                    require("aider.command_executor").on_buffer_open(ev.buf)
                end
            end, 100)
        end,
    })

    -- Keep existing autocmds for other buffer events
    vim.api.nvim_create_autocmd({
        "BufDelete",
        "BufEnter",
        "BufFilePost",
    }, {
        group = aider_group,
        callback = function()
            vim.defer_fn(function()
                require("aider.buffer_manager").update_context()
            end, 50)
        end,
    })

    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = aider_group,
        callback = function()
            Logger.debug("VimLeavePre autocmd triggered")
            Aider.cleanup()
        end,
    })

    vim.api.nvim_create_autocmd("BufEnter", {
        group = aider_group,
        pattern = "Aider",
        callback = function()
            Aider.on_aider_buffer_enter()
        end,
    })
end

return M
