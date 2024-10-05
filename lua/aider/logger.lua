local config = require("aider.config")
local Path = require("plenary.path")

local Logger = {}

local log_levels = {
	DEBUG = 1,
	INFO = 2,
	WARN = 3,
	ERROR = 4,
}

local current_log_level = log_levels.INFO
local log_file = nil

local function get_plugin_directory()
	local source = debug.getinfo(1, "S").source
	local file = string.sub(source, 2) -- Remove the '@' at the beginning
	return Path:new(file):parent():parent():parent()
end

function Logger.setup()
	current_log_level = log_levels[config.get("log_level")] or log_levels.DEBUG -- Set to DEBUG by default

	local log_path = config.get("log_file") or (get_plugin_directory() / "aider.log")

	log_file = io.open(tostring(log_path), "w")
	if not log_file then
		vim.notify("Failed to open log file: " .. tostring(log_path), vim.log.levels.ERROR)
	else
		vim.notify("Aider log file: " .. tostring(log_path), vim.log.levels.INFO)
	end

	Logger.debug("Logger setup complete")
end

local function log(level, message, correlation_id)
	if log_levels[level] >= current_log_level then
		local log_message = string.format("[%s] %s: %s", os.date("%Y-%m-%d %H:%M:%S"), level, tostring(message))
		if correlation_id then
			log_message = log_message .. " [CorrelationID: " .. tostring(correlation_id) .. "]"
		end
		vim.notify(log_message, vim.log.levels[level])
		if log_file then
			log_file:write(log_message .. "\n")
			log_file:flush()
		end
	end
end

function Logger.debug(message, correlation_id)
	log("DEBUG", message, correlation_id)
end

function Logger.info(message, correlation_id)
	log("INFO", message, correlation_id)
end

function Logger.warn(message, correlation_id)
	log("WARN", message, correlation_id)
end

function Logger.error(message, correlation_id)
	log("ERROR", message, correlation_id)
end

function Logger.generate_correlation_id()
	return string.format("%08x", math.random(0, 0xffffffff))
end

function Logger.cleanup()
	if log_file then
		log_file:close()
	end
end

return Logger
