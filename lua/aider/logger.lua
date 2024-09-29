local config = require("aider.config")

local Logger = {}

local log_levels = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
}

local current_log_level = log_levels.INFO
local log_file = nil

function Logger.setup()
    current_log_level = log_levels[config.get("log_level")] or log_levels.INFO
    local log_path = config.get("log_file")
    if log_path then
        log_file = io.open(log_path, "a")
        if not log_file then
            vim.notify("Failed to open log file: " .. log_path, vim.log.levels.ERROR)
        end
    end
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
