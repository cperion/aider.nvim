local Config = {}

local default_config = {
	auto_manage_context = true,
	default_layout = "float",
	keys = {
		open = "<leader> ",
		toggle = "<leader>at",
		-- Remove the 'stop' key
	},
}

local user_config = {}

function Config.setup(opts)
	user_config = vim.tbl_deep_extend("force", {}, default_config, opts or {})
end

function Config.get(key)
	local value = user_config
	for part in string.gmatch(key, "[^.]+") do
		value = value[part]
		if value == nil then
			return nil
		end
	end
	return value
end

return Config
