local helpers = require("lua.helpers")
local M = {}

M.aider_buf = nil
M.aider_win = nil

function M.AiderBackground(args, message)
	helpers.showProcessingCue()
	local command = helpers.build_background_command(args, message)
	local handle = vim.loop.spawn("bash", {
		args = { "-c", command },
	}, NotifyOnExit)

	vim.notify("Aider started " .. (args or ""))
end

function OnExit(code, signal)
    M.aider_buf = nil
end

function M.AiderOpen(args, layout)
    layout = layout or M.config.default_layout or "float"
    
    if M.aider_buf and vim.api.nvim_buf_is_valid(M.aider_buf) then
        -- If the buffer exists, just show it in the specified layout
        M.show_aider_window(layout)
    else
        -- Create a new buffer
        M.aider_buf = vim.api.nvim_create_buf(false, true)
        
        -- Show the buffer in the specified layout
        M.show_aider_window(layout)

        -- Use vim.schedule to ensure the terminal is properly initialized
        vim.schedule(function()
            -- Set buffer options
            vim.api.nvim_buf_set_option(M.aider_buf, 'buftype', 'nofile')
            vim.api.nvim_buf_set_option(M.aider_buf, 'buflisted', false)
            vim.api.nvim_buf_set_name(M.aider_buf, "Aider")

            -- Run Aider in the buffer
            command = "aider " .. (args or "")
            command = helpers.add_buffers_to_command(command)
            M.aider_job_id = vim.fn.termopen(command, { on_exit = OnExit })

            -- Enter insert mode after a short delay
            vim.defer_fn(function()
                vim.cmd('startinsert')
            end, 100)
        end)
    end
end

function M.show_aider_window(layout)
    if layout == "float" then
        local width = math.floor(vim.o.columns * 0.8)
        local height = math.floor(vim.o.lines * 0.8)
        local row = math.floor((vim.o.lines - height) / 2)
        local col = math.floor((vim.o.columns - width) / 2)

        local opts = {
            relative = 'editor',
            width = width,
            height = height,
            row = row,
            col = col,
            style = 'minimal',
            border = 'rounded'
        }

        M.aider_win = vim.api.nvim_open_win(M.aider_buf, true, opts)
        vim.api.nvim_win_set_option(M.aider_win, 'winblend', 0)
    elseif layout == "vsplit" then
        vim.cmd("vsplit")
        M.aider_win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(M.aider_win, M.aider_buf)
    elseif layout == "hsplit" then
        vim.cmd("split")
        M.aider_win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(M.aider_win, M.aider_buf)
    end
end

function M.AiderHide()
    if M.aider_win and vim.api.nvim_win_is_valid(M.aider_win) then
        vim.api.nvim_win_close(M.aider_win, true)
        M.aider_win = nil
    end
end

function M.AiderToggle()
	if M.aider_win then
		M.AiderHide()
	else
		M.AiderOpen()
	end
end

function M.AiderOnBufferOpen(bufnr)
    if not vim.g.aider_buffer_sync or vim.g.aider_buffer_sync == 0 then
        return
    end
    bufnr = tonumber(bufnr)
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local buftype = vim.fn.getbufvar(bufnr, "&buftype")
    if not bufname or bufname:match("^term://") or buftype == "terminal" or bufname == "Aider" then
        return
    end
    local relative_filename = vim.fn.fnamemodify(bufname, ":~:.")
    if M.aider_buf and vim.api.nvim_buf_is_valid(M.aider_buf) then
        local line_to_add = "/add " .. relative_filename
        vim.fn.chansend(M.aider_job_id, line_to_add .. "\n")
    end
end

function M.AiderOnBufferClose(bufnr)
	if not vim.g.aider_buffer_sync or vim.g.aider_buffer_sync == 0 then
		return
	end
	bufnr = tonumber(bufnr)
	local bufname = vim.api.nvim_buf_get_name(bufnr)
	if not bufname or bufname:match("^term://") then
		return
	end
	local relative_filename = vim.fn.fnamemodify(bufname, ":~:.")
	if M.aider_buf and vim.api.nvim_buf_is_valid(M.aider_buf) then
		local line_to_drop = "/drop " .. relative_filename
		vim.fn.chansend(M.aider_job_id, line_to_drop .. "\n")
	end
end

function M.setup(config)
    M.config = config or {}
    M.config.auto_manage_context = M.config.auto_manage_context or true
    M.config.default_bindings = M.config.default_bindings or true
    M.config.default_layout = M.config.default_layout or "float"

    vim.g.aider_buffer_sync = M.config.auto_manage_context

    if M.config.auto_manage_context then
        vim.api.nvim_command('autocmd BufReadPost * lua AiderOnBufferOpen(vim.fn.expand("<abuf>"))')
        vim.api.nvim_command('autocmd BufDelete * lua AiderOnBufferClose(vim.fn.expand("<abuf>"))')
        _G.AiderOnBufferOpen = M.AiderOnBufferOpen
        _G.AiderOnBufferClose = M.AiderOnBufferClose
    end

    _G.AiderOpen = M.AiderOpen
    _G.AiderToggle = M.AiderToggle
    _G.AiderBackground = M.AiderBackground
    _G.aider_background_status = "idle"

    if M.config.default_bindings then
        require("keybindings")
    end
end

return M
