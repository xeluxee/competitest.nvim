local api = vim.api
local luv = vim.loop
local config = require("competitest.config")
local utils = require("competitest.utils")
local ui = require("competitest.runner_ui")

local TCRunner = {}
TCRunner.__index = TCRunner

---Create a new Testcase Runner
---@param bufnr integer: buffer number that specify the buffer to associate the runner with
---@return object: a new TCRunner object, or nil on failure
function TCRunner:new(bufnr)
	local filetype = api.nvim_buf_get_option(bufnr, "filetype")
	local filedir = api.nvim_buf_call(bufnr, function()
		return vim.fn.expand("%:p:h")
	end) .. "/"

	local function eval_command(command)
		if command == nil then
			return nil
		end
		local exec = utils.buf_eval_string(bufnr, command.exec, nil)
		local args = {}
		for index, arg in ipairs(command.args or {}) do
			args[index] = utils.buf_eval_string(bufnr, arg, nil)
		end
		return { exec = exec, args = args }
	end

	local buf_cfg = config.get_buffer_config(bufnr)
	local this = {
		config = buf_cfg,
		bufnr = bufnr,
		cc = eval_command(buf_cfg.compile_command[filetype]), -- compile command
		rc = eval_command(buf_cfg.run_command[filetype]), -- run command
		compile_directory = filedir .. buf_cfg.compile_directory .. "/",
		running_directory = filedir .. buf_cfg.running_directory .. "/",
		testcase_directory = filedir .. buf_cfg.testcases_directory .. "/",
	}
	if this.rc == nil then
		utils.notify("TCRunner:new: run command for filetype '" .. filetype .. "' isn't configured properly.\nCannot proceed.")
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
			table.insert(self.tcdata, { stdin = {}, expout = nil, tcnum = "Compile" })
		end
		for tcnum, tc in pairs(tctbl) do
			table.insert(self.tcdata, {
				stdin = vim.split(tc.input, "\n", { plain = true }),
				-- expout = expected output, can be table or nil
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
		else -- vim.loop.available_parallelism() isn't available in Neovim < 0.7.2
			local cpu_info = luv.cpu_info()
			mut = cpu_info and #cpu_info or 1
		end
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

	utils.create_directory(dir)
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

		self:update_ui(true)
		if callback then
			callback()
		end
	end)
	if not process.handle then
		utils.notify("TCRunner:execute_testcase: failed to spawn process using '" .. process.exec .. "' (" .. process.pid .. ").")
		tc.status = "FAILED"
		tc.hlgroup = "CompetiTestWarning"
		tc.time = -1
		self:update_ui(true)
		return
	end

	---Update array of lines with data received from stdout or stderr
	---@param lines table
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
	self:update_ui(true)
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
	if self.tcdata then
		for tcindex, _ in pairs(self.tcdata) do
			self:kill_process(tcindex)
		end
	end
end

---Show Runner UI
function TCRunner:show_ui()
	if not self.ui then
		self.ui = ui:new(self)
	end
	self.ui:show_ui()
	self.ui:update_ui()
end

---Set or update restore_winid
---@param winid integer: bring the cursor to the given window after runner is closed
function TCRunner:set_restore_winid(winid)
	self.restore_winid = winid
	if self.ui then
		self.ui.restore_winid = winid
	end
end

---Update Runner UI content
---@param update_windows boolean | nil: whether to update all the windows or only details windows
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

---@class StressData
---@field running boolean Whether it is running
---@field passed integer Number of passed tests
---@field failed_seeds table List of failed seeds
---@field current_seed integer Current test seed
---@field outputs table Current test outputs
---@field start_time integer Start time

---Run stress test
---@param self TCRunner
function TCRunner:run_stress_test()
	if self.config.save_all_files then
		api.nvim_command("wa")
	elseif self.config.save_current_file then
		api.nvim_buf_call(self.bufnr, function()
			api.nvim_command("w")
		end)
	end

	-- Clean up normal test data
	self.tcdata = nil

	-- Initialize stress test data
	self.stress_data = {
		running = true,
		passed = 0,
		failed_seeds = {},
		current_seed = nil,
		outputs = {},
		start_time = os.time(),
		error_messages = {},
	}

	-- Show stress test window
	if not self.ui then
		self.ui = ui:new(self)
	end
	self.ui:show_ui()

	-- Check if stress test configuration is complete
	if not self.config.stress then
		table.insert(self.stress_data.error_messages, "Stress test configuration not found")
		self.stress_data.running = false
		self:update_stress_ui()
		return
	end

	if not self.config.stress.generator or not self.config.stress.generator.exec then
		table.insert(self.stress_data.error_messages, "Generator not configured")
		self.stress_data.running = false
		self:update_stress_ui()
		return
	end

	if not self.config.stress.correct or not self.config.stress.correct.exec then
		table.insert(self.stress_data.error_messages, "Correct program not configured")
		self.stress_data.running = false
		self:update_stress_ui()
		return
	end

	if not self.config.stress.solution or not self.config.stress.solution.exec then
		table.insert(self.stress_data.error_messages, "Program under test not configured")
		self.stress_data.running = false
		self:update_stress_ui()
		return
	end

	-- 预处理所有需要的字符串
	local gen_exec = utils.buf_eval_string(self.bufnr, self.config.stress.generator.exec, nil)
	local gen_args = {}
	for _, arg in ipairs(self.config.stress.generator.args or {}) do
		if arg == "$(SEED)" then
			self.stress_data.gen_seed_index = #gen_args + 1
			table.insert(gen_args, "$(SEED)")
		else
			local processed_arg = utils.buf_eval_string(self.bufnr, arg, nil)
			if not processed_arg then
				table.insert(self.stress_data.error_messages, string.format("无法处理生成器参数 '%s'", arg))
				self.stress_data.running = false
				self:update_stress_ui()
				return
			end
			table.insert(gen_args, processed_arg)
		end
	end
	self.stress_data.gen_exec = gen_exec
	self.stress_data.gen_args = gen_args

	local correct_exec = utils.buf_eval_string(self.bufnr, self.config.stress.correct.exec, nil)
	local correct_args = {}
	for _, arg in ipairs(self.config.stress.correct.args or {}) do
		table.insert(correct_args, utils.buf_eval_string(self.bufnr, arg, nil))
	end
	self.stress_data.correct_exec = correct_exec
	self.stress_data.correct_args = correct_args

	local solution_exec = utils.buf_eval_string(self.bufnr, self.config.stress.solution.exec, nil)
	local solution_args = {}
	for _, arg in ipairs(self.config.stress.solution.args or {}) do
		table.insert(solution_args, utils.buf_eval_string(self.bufnr, arg, nil))
	end
	self.stress_data.solution_exec = solution_exec
	self.stress_data.solution_args = solution_args

	-- 编译当前程序
	if self.cc then
		-- 直接执行编译命令，不创建 tcdata
		self:execute_testcase_without_ui(self.cc.exec, self.cc.args, self.compile_directory, function(success)
			if success then
				self:start_stress_test()
			else
				table.insert(self.stress_data.error_messages, "编译失败")
				self.stress_data.running = false
				self:update_stress_ui()
			end
		end)
	else
		self:start_stress_test()
	end
end

---执行命令但不显示界面
---@param exec string 可执行文件
---@param args table 参数列表
---@param dir string 工作目录
---@param callback function 回调函数
function TCRunner:execute_testcase_without_ui(exec, args, dir, callback)
	local process = {
		exec = exec,
		args = args,
		stdin = luv.new_pipe(false),
		stdout = luv.new_pipe(false),
		stderr = luv.new_pipe(false),
	}

	utils.create_directory(dir)
	process.handle, process.pid = luv.spawn(process.exec, {
		args = process.args,
		cwd = dir,
		stdio = { process.stdin, process.stdout, process.stderr },
	}, function(code, signal)
		process.stdin:close()
		process.stdout:close()
		process.stderr:close()
		process.handle:close()
		callback(code == 0)
	end)

	if not process.handle then
		callback(false)
		return
	end

	luv.shutdown(process.stdin)
end

---执行对拍进程
---@param self TCRunner
---@param name string 进程名称
---@param exec string 可执行文件
---@param args table 参数列表
---@param callback function 回调函数
function TCRunner:execute_stress_process(name, exec, args, callback)
	local stdout = luv.new_pipe(false)
	local stderr = luv.new_pipe(false)
	local handle
	local timer

	local function on_exit(code, signal)
		if timer then
			timer:stop()
			timer:close()
		end
		if handle then
			handle:close()
		end
		if stdout then
			stdout:close()
		end
		if stderr then
			stderr:close()
		end

		self.stress_data.outputs[name] = {
			stdout = self.stress_data.outputs[name].stdout,
			stderr = self.stress_data.outputs[name].stderr,
			exit_code = code,
			signal = signal,
		}

		callback(code == 0)
	end

	-- 初始化输出缓冲区
	self.stress_data.outputs[name] = {
		stdout = {},
		stderr = {},
	}

	-- 检查可执行文件是否存在
	if not utils.does_file_exist(exec) then
		self.stress_data.outputs[name] = {
			stdout = {},
			stderr = {},
			exit_code = -1,
			signal = 0,
		}
		callback(false)
		return
	end

	handle = luv.spawn(exec, {
		args = args,
		cwd = self.running_directory,
		stdio = { nil, stdout, stderr }
	}, on_exit)

	if not handle then
		self.stress_data.outputs[name] = {
			stdout = {},
			stderr = { "无法启动进程" },
			exit_code = -1,
			signal = 0,
		}
		callback(false)
		return
	end

	luv.read_start(stdout, function(err, data)
		if err then
			table.insert(self.stress_data.outputs[name].stderr, "stdout 读取错误")
			return
		end
		if data then
			table.insert(self.stress_data.outputs[name].stdout, data)
		end
	end)

	luv.read_start(stderr, function(err, data)
		if err then
			table.insert(self.stress_data.outputs[name].stderr, "stderr 读取错误")
			return
		end
		if data then
			table.insert(self.stress_data.outputs[name].stderr, data)
		end
	end)

	timer = luv.new_timer()
	timer:start(self.config.stress.time_limit, 0, function()
		if handle then
			table.insert(self.stress_data.outputs[name].stderr, "进程超时")
			handle:kill(9)
		end
	end)
end

---Start stress test
---@param self TCRunner
function TCRunner:start_stress_test()
	local function generate_seed()
		return math.random(self.config.stress.seed_range[1], self.config.stress.seed_range[2])
	end

	local function run_stress_iteration()
		if not self.stress_data.running then
			return
		end

		local seed = generate_seed()
		self.stress_data.current_seed = seed
		self.stress_data.outputs = {}

		-- Replace seed in generator arguments
		local gen_args = vim.deepcopy(self.stress_data.gen_args)
		if self.stress_data.gen_seed_index then
			gen_args[self.stress_data.gen_seed_index] = tostring(seed)
		end

		-- Run generator
		self:execute_stress_process("generator", self.stress_data.gen_exec, gen_args, function(success)
			if not success then
				vim.schedule(function()
					utils.notify("Generator failed to run")
					utils.notify(string.format("Generator path: %s", self.stress_data.gen_exec))
					utils.notify(string.format("Generator arguments: %s", table.concat(gen_args, " ")))
					utils.notify(string.format("Working directory: %s", self.running_directory))
					if #self.stress_data.outputs.generator.stderr > 0 then
						for _, line in ipairs(self.stress_data.outputs.generator.stderr) do
							if line and line ~= "" then
								utils.notify(string.format("Generator error output: %s", line))
							end
						end
					end
				end)
				return
			end

			-- Run correct program
			self:execute_stress_process("correct", self.stress_data.correct_exec, self.stress_data.correct_args, function(success)
				if not success then
					vim.schedule(function()
						utils.notify("Correct program failed to run")
						utils.notify(string.format("Correct program path: %s", self.stress_data.correct_exec))
						utils.notify(string.format("Correct program arguments: %s", table.concat(self.stress_data.correct_args, " ")))
						utils.notify(string.format("Working directory: %s", self.running_directory))
						if #self.stress_data.outputs.correct.stderr > 0 then
							for _, line in ipairs(self.stress_data.outputs.correct.stderr) do
								if line and line ~= "" then
									utils.notify(string.format("Correct program error output: %s", line))
								end
							end
						end
					end)
					return
				end

				-- Run program under test
				self:execute_stress_process("solution", self.stress_data.solution_exec, self.stress_data.solution_args, function(success)
					if not success then
						vim.schedule(function()
							local error_messages = {
								"Program under test failed to run",
								string.format("Program under test path: %s", self.stress_data.solution_exec),
								string.format("Program under test arguments: %s", table.concat(self.stress_data.solution_args, " ")),
								string.format("Working directory: %s", self.running_directory),
							}
							if #self.stress_data.outputs.solution.stderr > 0 then
								for _, line in ipairs(self.stress_data.outputs.solution.stderr) do
									if line and line ~= "" then
										table.insert(error_messages, string.format("Error output: %s", line))
									end
								end
							end
							for _, msg in ipairs(error_messages) do
								utils.notify(msg)
							end
						end)
						return
					end

					-- Compare outputs
					local correct_output = table.concat(self.stress_data.outputs.correct.stdout or {}, "\n")
					local solution_output = table.concat(self.stress_data.outputs.solution.stdout or {}, "\n")

					if correct_output ~= solution_output then
						table.insert(self.stress_data.failed_seeds, seed)
						self.stress_data.running = false
						vim.schedule(function()
							local error_messages = {
								string.format("Stress test failed: seed %d", seed),
								"",
								"Generator output:",
							}
							for _, line in ipairs(self.stress_data.outputs.generator.stdout) do
								if line and line ~= "" then
									table.insert(error_messages, string.format("  %s", line))
								end
							end
							table.insert(error_messages, "")
							table.insert(error_messages, "Correct program output:")
							for _, line in ipairs(self.stress_data.outputs.correct.stdout) do
								if line and line ~= "" then
									table.insert(error_messages, string.format("  %s", line))
								end
							end
							table.insert(error_messages, "")
							table.insert(error_messages, "Solution output:")
							for _, line in ipairs(self.stress_data.outputs.solution.stdout) do
								if line and line ~= "" then
									table.insert(error_messages, string.format("  %s", line))
								end
							end
							for _, msg in ipairs(error_messages) do
								utils.notify(msg)
							end
						end)
						self:update_stress_ui()
					else
						self.stress_data.passed = self.stress_data.passed + 1
						self:update_stress_ui()
						if self.config.stress.auto_continue then
							vim.defer_fn(run_stress_iteration, 0)
						end
					end
				end)
			end)
		end)
	end

	math.randomseed(os.time())
	self.stress_data.running = true
	run_stress_iteration()
end

---Update stress test UI
---@param self TCRunner
function TCRunner:update_stress_ui()
	if not self.ui then return end
	self.ui:update_stress_view(self.stress_data)
end

return TCRunner
