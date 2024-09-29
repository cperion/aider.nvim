local Aider = require("aider.core")
local config = require("aider.config")

local M = {}

function M.setup(user_config)
	config.setup(user_config)
	Aider.setup()
end

return M
