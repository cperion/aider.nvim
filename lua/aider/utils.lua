local Path = require("plenary.path")

local M = {}

function M.get_relative_path(file)
    local cwd = vim.fn.getcwd()
    local abs_path = Path:new(file):absolute()
    return Path:new(abs_path):make_relative(cwd)
end

return M
