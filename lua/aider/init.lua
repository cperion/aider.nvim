local config = require("aider.config")
local Logger = require("aider.logger")
local Autocmds = require("aider.autocmds")

local M = {}

function M.setup(user_config)
	Logger.debug("Aider setup started")
	config.setup(user_config)
	Logger.debug("Config setup complete")

	-- Defer the core setup to avoid circular dependency
	vim.defer_fn(function()
		local Aider = require("aider.core")
		Aider.setup()
		Logger.debug("Aider core setup complete")

		vim.defer_fn(function()
			Autocmds.setup()
			Logger.debug("Autocmds setup complete")
		end, 0)
	end, 0)

	Logger.debug("Aider setup finished")
end

-- Export the main functions
function M.open(args, layout)
	require("aider.core").open(args, layout)
end

function M.toggle(args, layout)
	require("aider.core").toggle(args, layout)
end

function M.mass_sync_context()
	require("aider.core").mass_sync_context()
end

return M
