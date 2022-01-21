local api = vim.api
local luv = vim.loop
local cgc = require("competitest.config").get_config
local compare = require("competitest.compare")
local utils = require("competitest.utils")
local ui = require("competitest.runner_ui")

local TCRunner = {}
TCRunner.__index = TCRunner

---Create a new Testcase Runner
---@param bufnr integer: buffer number that specify the buffer to associate the runner with
---@param restore_winid integer | nil: bring the cursor to the given window after runner is closed
---@return table: a new TCRunner object
function TCRunner:new(bufnr, restore_winid)
	local filetype = api.nvim_buf_get_option(bufnr, "filetype")
	local filedir = api.nvim_buf_call(bufnr, function()
		return vim.fn.expand("%:p:h")
	end) .. "/"

	local function eval_command(command)
		if command == nil then
			return nil
		end
		local exec = utils.eval_string(command.exec, 0, "", bufnr)
		local args = {}
		for index, value in ipairs(command.args or {}) do
			args[index] = utils.eval_string(value, 0, "", bufnr)
		end
		return { exec = exec, args = args }
	end

	local config = cgc(bufnr)
	local this = {
		config = config,
		bufnr = bufnr,
		cc = eval_command(config.compile_command[filetype]), -- compile command
		rc = eval_command(config.run_command[filetype]), -- run command
		compile_directory = filedir .. config.compile_directory .. "/",
		running_directory = filedir .. config.running_directory .. "/",
		testcase_directory = filedir .. config.testcases_directory .. "/",
		restore_winid = restore_winid,
	}
	if this.rc == nil then
		vim.notify(
			"CompetiTest.nvim: TCRunner:new: run command for filetype '" .. filetype .. "' isn't configured properly.\nCannot proceed.",
			vim.log.levels.ERROR
		)
		return nil
	end

	setmetatable(this, self)
	return this
end

---Run the testcases specified in self.tcdata
---@param tctbl table | nil: table associating testcase numbers to file names
---@param compile boolean | nil: whether to compile or not
function TCRunner:run_testcases(tctbl, compile)
	if tctbl then -- if tctbl isn't specified use the testcases that were previously loaded
		if self.config.save_all_files then
			api.nvim_command("wa")
		elseif self.config.save_current_file then
			api.nvim_buf_call(self.bufnr, function()
				api.nvim_command("w")
			end)
		end

		self.tcdata = {} -- table containing data about testcases and results
		if compile == nil then -- if not specified compile
			compile = true
		end
		self.compile = compile and self.cc ~= nil
		if self.compile then -- if compilation is needed we add it as a testcase
			table.insert(self.tcdata, { stdin = "", expout = nil, tcnum = "Compile" })
		end
		for tcnum, files in pairs(tctbl) do
			if files.input then -- it makes no sense to consider a testcase without input
				table.insert(self.tcdata, {
					-- newline after stdin is needed, otherwise execution will get stuck in some cases
					stdin = utils.load_file_as_string(self.testcase_directory .. files.input) .. "\n",
					-- expout = expected output
					expout = files.output and utils.load_file_as_string(self.testcase_directory .. files.output) or nil,
					tcnum = tcnum,
					timelimit = self.config.maximum_time,
				})
			end
		end
	end

	-- reset running data
	for _, tc in pairs(self.tcdata) do
		tc.status = ""
		tc.hlgroup = "CompetiTestRunning"
		tc.stdout = ""
		tc.stderr = ""
		tc.running = false
		tc.killed = false
		tc.time = nil
	end

	local tc_size = #self.tcdata -- how many testcases
	local mut = self.config.multiple_testing -- multiple testing, how many testcases to run at the same time
	if mut == -1 then -- -1 -> use the number of available cpu cores
		mut = #vim.loop.cpu_info()
	elseif mut == 0 then -- 0 -> run all testcases together
		mut = tc_size
	end
	mut = math.min(tc_size, mut)
	local next_tc = 1

	function self.run_next_tc(tcnum)
		if tcnum then
			if tcnum == 1 and self.compile then
				self:execute_testcase(tcnum, self.cc.exec, self.cc.args, self.compile_directory)
			else
				self:execute_testcase(tcnum, self.rc.exec, self.rc.args, self.running_directory)
			end
			return
		end
		if next_tc > tc_size then
			return
		end
		next_tc = next_tc + 1
		self:execute_testcase(next_tc - 1, self.rc.exec, self.rc.args, self.running_directory, self.run_next_tc)
	end

	local function run_first_testcases()
		local starting_tc = next_tc
		next_tc = next_tc + mut
		for tcnum = starting_tc, math.min(tc_size, starting_tc + mut - 1) do
			self:execute_testcase(tcnum, self.rc.exec, self.rc.args, self.running_directory, self.run_next_tc)
		end
	end

	if not self.compile then
		run_first_testcases()
	else
		next_tc = 2
		local function compilation_callback()
			if self.tcdata[1].exit_code == 0 then
				run_first_testcases()
			end
		end
		self:execute_testcase(1, self.cc.exec, self.cc.args, self.compile_directory, compilation_callback)
	end
end

---Start a testcase process with given parameters
---@param tcindex integer: testcase index, refer to self.tcdata
---@param exec string: name of executable
---@param args table: array of its arguments
---@param dir string: current working directory
---@param callback function | nil: callback function
function TCRunner:execute_testcase(tcindex, exec, args, dir, callback)
	local process = {
		exec = exec,
		args = args,
		stdin = luv.new_pipe(false),
		stdout = luv.new_pipe(false),
		stderr = luv.new_pipe(false),
	}
	local tc = self.tcdata[tcindex]

	process.handle, process.pid = luv.spawn(process.exec, {
		args = process.args,
		cwd = dir,
		stdio = { process.stdin, process.stdout, process.stderr },
	}, function(code, signal)
		tc.running = false
		tc.time = luv.now() - tc.process.starting_time
		tc.exit_code = code
		tc.exit_signal = signal

		-- determine process status to display
		if tc.killed then
			if tc.timelimit and tc.time >= tc.timelimit then
				tc.status = "TIMEOUT"
				tc.hlgroup = "CompetiTestWrong"
			else
				tc.status = "KILLED"
				tc.hlgroup = "CompetiTestWarning"
			end
		else
			if tc.exit_signal ~= 0 then
				tc.status = "SIG " .. tc.exit_signal
				tc.hlgroup = "CompetiTestWarning"
			elseif tc.exit_code ~= 0 then
				tc.status = "RET " .. tc.exit_code
				tc.hlgroup = "CompetiTestWarning"
			end -- correct/wrong/done status is computed when stdout is closed
		end

		tc.process.stdin:close()
		tc.process.handle:close()
		if tc.timer and not tc.timer:is_closing() then
			tc.timer:stop()
			tc.timer:close()
		end

		ui.options.update_popups = true
		ui.update_ui(self.tcdata)
		if callback then
			callback()
		end
	end)
	if not process.handle then
		vim.notify(
			"CompetiTest.nvim: TCRunner:execute_testcase: failed to spawn process using '" .. process.exec .. "' (" .. process.pid .. ").",
			vim.log.levels.ERROR
		)
		tc.status = "FAILED"
		tc.hlgroup = "CompetiTestWarning"
		tc.time = -1
		ui.options.update_popups = true
		ui.update_ui(self.tcdata)
		return
	end

	luv.write(process.stdin, tc.stdin)
	tc.stdout = ""
	luv.read_start(process.stdout, function(err, data)
		if err or not data then
			tc.process.stdout:read_stop()
			tc.process.stdout:close()
			if not tc.running and tc.status ~= "RUNNING" then
				return
			end
			local correct = compare.compare_output(tc.stdout, tc.expout, self.config.testcases_compare_method)
			if correct == true then
				tc.status = "CORRECT"
				tc.hlgroup = "CompetiTestCorrect"
			elseif correct == false then
				tc.status = "WRONG"
				tc.hlgroup = "CompetiTestWrong"
			else
				tc.status = "DONE"
				tc.hlgroup = "CompetiTestDone"
			end
			ui.options.update_popups = true
		else
			tc.stdout = tc.stdout .. string.gsub(data, "\r\n", "\n")
			ui.options.update_details = true
		end
		ui.update_ui(self.tcdata)
	end)
	tc.stderr = ""
	luv.read_start(process.stderr, function(err, data)
		if err or not data then
			tc.process.stderr:read_stop()
			tc.process.stderr:close()
			return
		end
		tc.stderr = tc.stderr .. string.gsub(data, "\r\n", "\n")
		ui.options.update_details = true
		ui.update_ui(self.tcdata)
	end)

	if tc.timelimit then
		tc.timer = luv.new_timer()
		tc.timer:start(tc.timelimit, 0, function()
			tc.timer:stop()
			tc.timer:close()
			self:kill_process(tcindex)
		end)
	end

	-- set running data
	tc.time = nil
	process.starting_time = luv.now()
	tc.process = process
	tc.status = "RUNNING"
	tc.hlgroup = "CompetiTestRunning"
	tc.running = true
	tc.killed = false
	ui.options.update_popups = true
	ui.update_ui(self.tcdata)
end

---Kill the process associated with a testcase
---@param tcindex integer: testcase index
function TCRunner:kill_process(tcindex)
	local tc = self.tcdata[tcindex]
	if tc.running ~= true then
		return
	end

	tc.process.stdout:read_stop()
	tc.process.stdout:close()
	tc.process.stderr:read_stop()
	tc.process.stderr:close()
	tc.process.handle:kill("sigkill")
	tc.killed = true
end

---Kill all the running processes associated with testcases
function TCRunner:kill_all_processes()
	for tcindex, _ in pairs(self.tcdata) do
		self:kill_process(tcindex)
	end
end

---Show Runner UI
function TCRunner:show_ui()
	ui.init_ui(self)
	ui.update_ui(self.tcdata)
end

return TCRunner
