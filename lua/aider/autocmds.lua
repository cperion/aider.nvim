local BufferManager = require("aider.buffer_manager")
local Aider = require("aider.core")
local Logger = require("aider.logger")

local M = {}

function M.setup()
    local aider_group = vim.api.nvim_create_augroup("Aider", { clear = true })

    -- Monitor buffer state changes
    vim.api.nvim_create_autocmd({
        "BufAdd",
        "BufDelete",
        "BufEnter",
        "BufFilePost",  -- Catches file renames
        "BufWipeout"
    }, {
        group = aider_group,
        callback = function(ev)
            -- Small delay to ensure buffer state is settled
            vim.defer_fn(function()
                if BufferManager.should_include_in_context(ev.buf) then
                    BufferManager.update_context()
                end
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
