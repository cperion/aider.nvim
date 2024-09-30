local Aider = require("aider.core")
local config = require("aider.config")
local Logger = require("aider.logger")

local M = {}

function M.setup(user_config)
    Logger.debug("Aider setup started")
    config.setup(user_config)
    Logger.debug("Config setup complete")
    Aider.setup()
    Logger.debug("Aider core setup complete")

    vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
            Logger.debug("VimLeavePre autocmd triggered")
            Aider.cleanup()
        end,
    })
    Logger.debug("VimLeavePre autocmd created")
    Logger.debug("Aider setup finished")
end

-- Export the main functions
M.open = Aider.open
M.toggle = Aider.toggle

return M
