local Config = {}

local Logger

local default_config = {
	auto_manage_context = true,
	default_layout = "vsplit",
	max_buffer_size = 1000000, -- 1MB
	aider_args = "", -- Default CLI arguments for Aider
	keys = {
		open = "<leader>ao",
		toggle = "<leader>at",
	},
	log = {
		level = "INFO",
		file = nil, -- Will be set to default in setup if not provided
	},
	auto_scroll = true,
	max_context_file_size = 1024 * 1024, -- 1MB
}

local user_config = {}

function Config.setup(opts)
	-- Deep merge with default config
	user_config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), opts or {})

	-- Set default log file if not provided
	if not user_config.log.file then
		user_config.log.file = vim.fn.stdpath("cache") .. "/aider.log"
	end

	-- Convert log level to vim.log.levels and set legacy fields for compatibility
	user_config.log_level = vim.log.levels[user_config.log.level] or vim.log.levels.INFO
	user_config.log_file = user_config.log.file

	Logger = require("aider.logger")
	Logger.setup()

	-- Add more detailed logging of the final configuration
	Logger.debug("Config setup complete. Full user config: " .. vim.inspect(user_config))
	Logger.debug("Aider args from config: " .. tostring(user_config.aider_args))
end

function Config.get(key)
	local value = user_config
	for part in string.gmatch(key, "[^.]+") do
		value = value[part]
		if value == nil then
			-- If the key is not found in user_config, check default_config
			Logger.debug("Config key '" .. key .. "' not found in user_config, using default value")
			return default_config[key]
		end
	end
	return value
end

function Config.get_all()
	return vim.deepcopy(user_config)
end

return Config
