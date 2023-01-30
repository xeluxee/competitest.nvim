local luv = vim.loop
local testcases = require("competitest.testcases")
local utils = require("competitest.utils")
local M = {}

---Wait for competitive companion to send tasks data
---@param port integer: competitive companion port to listen on
---@param single_task boolean: whether to parse a single task or all tasks
---@param notify string | nil: if not nil notify user when receiving data. It specifies what content is received: can be "testcases", "problem" or "contest"
---@param callback function: function called after data is received, accepting list of tasks as argument
function M.receive(port, single_task, notify, callback)
	local tasks = {} -- table with tasks data
	local server, client, timer

	---Stop listening to competitive companion port
	local function stop_receiving()
		if client and not client:is_closing() then
			client:shutdown()
			client:close()
		end
		if server and not server:is_closing() then
			server:shutdown()
			server:close()
		end
		if timer and not timer:is_closing() then
			timer:stop()
			timer:close()
		end

		vim.schedule(function()
			if notify then
				utils.notify(notify .. " received successfully!", "INFO")
			end
			callback(tasks)
		end)
	end

	local message = {} -- received string
	local tasks_number = single_task and 1 or nil -- if nil download all tasks
	server = luv.new_tcp()
	server:bind("127.0.0.1", port)
	server:listen(128, function(err)
		assert(not err, err)
		client = luv.new_tcp()
		server:accept(client)
		client:read_start(function(error, chunk)
			assert(not error, error)
			if chunk then
				table.insert(message, chunk)
			else
				message = string.match(table.concat(message), "^.+\r\n(.+)$") -- last line, text after last \r\n
				message = vim.json.decode(message)
				table.insert(tasks, message)
				tasks_number = tasks_number or message.batch.size
				tasks_number = tasks_number - 1
				if tasks_number == 0 then
					stop_receiving()
				end
				message = {}
			end
		end)
	end)

	-- if after 100 seconds nothing happened stop listening
	timer = luv.new_timer()
	timer:start(100000, 0, stop_receiving)

	if notify then
		utils.notify("ready to receive " .. notify .. ". Press the green plus button in your browser.", "INFO")
	end
end

---Utility function to store received testcases
---@param bufnr integer: buffer number
---@param tclist table: table containing received testcases
---@param use_single_file boolean: whether to store testcases in a single file or not
function M.store_testcases(bufnr, tclist, use_single_file)
	local tctbl = testcases.buf_get_testcases(bufnr)
	if next(tctbl) ~= nil then
		local choice = vim.fn.confirm("Some testcases already exist. Do you want to keep them along the new ones?", "&Keep\n&Replace\n&Cancel")
		if choice == 2 then -- user chose "Replace"
			if not use_single_file then
				for tcnum, _ in pairs(tctbl) do -- delete existing files
					testcases.io_files.buf_write_pair(bufnr, tcnum, nil, nil)
				end
			end
			tctbl = {}
		elseif choice == 3 then -- user chose "Cancel"
			return
		end
	end

	local tcindex = 0
	for _, tc in ipairs(tclist) do
		while tctbl[tcindex] do
			tcindex = tcindex + 1
		end
		tctbl[tcindex] = tc
		tcindex = tcindex + 1
	end

	testcases.buf_write_testcases(bufnr, tctbl, use_single_file)
end

---Utility function to store received problem (source file and testcases)
---@param filepath string: source file absolute path
---@param tcdir string: directory where testcases files will be stored
---@param tclist table: table containing received testcases
---@param use_single_file boolean: whether to store testcases in a single file or not
---@param single_file_format string: string with CompetiTest modifiers to match single testcases file name
---@param input_file_format string: string with CompetiTest modifiers to match input files name
---@param output_file_format string: string with CompetiTest modifiers to match output files name
---@param template_file string: string with the absolute location of template file to use.
function M.store_problem(filepath, tcdir, tclist, use_single_file, single_file_format, input_file_format, output_file_format, template_file)
	local template = utils.load_file_as_string(vim.fs.normalize(utils.eval_string(filepath, template_file, nil)))
	utils.write_string_on_file(filepath, template)

	local tctbl = {}
	local tcindex = 0
	-- convert tclist into a 0-indexed testcases table
	for _, tc in ipairs(tclist) do
		tctbl[tcindex] = tc
		tcindex = tcindex + 1
	end

	if use_single_file then
		local single_file_path = tcdir .. utils.eval_string(filepath, single_file_format, nil)
		testcases.single_file.write(single_file_path, tctbl)
	else
		testcases.io_files.write_eval_format_string(tcdir, tctbl, filepath, input_file_format, output_file_format)
	end
end

return M
