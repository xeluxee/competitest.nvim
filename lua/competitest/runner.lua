local api = vim.api
local luv = vim.uv and vim.uv or vim.loop
local utils = require("competitest.utils")

---System command with arguments
---@class (exact) competitest.SystemCommand
---@field exec string executable path
---@field args string[]? program arguments

---Running testcase process status
---@class (exact) competitest.TCRunner.testcase_status.process
---@field stdin uv.uv_pipe_t
---@field stdout uv.uv_pipe_t
---@field stderr uv.uv_pipe_t
---@field handle uv.uv_process_t
---@field pid integer
---@field starting_time integer

---Running testcase status, data and results
---@class (exact) competitest.TCRunner.testcase_status
---@field stdin string[] stdin lines
---@field expout string[]? expected output lines
---@field stdout string[] stdout lines
---@field stderr string[] stderr lines
---@field tcnum integer | "Compile" testcase number or identifier
---@field status "" | "RUNNING" | "TIMEOUT" | "KILLED" | "SIG x" | "RET x" | "FAILED" | "CORRECT" | "WRONG" | "DONE"
---@field hlgroup string testcase status highlight group
---@field timelimit integer? maximum execution time in milliseconds, or `nil` if there's no time limit
---@field timer uv.uv_timer_t? process is killed when `timer` expires, `nil` if and only if `timelimit` is `nil`
---@field time integer? testcase running time in milliseconds, `nil` if process isn't started or is running
---@field process competitest.TCRunner.testcase_status.process
---@field running boolean
---@field killed boolean
---@field exit_code integer?
---@field exit_signal integer?

---Testcases Runner
---@class (exact) competitest.TCRunner
---@field config competitest.Config buffer configuration
---@field private bufnr integer associated buffer
---@field private cc competitest.SystemCommand? compile command, or `nil` for interpreted languages
---@field private rc competitest.SystemCommand run command
---@field private compile_directory string
---@field private running_directory string
---@field tcdata table<integer, competitest.TCRunner.testcase_status> testcases status, data and results
---@field private compile boolean whether compilation is needed in the current run or not
---@field private next_tc integer index of next unprocessed testcase to run
---@field ui_restore_winid integer? bring the cursor to the given window when testcases runner UI is closed
---@field private ui competitest.RunnerUI?
local TCRunner = {}
TCRunner.__index = TCRunner ---@diagnostic disable-line: inject-field

---Create a new `TCRunner`
---@param bufnr integer buffer to associate the runner with
---@return competitest.TCRunner? # a new `TCRunner`, or `nil` on failure
function TCRunner:new(bufnr)
	local filetype = vim.bo[bufnr].filetype
	local filedir = api.nvim_buf_call(bufnr, function()
		return vim.fn.expand("%:p:h")
	end) .. "/"

	---Evaluate CompetiTest file-format modifiers inside a system command
	---@param command competitest.SystemCommand
	---@return competitest.SystemCommand?
	local function eval_command(command)
		local exec = utils.buf_eval_string(bufnr, command.exec, nil)
		if not exec then
			return nil
		end
		---@type string[]
		local args = {}
		for index, arg in ipairs(command.args or {}) do
			args[index] = utils.buf_eval_string(bufnr, arg, nil)
			if not args[index] then
				return nil
			end
		end
		return { exec = exec, args = args }
	end

	local buf_cfg = require("competitest.config").get_buffer_config(bufnr)
	local compile_command = nil
	if buf_cfg.compile_command[filetype] then
		compile_command = eval_command(buf_cfg.compile_command[filetype])
		if not compile_command then
			utils.notify("TCRunner:new: compile command for filetype '" .. filetype .. "' isn't formatted properly.\nCannot proceed.")
			return nil
		end
	end
	if not buf_cfg.run_command[filetype] then
		utils.notify("TCRunner:new: run command for filetype '" .. filetype .. "' isn't configured properly.\nCannot proceed.")
		return nil
	end
	local run_command = eval_command(buf_cfg.run_command[filetype])
	if not run_command then
		utils.notify("TCRunner:new: run command for filetype '" .. filetype .. "' isn't formatted properly.\nCannot proceed.")
		return nil
	end

	---@type competitest.TCRunner
	local this = {
		config = buf_cfg,
		bufnr = bufnr,
		cc = compile_command,
		rc = run_command,
		compile_directory = filedir .. buf_cfg.compile_directory .. "/",
		running_directory = filedir .. buf_cfg.running_directory .. "/",
		tcdata = {},
		compile = compile_command ~= nil,
		next_tc = 1,
	}
	setmetatable(this, self)
	return this
end

---Run the `tcindex`-th testcase
---@param tcindex integer testcase index in `self.tcdata`
function TCRunner:run_testcase(tcindex)
	if tcindex == 1 and self.compile then
		self:execute_testcase(tcindex, self.cc, self.compile_directory)
	else
		self:execute_testcase(tcindex, self.rc, self.running_directory)
	end
end

---@private
---Run the next unprocessed testcase, if any, and when it finishes run the successive unprocessed testcase, if any
function TCRunner:run_next_testcase()
	if self.next_tc > #self.tcdata then
		return
	end
	self.next_tc = self.next_tc + 1
	self:execute_testcase(self.next_tc - 1, self.rc, self.running_directory, function()
		self:run_next_testcase()
	end)
end

---Run new testcases or previously loaded ones
---@param tctbl competitest.TcTable? testcases to run, or `nil` to run previously loaded testcases
---@param compile boolean? whether to compile or not, `nil` has the same effect as `true`
function TCRunner:run_testcases(tctbl, compile)
	if tctbl then -- if tctbl isn't specified use the testcases that were previously loaded
		if self.config.save_all_files then
			api.nvim_command("wa")
		elseif self.config.save_current_file then
			api.nvim_buf_call(self.bufnr, function()
				api.nvim_command("w")
			end)
		end

		self.tcdata = {}
		if compile == nil then -- if not specified compile
			compile = true
		end
		self.compile = compile and self.cc ~= nil
		if self.compile then -- if compilation is needed we add it as a testcase
			table.insert(self.tcdata, { stdin = {}, expout = nil, tcnum = "Compile" })
		end
		for tcnum, tc in pairs(tctbl) do
			table.insert(self.tcdata, {
				stdin = vim.split(tc.input, "\n", { plain = true }),
				expout = tc.output and vim.split(tc.output, "\n", { plain = true }),
				tcnum = tcnum,
				timelimit = self.config.maximum_time,
			})
		end
	end

	-- reset running data
	for _, tc in pairs(self.tcdata) do
		tc.status = ""
		tc.hlgroup = "CompetiTestRunning"
		tc.stdout = nil
		tc.stderr = nil
		tc.running = false
		tc.killed = false
		tc.time = nil
	end

	local tc_size = #self.tcdata -- how many testcases
	local mut = self.config.multiple_testing -- multiple testing, how many testcases to run at the same time
	if mut == -1 then -- -1 -> make the most of the amount of available parallelism
		if luv.available_parallelism then
			mut = luv.available_parallelism()
		else -- luv.available_parallelism() isn't available in Neovim < 0.7.2
			local cpu_info = luv.cpu_info()
			mut = cpu_info and #cpu_info or 1
		end
	elseif mut == 0 then -- 0 -> run all testcases together
		mut = tc_size
	end
	mut = math.min(tc_size, mut)
	self.next_tc = 1

	local function rmdir(dir)
		local d = luv.fs_opendir(dir)
		if d then
			while true do
				local content = luv.fs_readdir(d, nil, 1)
				if not content then
					break
				end
				for _, entry in ipairs(content) do
					if entry.name ~= "." or entry.name ~= ".." then
						local path = dir .. "/" .. entry.name
						if entry.type == 'directory' then
							rmdir(path)
						elseif entry.type == 'file' then
							luv.fs_unlink(path)
						end
					end
				end
			end
			luv.fs_closedir(d)
		end
		luv.fs_rmdir(dir)
	end

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
			local sep = vim.fn.has("win32") and "\\" or "/"
			local rc_exec = self.running_directory .. sep .. self.rc.exec
			if self.compile and self.config.remove_compiled_binary and vim.fn.filereadable(rc_exec) then
				os.remove(rc_exec)
				if vim.fn.has("mac") then
					local dsym = rc_exec .. ".dSYM"
					if vim.fn.isdirectory(dsym) then
						rmdir(dsym)
					end
				end
			end
			return
		end
		next_tc = next_tc + 1
		self:execute_testcase(next_tc - 1, self.rc.exec, self.rc.args, self.running_directory, self.run_next_tc)
	end

	local function run_first_testcases()
		local starting_tc = self.next_tc
		self.next_tc = self.next_tc + mut
		for tcnum = starting_tc, math.min(tc_size, starting_tc + mut - 1) do
			self:execute_testcase(tcnum, self.rc, self.running_directory, function()
				self:run_next_testcase()
			end)
		end
	end

	if not self.compile then
		run_first_testcases()
	else
		self.next_tc = 2
		local function compilation_callback()
			if self.tcdata[1].exit_code == 0 then
				run_first_testcases()
			end
		end
		self:execute_testcase(1, self.cc, self.compile_directory, compilation_callback)
	end
end

---@private
---Start a testcase process with given parameters
---@param tcindex integer testcase index in `self.tcdata`
---@param cmd competitest.SystemCommand command to run testcase
---@param dir string current working directory
---@param callback fun()? callback function
function TCRunner:execute_testcase(tcindex, cmd, dir, callback)
	---@type competitest.TCRunner.testcase_status.process
	---@diagnostic disable-next-line: missing-fields
	local process = {
		stdin = assert(luv.new_pipe(false), "CompetiTest.nvim: TCRunner:execute_testcase: process stdin pipe creation failed"),
		stdout = assert(luv.new_pipe(false), "CompetiTest.nvim: TCRunner:execute_testcase: process stdout pipe creation failed"),
		stderr = assert(luv.new_pipe(false), "CompetiTest.nvim: TCRunner:execute_testcase: process stderr pipe creation failed"),
	}
	local tc = self.tcdata[tcindex]

	utils.create_directory(dir)
	---@diagnostic disable-next-line: missing-fields
	process.handle, process.pid = luv.spawn(cmd.exec, {
		args = cmd.args,
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

		self:update_ui(true)
		if callback then
			callback()
		end
	end)
	if not process.handle then
		utils.notify("TCRunner:execute_testcase: failed to spawn process using '" .. cmd.exec .. "' (" .. process.pid .. ").")
		tc.status = "FAILED"
		tc.hlgroup = "CompetiTestWarning"
		tc.time = -1
		self:update_ui(true)
		return
	end

	---Update array of lines with data received from stdout or stderr
	---@param lines string[]
	---@param received string
	local function add_stream_lines(lines, received)
		local received_lines = vim.split(string.gsub(received, "\r\n", "\n"), "\n", { plain = true })
		local n = #lines
		for _, line in ipairs(received_lines) do
			lines[n] = (lines[n] or "") .. line
			n = n + 1
		end
	end

	luv.write(process.stdin, table.concat(tc.stdin, "\n"))
	luv.shutdown(process.stdin)
	tc.stdout = { "" }
	luv.read_start(process.stdout, function(err, data)
		if err or not data then
			tc.process.stdout:read_stop()
			tc.process.stdout:close()
			if not tc.running and tc.status ~= "RUNNING" then
				return
			end
			local correct = require("competitest.compare").compare_output(
				table.concat(tc.stdout, "\n"),
				tc.expout and table.concat(tc.expout, "\n"),
				self.config.output_compare_method
			)
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
			self:update_ui(true)
		else
			add_stream_lines(tc.stdout, data)
			self:update_ui()
		end
	end)
	tc.stderr = { "" }
	luv.read_start(process.stderr, function(err, data)
		if err or not data then
			tc.process.stderr:read_stop()
			tc.process.stderr:close()
			return
		end
		add_stream_lines(tc.stderr, data)
		self:update_ui()
	end)

	if tc.timelimit then
		tc.timer = assert(luv.new_timer(), "CompetiTest.nvim: TCRunner:execute_testcase: timer creation failed")
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
	tc.exit_code = nil
	tc.exit_signal = nil
	self:update_ui(true)
end

---Kill the process associated with a testcase, triggering the execution of the next unprocessed testcase, if any
---@param tcindex integer testcase index in `self.tcdata`
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

---Kill all the running processes associated with testcases, triggering the execution of the next unprocessed testcases, if any
function TCRunner:kill_all_processes()
	if self.tcdata then
		for tcindex, _ in pairs(self.tcdata) do
			self:kill_process(tcindex)
		end
	end
end

---Show Runner UI
function TCRunner:show_ui()
	if not self.tcdata then -- nothing to show
		return
	end
	if not self.ui then
		self.ui = require("competitest.runner_ui"):new(self)
	end
	self.ui:show_ui()
	self.ui:update_ui()
end

---Set or update `restore_winid`
---@param restore_winid integer bring the cursor to the given window after runner is closed
function TCRunner:set_restore_winid(restore_winid)
	self.ui_restore_winid = restore_winid
	if self.ui then
		self.ui.restore_winid = restore_winid
	end
end

---@private
---Update Runner UI content
---@param update_windows boolean? whether to update all the windows or details window only, `nil` has the same effect as `false`
function TCRunner:update_ui(update_windows)
	if self.ui then
		if update_windows then -- avoid direct assignment to satisfy unprocessed previous update_windows requests
			self.ui.update_windows = true
		end
		self.ui.update_details = true
		self.ui:update_ui()
	end
end

function TCRunner:resize_ui()
	if self.ui then
		self.ui:resize_ui()
	end
end

return TCRunner
