local BufferManager = require("aider.buffer_manager")
local ContextManager = require("aider.context_manager")
local Logger = require("aider.logger")
local config = require("aider.config")
local Utils = require("aider.utils")
local Utils = require("aider.utils")

local M = {}
local aider_buf = nil
local aider_job_id = nil
local command_queue = {}
local is_executing = false

function M.scroll_to_bottom()
	if aider_buf and vim.api.nvim_buf_is_valid(aider_buf) then
		local window = vim.fn.bufwinid(aider_buf)
		if window ~= -1 then
			local line_count = vim.api.nvim_buf_line_count(aider_buf)
			vim.api.nvim_win_set_cursor(window, { line_count, 0 })
		end
	end
end

function M.setup()
    -- Autocommands are now managed in autocmds.lua
end

function M.is_aider_running()
	return aider_job_id ~= nil and aider_job_id > 0
end

function M.start_aider(buf, args, initial_context)
	local correlation_id = Logger.generate_correlation_id()
	args = args or ""
	initial_context = initial_context or {}

	Logger.debug("start_aider: Starting with buffer " .. tostring(buf) .. " and args: " .. args, correlation_id)
	Logger.debug("start_aider: Initial context: " .. vim.inspect(initial_context), correlation_id)

	-- Construct the command
	local command = "aider " .. args

	-- Add each file from the initial context to the command, properly escaped
	for _, file in ipairs(initial_context) do
		command = command .. " " .. vim.fn.shellescape(file)
	end

	Logger.info("Starting Aider", correlation_id)
	Logger.debug("Command: " .. command, correlation_id)

	-- Start the job using vim.fn.termopen and store the job ID
	aider_job_id = vim.fn.termopen(command, {
		on_exit = function(job_id, exit_code, event_type)
			M.on_aider_exit(exit_code)
		end,
	})

	if aider_job_id <= 0 then
		Logger.error("Failed to start Aider job. Job ID: " .. tostring(aider_job_id), correlation_id)
		return
	end

	Logger.debug("Aider job started with job_id: " .. tostring(aider_job_id), correlation_id)

	aider_buf = buf
	ContextManager.update(initial_context)
	Logger.debug("Context updated", correlation_id)

	Logger.info("Aider started successfully", correlation_id)

	-- Scroll to the bottom after starting Aider if auto_scroll is enabled
	if config.get("auto_scroll") then
		vim.schedule(function()
			M.scroll_to_bottom()
		end)
	end
end

function M.update_aider_context()
	local correlation_id = Logger.generate_correlation_id()
	Logger.debug("update_aider_context: Starting context update", correlation_id)

	if M.is_aider_running() then
		local new_context = BufferManager.get_aider_context()
		local commands = ContextManager.get_batched_commands()

		Logger.info("Updating Aider context", correlation_id)
		Logger.debug("New context: " .. vim.inspect(new_context), correlation_id)
		Logger.debug("Generated commands: " .. vim.inspect(commands), correlation_id)

		if #commands > 0 then
			M.queue_commands(commands, true) -- Set is_context_update to true
			Logger.debug("Context update commands queued", correlation_id)
		else
			Logger.debug("No context update commands to execute", correlation_id)
		end
	else
		Logger.warn("Aider job is not running, context update skipped", correlation_id)
	end

	Logger.debug("update_aider_context: Context update finished", correlation_id)
end

function M.queue_commands(inputs, is_context_update)
	for _, input in ipairs(inputs) do
		table.insert(command_queue, { input = input, is_context_update = is_context_update })
	end
	M.process_command_queue()
end

function M.process_command_queue()
	if is_executing or #command_queue == 0 or not M.is_aider_running() or not aider_buf then
		return
	end

	is_executing = true
	local inputs_to_send = {}
	local context_update_inputs = {}

	-- Separate context update inputs from user inputs
	for _, input_data in ipairs(command_queue) do
		if input_data.is_context_update then
			table.insert(context_update_inputs, input_data.input)
		else
			table.insert(inputs_to_send, input_data.input)
		end
	end
	command_queue = {}

	-- Process context update inputs first
	if #context_update_inputs > 0 then
		for _, input in ipairs(context_update_inputs) do
			M.send_input(input)
		end
		Logger.debug("Context update inputs sent to Aider: " .. vim.inspect(context_update_inputs))
	end

	-- Process user inputs
	if #inputs_to_send > 0 then
		for _, input in ipairs(inputs_to_send) do
			M.send_input(input)
		end
		Logger.debug("User inputs sent to Aider: " .. vim.inspect(inputs_to_send))
	end

	-- Wait for a short time before processing the next batch of inputs
	vim.defer_fn(function()
		is_executing = false
		M.process_command_queue()
	end, 500) -- 500ms delay to allow for input execution
end

function M.send_input(input)
	if input:match("^/") then
		-- It's a command, send it as is
		vim.fn.chansend(aider_job_id, input .. "\n")
	else
		-- It's raw text, send it without adding a slash
		vim.fn.chansend(aider_job_id, input)
	end

	-- Scroll to the bottom after sending input if auto_scroll is enabled
	if config.get("auto_scroll") then
		vim.schedule(function()
			M.scroll_to_bottom()
		end)
	end
end

function M.on_buffer_open(bufnr)
	if not M.is_aider_running() then
		return
	end

	local bufname = vim.api.nvim_buf_get_name(bufnr)
	local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
	if not bufname or bufname:match("^term://") or buftype == "terminal" then
		return
	end

	local relative_filename = get_relative_path(bufname)
	M.queue_commands({ "/add " .. relative_filename }, true)

	Logger.debug("Buffer opened: " .. relative_filename)
end

function M.on_buffer_close(bufnr)
	if not M.is_aider_running() then
		return
	end

	local bufname = vim.api.nvim_buf_get_name(bufnr)
	if not bufname or bufname:match("^term://") then
		return
	end

	local relative_filename = get_relative_path(bufname)
	M.queue_commands({ "/drop " .. relative_filename }, true)

	Logger.debug("Buffer closed: " .. relative_filename)
end

function M.on_aider_exit(exit_code)
	aider_job_id = nil
	aider_buf = nil
	command_queue = {}
	is_executing = false
	ContextManager.update({})
	vim.schedule(function()
		if exit_code ~= nil then
			Logger.info("Aider finished with exit code " .. tostring(exit_code))
		else
			Logger.info("Aider finished")
		end
	end)
end

return M
