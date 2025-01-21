local M = {}

local state = {
	active = false, -- If aider process is running
	visible = false, -- If window is displayed
	job_id = nil, -- Terminal job ID
	buf_id = nil, -- Terminal buffer ID
	win_id = nil, -- Window ID
	layout = "vsplit", -- Last used layout
	dimensions = { -- Last window size
		width = nil,
		height = nil,
		pos = nil,
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

	if state.win_id then
		state.visible = vim.api.nvim_win_is_valid(state.win_id)
	else
		state.visible = false
	end

	if state.buf_id and not vim.api.nvim_buf_is_valid(state.buf_id) then
		state.buf_id = nil
		state.active = false
	end

	return state
end

function M.update(updates)
	state = vim.tbl_deep_extend("force", state, updates)
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
		win_id = nil,
		layout = "vsplit",
		dimensions = {
			width = nil,
			height = nil,
			pos = nil,
		},
		context = {},
	}
	return state
end

return M

