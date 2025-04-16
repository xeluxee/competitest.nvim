local luv = vim.uv and vim.uv or vim.loop
local utils = require("competitest.utils")
local M = {}
local storage_utils = {}

---@alias competitest.CCTask.batch_id string

---competitive-companion task format (https://github.com/jmerle/competitive-companion/#the-format)
---@class (exact) competitest.CCTask
---@field name string
---@field group string
---@field url string
---@field interactive boolean?
---@field memoryLimit number
---@field timeLimit number
---@field tests { input: string, output: string }[]
---@field testType "single" | "multiNumber"
---@field input { type: "stdin" | "file" | "regex", fileName: string?, pattern: string? }
---@field output { type: "stdout" | "file", fileName: string? }
---@field languages { java: { mainClass: string, taskClass: string }, [string]: any }
---@field batch { id: competitest.CCTask.batch_id, size: integer }

---------------- RECEIVE UTILITIES ----------------

---Receive tasks from competitive-companion
---@class (exact) competitest.Receiver
---@field private server uv.uv_tcp_t
local Receiver = {}
Receiver.__index = Receiver ---@diagnostic disable-line: inject-field

---Create a new `Receiver` and start listening to `address:port`
---@param address string address to bind server socket to
---@param port integer port to bind server socket to
---@param callback fun(task: competitest.CCTask) called every time EOF is reached from an incoming stream, accepting the received task as argument
---@return competitest.Receiver | string # a new `Receiver`, or string describing error on failure
function Receiver:new(address, port, callback)
	local server = luv.new_tcp()
	if not server then
		return "server TCP socket creation failed"
	end
	local bind_success, bind_error = server:bind(address, port)
	if not bind_success then
		return string.format("cannot bind receiver to %s:%d%s", address, port, bind_error and (": " .. bind_error) or "")
	end
	local listen_success, listen_error = server:listen(128, function(err)
		assert(not err, err)
		local client = luv.new_tcp()
		assert(client, "CompetiTest.nvim: Receiver:new, server:listen: client TCP socket creation failed")
		server:accept(client)
		local message = {} -- received string
		client:read_start(function(error, chunk)
			assert(not error, error)
			if chunk then
				table.insert(message, chunk)
			else
				client:read_stop()
				client:close()
				local content = string.match(table.concat(message), "^.+\r\n(.+)$") -- last line, text after last \r\n
				local task = vim.json.decode(content)
				callback(task)
			end
		end)
	end)
	if not listen_success then
		return string.format("cannot listen or bind receiver to %s:%d%s", address, port, listen_error and (": " .. listen_error) or "")
	end
	---@type competitest.Receiver
	local this = {
		server = server,
	}
	setmetatable(this, self)
	return this
end

---Close receiver and stop listening
function Receiver:close()
	if self.server:is_active() and not self.server:is_closing() then
		self.server:close()
	end
end

---Collect tasks received from competitive-companion and send them to a callback every time a batch is fully received
---@class (exact) competitest.TasksCollector
---@field private batches { [competitest.CCTask.batch_id]: { size: integer, tasks: competitest.CCTask[] } }
---@field private callback fun(tasks: competitest.CCTask[])
local TasksCollector = {}
TasksCollector.__index = TasksCollector ---@diagnostic disable-line: inject-field

---Create a new `TasksCollector`
---@param callback fun(tasks: competitest.CCTask[]) called every time a batch is fully received, accepting a batch of tasks as argument
---@return competitest.TasksCollector
function TasksCollector:new(callback)
	---@type competitest.TasksCollector
	local this = {
		batches = {},
		callback = callback,
	}
	setmetatable(this, self)
	return this
end

---Insert a competitive-companion task into collector
---@param task competitest.CCTask
function TasksCollector:insert(task)
	if not self.batches[task.batch.id] then
		self.batches[task.batch.id] = { size = task.batch.size, tasks = {} }
	end
	local b = self.batches[task.batch.id]
	table.insert(b.tasks, task)
	if b.size == #b.tasks then -- batch fully received
		local tasks = b.tasks
		self.batches[task.batch.id] = nil
		self.callback(tasks)
	end
end

---Process batches of tasks serially
---@class (exact) competitest.BatchesSerialProcessor
---@field private batches competitest.CCTask[][]
---@field private callback fun(tasks: competitest.CCTask[], finished: fun())
---@field private callback_busy boolean
---@field private stopped boolean
local BatchesSerialProcessor = {}
BatchesSerialProcessor.__index = BatchesSerialProcessor ---@diagnostic disable-line: inject-field

---Create a new `BatchesSerialProcessor`
---@param callback fun(tasks: competitest.CCTask[], finished: fun()) serially called for every enqueued batch, i.e. no two callbacks run at the same time; it accepts two arguments: batch of tasks and a function that must be called when callback finishes to unlock the batches serial processor
---@return competitest.BatchesSerialProcessor
function BatchesSerialProcessor:new(callback)
	---@type competitest.BatchesSerialProcessor
	local this = {
		batches = {},
		callback = callback,
		callback_busy = false,
		stopped = false,
	}
	setmetatable(this, self)
	return this
end

---Enqueue a batch of tasks for processing
---@param batch competitest.CCTask[]
function BatchesSerialProcessor:enqueue(batch)
	table.insert(self.batches, batch)
	self:process()
end

---@private
---Process the first enqueued batch
function BatchesSerialProcessor:process()
	if #self.batches == 0 or self.callback_busy or self.stopped then
		return
	end
	self.callback_busy = true
	local batch = self.batches[1]
	table.remove(self.batches, 1)
	self.callback(
		batch,
		vim.schedule_wrap(function()
			self.callback_busy = false
			self:process()
		end)
	)
end

---Stop processing batches, except for the currently running callback, if any
function BatchesSerialProcessor:stop()
	self.stopped = true
end

---------------- RECEIVE METHODS ----------------

---@alias competitest.ReceiveMode "testcases" | "problem" | "contest" | "persistently"

---@class (exact) competitest.ReceiveStatus
---@field mode competitest.ReceiveMode
---@field companion_port integer
---@field receiver competitest.Receiver
---@field tasks_collector competitest.TasksCollector
---@field batches_serial_processor competitest.BatchesSerialProcessor

---@type competitest.ReceiveStatus?
local rs = nil

---Stop receiving, listening to competitive-companion and processing received tasks
function M.stop_receiving()
	if rs then
		rs.receiver:close()
		rs.batches_serial_processor:stop()
		rs = nil
	end
end

---Show current receive status trough a notification
function M.show_status()
	local msg
	if not rs then
		msg = "receiving not enabled."
	else
		msg = "receiving " .. rs.mode .. ", listening on port " .. rs.companion_port .. "."
	end
	utils.notify(msg, "INFO")
end

---Start receiving tasks from competitive-companion
---@param mode competitest.ReceiveMode
---@param companion_port integer competitive-companion port to listen to
---@param notify_on_start boolean if `true` notify user when receiving starts correctly
---@param notify_on_receive boolean if `true` notify user when data is received
---@param bufnr integer? buffer number, only required when `mode` is `"testcases"`
---@param cfg competitest.Config current CompetiTest configuration
---@return nil | string # `nil`, or a string describing error on failure
function M.start_receiving(mode, companion_port, notify_on_start, notify_on_receive, bufnr, cfg)
	if rs then
		return "receiving already enabled, stop it if you want to change receive mode"
	end
	---BatchesSerialProcessor callback
	---@type fun(tasks: competitest.CCTask[], finished: fun())
	local bsp_callback
	if mode == "testcases" then
		if not bufnr then
			return "bufnr required when receiving testcases"
		end
		bsp_callback = function(tasks, _)
			M.stop_receiving()
			if notify_on_receive then
				utils.notify("testcases received successfully!", "INFO")
			end
			storage_utils.store_testcases(bufnr, tasks[1].tests, cfg.testcases_use_single_file, cfg.replace_received_testcases, nil)
		end
	elseif mode == "problem" then
		bsp_callback = function(tasks, _)
			M.stop_receiving()
			if notify_on_receive then
				utils.notify("problem received successfully!", "INFO")
			end
			storage_utils.store_single_problem(tasks[1], cfg, nil)
		end
	elseif mode == "contest" then
		bsp_callback = function(tasks, _)
			M.stop_receiving()
			if notify_on_receive then
				utils.notify("contest (" .. #tasks .. " tasks) received successfully!", "INFO")
			end
			storage_utils.store_contest(tasks, cfg, nil)
		end
	elseif mode == "persistently" then
		bsp_callback = function(tasks, finished)
			if notify_on_receive then
				if #tasks > 1 then
					utils.notify("contest (" .. #tasks .. " tasks) received successfully!", "INFO")
				else
					utils.notify("one task received successfully!", "INFO")
				end
			end
			if #tasks > 1 then
				storage_utils.store_contest(tasks, cfg, finished)
			else
				local choice = vim.fn.confirm(
					"One task received (" .. tasks[1].name .. ").\nDo you want to store its testcases only or the full problem?",
					"Testcases\nProblem\nCancel"
				)
				if choice == 1 then -- user chose "Testcases"
					storage_utils.store_testcases(
						vim.api.nvim_get_current_buf(),
						tasks[1].tests,
						cfg.testcases_use_single_file,
						cfg.replace_received_testcases,
						finished
					)
				elseif choice == 2 then -- user chose "Problem"
					storage_utils.store_single_problem(tasks[1], cfg, finished)
				else -- user pressed <esc> or chose "Cancel"
					finished()
				end
			end
		end
	end
	local batches_serial_processor = BatchesSerialProcessor:new(vim.schedule_wrap(bsp_callback))
	local tasks_collector = TasksCollector:new(function(tasks)
		batches_serial_processor:enqueue(tasks)
	end)
	local receiver_or_error = Receiver:new("127.0.0.1", companion_port, function(task)
		tasks_collector:insert(task)
	end)
	if type(receiver_or_error) == "string" then
		return receiver_or_error
	end
	rs = {
		mode = mode,
		companion_port = companion_port,
		receiver = receiver_or_error,
		tasks_collector = tasks_collector,
		batches_serial_processor = batches_serial_processor,
	}
	if notify_on_start then
		utils.notify("ready to receive " .. mode .. ". Press the green plus button in your browser.", "INFO")
	end
end

---------------- STORAGE UTILITIES ----------------

---Convert a string with CompetiTest receive modifiers into a formatted string
---@param str string the string to evaluate
---@param task competitest.CCTask received task
---@param file_extension string
---@param remove_illegal_characters boolean whether to remove windows illegal characters from modifiers or not
---@param date_format string? string used to format date
---@return string? # the converted string, or `nil` on failure
function storage_utils.eval_receive_modifiers(str, task, file_extension, remove_illegal_characters, date_format)
	local judge, contest
	local hyphen = string.find(task.group, " - ", 1, true)
	if not hyphen then
		judge = task.group
		contest = "unknown_contest"
	else
		judge = string.sub(task.group, 1, hyphen - 1)
		contest = string.sub(task.group, hyphen + 3)
	end

	---CompetiTest receive modifiers
	---@type table<string, string>
	local receive_modifiers = {
		[""] = "$", -- $(): replace it with a dollar
		["HOME"] = luv.os_homedir(), -- home directory
		["CWD"] = vim.fn.getcwd(), -- current working directory
		["FEXT"] = file_extension,
		["PROBLEM"] = task.name, -- problem name, name field
		["GROUP"] = task.group, -- judge and contest name, group field
		["JUDGE"] = judge, -- first part of group, before hyphen
		["CONTEST"] = contest, -- second part of group, after hyphen
		["URL"] = task.url, -- problem url, url field
		["MEMLIM"] = tostring(task.memoryLimit), -- available memory, memoryLimit field
		["TIMELIM"] = tostring(task.timeLimit), -- time limit, timeLimit field
		["JAVA_MAIN_CLASS"] = task.languages.java.mainClass, -- it's almost always 'Main'
		["JAVA_TASK_CLASS"] = task.languages.java.taskClass, -- classname-friendly version of problem name
		["DATE"] = tostring(os.date(date_format)),
	}

	if remove_illegal_characters then
		for modifier, value in pairs(receive_modifiers) do
			if modifier ~= "HOME" and modifier ~= "CWD" then
				receive_modifiers[modifier] = string.gsub(value, '[<>:"/\\|?*]', "_")
			end
		end
	end

	return utils.format_string_modifiers(str, receive_modifiers)
end

---Get path for received problems or contests
---@param path string | fun(task: competitest.CCTask, file_extension: string): string see `received_problems_path`, `received_contests_directory` and `received_contests_problems_path`
---@param task competitest.CCTask received task
---@param file_extension string configured file extension
---@return string? # evaluated path, or `nil` on failure
function storage_utils.eval_path(path, task, file_extension)
	if type(path) == "string" then
		return storage_utils.eval_receive_modifiers(path, task, file_extension, true)
	elseif type(path) == "function" then
		return path(task, file_extension)
	end
end

---Utility function to store received testcases
---@param bufnr integer buffer number
---@param tclist { input: string, output: string }[] received testcases
---@param use_single_file boolean whether to store testcases in a single file or not
---@param replace boolean whether to replace existing testcases with received ones or to ask user what to do
---@param finished fun()? a function that must be called when procedure finishes
function storage_utils.store_testcases(bufnr, tclist, use_single_file, replace, finished)
	local testcases = require("competitest.testcases")
	local tctbl = testcases.buf_get_testcases(bufnr)
	if next(tctbl) ~= nil then
		local choice = 2
		if not replace then
			choice = vim.fn.confirm("Some testcases already exist. Do you want to keep them along the new ones?", "Keep\nReplace\nCancel")
		end
		if choice == 2 then -- user chose "Replace"
			if not use_single_file then
				for tcnum, _ in pairs(tctbl) do -- delete existing files
					testcases.io_files.buf_write_pair(bufnr, tcnum, nil, nil)
				end
			end
			tctbl = {}
		elseif choice == 0 or choice == 3 then -- user pressed <esc> or chose "Cancel"
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
	if finished then
		finished()
	end
end

---Utility function to store received task and its testcases following configuration
---@param filepath string source file absolute path
---@param confirm_overwriting boolean whether to ask user to overwrite an already existing file or not
---@param task competitest.CCTask received task
---@param cfg competitest.Config current CompetiTest configuration
function storage_utils.store_received_task_config(filepath, confirm_overwriting, task, cfg)
	if confirm_overwriting and utils.does_file_exist(filepath) then
		local choice = vim.fn.confirm('Do you want to overwrite "' .. filepath .. '"?', "Yes\nNo")
		if choice == 0 or choice == 2 then -- user pressed <esc> or chose "No"
			return
		end
	end

	local file_extension = vim.fn.fnamemodify(filepath, ":e")
	---Template file absolute path
	---@type string?
	local template_file
	if type(cfg.template_file) == "string" then -- string with CompetiTest file-format modifiers
		---@diagnostic disable-next-line: param-type-mismatch
		template_file = utils.eval_string(filepath, cfg.template_file)
	elseif type(cfg.template_file) == "table" then -- table with paths to template files
		template_file = cfg.template_file[file_extension]
	end

	if template_file then
		template_file = string.gsub(template_file, "^%~", luv.os_homedir()) -- expand tilde into home directory
		if not utils.does_file_exist(template_file) then
			if type(cfg.template_file) == "table" then -- notify file absence when path is explicitly set
				utils.notify('template file "' .. template_file .. "\" doesn't exist.", "WARN")
			end
			template_file = nil
		end
	end

	local file_directory = vim.fn.fnamemodify(filepath, ":h")
	-- if template file exists then template_file is a string
	if template_file then
		if cfg.evaluate_template_modifiers then
			local str = utils.load_file_as_string(template_file)
			assert(str, "CompetiTest.nvim: store_received_task_config: cannot load '" .. template_file .. "'")
			local evaluated_str = storage_utils.eval_receive_modifiers(str, task, file_extension, false, cfg.date_format)
			utils.write_string_on_file(filepath, evaluated_str or "")
		else
			utils.create_directory(file_directory)
			luv.fs_copyfile(template_file, filepath)
		end
	else
		utils.write_string_on_file(filepath, "")
	end

	---@type competitest.TcTable
	local tctbl = {}
	local tcindex = 0
	-- convert testcases list into a 0-indexed testcases table
	for _, tc in ipairs(task.tests) do
		tctbl[tcindex] = tc
		tcindex = tcindex + 1
	end

	local testcases = require("competitest.testcases")
	local tcdir = file_directory .. "/" .. cfg.testcases_directory .. "/"
	if cfg.testcases_use_single_file then
		local single_file_path = tcdir .. utils.eval_string(filepath, cfg.testcases_single_file_format)
		testcases.single_file.write(single_file_path, tctbl)
	else
		testcases.io_files.write_eval_format_string(tcdir, tctbl, filepath, cfg.testcases_input_file_format, cfg.testcases_output_file_format)
	end
end

---Utility function to store a single received problem
---@param task competitest.CCTask received task
---@param cfg competitest.Config current CompetiTest configuration
---@param finished fun()? a function that must be called when procedure finishes
function storage_utils.store_single_problem(task, cfg, finished)
	local evaluated_problem_path = storage_utils.eval_path(cfg.received_problems_path, task, cfg.received_files_extension)
	if not evaluated_problem_path then
		utils.notify("'received_problems_path' evaluation failed for task '" .. task.name .. "'")
		if finished then
			finished()
		end
		return
	end

	local widgets = require("competitest.widgets")
	widgets.input("Choose problem path", evaluated_problem_path, cfg.floating_border, not cfg.received_problems_prompt_path, function(filepath)
		local config = require("competitest.config")
		local local_cfg = config.load_local_config_and_extend(vim.fn.fnamemodify(filepath, ":h"))
		storage_utils.store_received_task_config(filepath, true, task, local_cfg)
		if local_cfg.open_received_problems then
			vim.api.nvim_command("edit " .. vim.fn.fnameescape(filepath))
		end
		if finished then
			finished()
		end
	end, finished)
end

---Utility function to store received contest
---@param tasks competitest.CCTask[] received tasks
---@param cfg competitest.Config current CompetiTest configuration
---@param finished fun()? a function that must be called when procedure finishes
function storage_utils.store_contest(tasks, cfg, finished)
	local contest_directory = storage_utils.eval_path(cfg.received_contests_directory, tasks[1], cfg.received_files_extension)
	if not contest_directory then
		utils.notify("'received_contests_directory' evaluation failed")
		if finished then
			finished()
		end
		return
	end

	local widgets = require("competitest.widgets")
	widgets.input("Choose contest directory", contest_directory, cfg.floating_border, not cfg.received_contests_prompt_directory, function(directory)
		local config = require("competitest.config")
		local local_cfg = config.load_local_config_and_extend(directory)
		widgets.input(
			"Choose files extension",
			local_cfg.received_files_extension,
			local_cfg.floating_border,
			not local_cfg.received_contests_prompt_extension,
			function(file_extension)
				for _, task in ipairs(tasks) do
					local problem_path = storage_utils.eval_path(local_cfg.received_contests_problems_path, task, file_extension)
					if problem_path then
						local filepath = directory .. "/" .. problem_path
						storage_utils.store_received_task_config(filepath, true, task, local_cfg)
						if local_cfg.open_received_contests then
							vim.api.nvim_command("edit " .. vim.fn.fnameescape(filepath))
						end
					else
						utils.notify("'received_contests_problems_path' evaluation failed for task '" .. task.name .. "'")
					end
				end
				if finished then
					finished()
				end
			end,
			finished
		)
	end, finished)
end

return M
