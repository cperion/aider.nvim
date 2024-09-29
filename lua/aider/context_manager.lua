local ContextManager = {}

local current_context = {}
local previous_context = {}

function ContextManager.update(new_context)
	previous_context = vim.deepcopy(current_context)
	current_context = new_context
end

function ContextManager.get_batched_commands()
	local files_to_add = {}
	local files_to_drop = {}

	-- Files to add
	for _, file in ipairs(current_context) do
		if not vim.tbl_contains(previous_context, file) then
			table.insert(files_to_add, file)
		end
	end

	-- Files to drop
	for _, file in ipairs(previous_context) do
		if not vim.tbl_contains(current_context, file) then
			table.insert(files_to_drop, file)
		end
	end

	local commands = {}

	if #files_to_add > 0 then
		table.insert(commands, "/add " .. table.concat(files_to_add, " "))
	end

	if #files_to_drop > 0 then
		table.insert(commands, "/drop " .. table.concat(files_to_drop, " "))
	end

	return commands
end

return ContextManager
