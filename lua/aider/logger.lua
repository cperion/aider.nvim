local config = require("aider.config")

local Logger = {}

local log_file = nil

function Logger.setup()
    local log_path = config.get("log_file")
    if log_path then
        log_file = io.open(log_path, "a")
        if not log_file then
            vim.notify("Failed to open log file: " .. log_path, vim.log.levels.ERROR)
        end
    end
end

function Logger.log(message, level)
    level = level or vim.log.levels.INFO
    if level >= config.get("log_level") then
        local formatted_message = string.format("[%s] %s", os.date("%Y-%m-%d %H:%M:%S"), message)
        vim.notify(formatted_message, level)
        if log_file then
            log_file:write(formatted_message .. "\n")
            log_file:flush()
        end
    end
end

function Logger.debug(message)
    Logger.log(message, vim.log.levels.DEBUG)
end

function Logger.info(message)
    Logger.log(message, vim.log.levels.INFO)
end

function Logger.warn(message)
    Logger.log(message, vim.log.levels.WARN)
end

function Logger.error(message)
    Logger.log(message, vim.log.levels.ERROR)
end

function Logger.cleanup()
    if log_file then
        log_file:close()
    end
end

return Logger
local Logger = {}

local log_levels = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
}

local current_log_level = log_levels.INFO
local log_file = nil

function Logger.setup(opts)
    opts = opts or {}
    current_log_level = opts.log_level or log_levels.INFO
    log_file = opts.log_file
end

function Logger.set_log_level(level)
    if log_levels[level] then
        current_log_level = log_levels[level]
    else
        error("Invalid log level: " .. tostring(level))
    end
end

local function log(level, message, correlation_id)
    if log_levels[level] >= current_log_level then
        local log_message = string.format("[%s] %s: %s", os.date("%Y-%m-%d %H:%M:%S"), level, message)
        if correlation_id then
            log_message = log_message .. " [CorrelationID: " .. correlation_id .. "]"
        end
        print(log_message)
        if log_file then
            local file = io.open(log_file, "a")
            if file then
                file:write(log_message .. "\n")
                file:close()
            end
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

return Logger
