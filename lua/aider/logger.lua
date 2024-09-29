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
