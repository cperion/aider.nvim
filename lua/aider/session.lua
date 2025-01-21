local M = {}

-- State management with clear separation between process and UI concerns
local state = {
    -- Process state
    active = false,      -- If aider process is running
    job_id = nil,        -- Terminal job ID
    buf_id = nil,        -- Terminal buffer ID
    context = {},        -- Current file context
    terminal_state = nil, -- Preserved terminal state
    
    -- UI state
    visible = false,     -- If window is displayed
    layout = "vsplit",   -- Last used layout
    dimensions = {
        float = { width = 80, height = 20, pos = {1, 5} },
        vsplit = { width = 60 },
        hsplit = { height = 15 }
    }
}

function M.validate()
    -- Primary validation: buffer state
    if state.buf_id and not vim.api.nvim_buf_is_valid(state.buf_id) then
        state.buf_id = nil
        state.active = false
        state.visible = false
    end

    -- Secondary validation: process state
    if state.job_id then
        state.active = vim.fn.jobwait({ state.job_id }, 0)[1] == -1
    else
        state.active = false
    end

    -- Visibility derived from buffer windows
    if state.buf_id then
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.api.nvim_win_is_valid(win) and
               vim.api.nvim_win_get_buf(win) == state.buf_id then
                state.visible = true
                return state
            end
        end
    end
    state.visible = false

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
        -- Process state
        active = false,
        job_id = nil,
        buf_id = nil,
        context = {},
        terminal_state = nil,
        
        -- UI state
        visible = false,
        layout = "vsplit",
        dimensions = {
            float = { width = 80, height = 20, pos = {1, 5} },
            vsplit = { width = 60 },
            hsplit = { height = 15 }
        }
    }
    return state
end

return M
