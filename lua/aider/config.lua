local Config = {}

local default_config = {
    auto_manage_context = true,
    default_layout = "float",
    update_debounce_ms = 500,
    max_buffer_size = 1000000, -- 1MB
    keys = {
        open = "<leader> ",
        toggle = "<leader>at",
    },
    log_level = vim.log.levels.INFO,
    log_file = nil, -- Set to a file path to enable file logging
}

local user_config = {}

function Config.setup(opts)
    user_config = vim.tbl_deep_extend("force", {}, default_config, opts or {})
    Logger.debug("Config setup complete. User config: " .. vim.inspect(user_config))
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
