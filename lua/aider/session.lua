local M = {}

local state = {
    active = false, -- If aider process is running
    visible = false, -- If window is displayed
    job_id = nil, -- Terminal job ID
    buf_id = nil, -- Terminal buffer ID
    layout = "vsplit", -- Last used layout
    dimensions = {
        float = { width = 80, height = 20, pos = {1, 5} },
        vsplit = { width = 60 },
        hsplit = { height = 15 }
    },
    context = {}, -- Current file context
}

function M.validate()
    -- Ensure all state references are valid
    if state.job_id then
        state.active = vim.fn.jobwait({ state.job_id }, 0)[1] == -1
    else
        state.active = false
    end

    -- Window visibility now determined by buffer presence
    local wins = vim.api.nvim_tabpage_list_wins(0)
    state.visible = false
    for _, win in ipairs(wins) do
        local buf = vim.api.nvim_win_get_buf(win)
        if buf == state.buf_id then
            state.visible = true
            break
        end
    end

    if state.buf_id and not vim.api.nvim_buf_is_valid(state.buf_id) then
        state.buf_id = nil
        state.active = false
    end

    return state
end

function M.update(updates)
    -- Handle dimension updates specially to preserve per-layout settings
    if updates.dimensions then
        local layout = state.layout
        state.dimensions[layout] = vim.tbl_deep_extend("force",
            state.dimensions[layout] or {},
            updates.dimensions)
        updates.dimensions = nil
    end

    state = vim.tbl_deep_extend("force", state, updates or {})
    return M.validate()
end

function M.get()
    return vim.deepcopy(state)
end

function M.clear()
    state = {
        active = false,
        visible = false,
        job_id = nil,
        buf_id = nil,
        layout = "vsplit",
        dimensions = {
            float = { width = 80, height = 20, pos = {1, 5} },
            vsplit = { width = 60 },
            hsplit = { height = 15 }
        },
        context = {},
    }
    return state
end

return M
