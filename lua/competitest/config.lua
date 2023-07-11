local M = {}

local default_config = {
	local_config_file_name = ".competitest.lua", -- configuration file name, local to folders

	floating_border = "rounded",
	floating_border_highlight = "FloatBorder",
	picker_ui = {
		width = 0.2, -- from 0 to 1
		height = 0.3, -- from 0 to 1
		mappings = {
			focus_next = { "j", "<down>", "<Tab>" },
			focus_prev = { "k", "<up>", "<S-Tab>" },
			close = { "<esc>", "<C-c>", "q", "Q" },
			submit = { "<cr>" },
		},
	},
	editor_ui = { -- user interface used by CompetiTestAdd and CompetiTestEdit
		popup_width = 0.4, -- from 0 to 0.5, because there are two popups
		popup_height = 0.6, -- from 0 to 1
		show_nu = true, -- show line number
		show_rnu = false, -- show relative line number
		normal_mode_mappings = {
			switch_window = { "<C-h>", "<C-l>", "<C-i>" },
			save_and_close = "<C-s>",
			cancel = { "q", "Q" },
		},
		insert_mode_mappings = {
			switch_window = { "<C-h>", "<C-l>", "<C-i>" },
			save_and_close = "<C-s>",
			cancel = "<C-q>",
		},
	},
	runner_ui = { -- user interface used by CompetiTestRun
		interface = "popup", -- interface type, can be 'popup' or 'split'
		selector_show_nu = false, -- show line number in testcase selector window
		selector_show_rnu = false, -- show relative line number in testcase selector window
		show_nu = true, -- show line number in details popups
		show_rnu = false, -- show relative line number in details popups
		mappings = {
			run_again = "R",
			run_all_again = "<C-r>",
			kill = "K",
			kill_all = "<C-k>",
			view_input = { "i", "I" },
			view_output = { "a", "A" },
			view_stdout = { "o", "O" },
			view_stderr = { "e", "E" },
			toggle_diff = { "d", "D" },
			close = { "q", "Q" },
		},
		viewer = { -- viewer window, to view in detail a stream (input, expected output, stdout or stderr)
			width = 0.5, -- from 0 to 1
			height = 0.5, -- from 0 to 1
			show_nu = true, -- show line number
			show_rnu = false, -- show relative line number
			close_mappings = { "q", "Q" },
		},
	},
	popup_ui = {
		total_width = 0.8, -- from 0 to 1, total width of popup ui
		total_height = 0.8, -- from 0 to 1, total height of popup ui
		layout = {
			{ 3, "tc" },
			{ 4, {
				{ 1, "so" },
				{ 1, "si" },
			} },
			{ 4, {
				{ 1, "eo" },
				{ 1, "se" },
			} },
		},
	},
	split_ui = {
		position = "right", -- top, right, left, bottom
		relative_to_editor = true, -- open split relative to editor or to local window
		total_width = 0.3, -- from 0 to 1, total width of vertical split
		vertical_layout = {
			{ 1, "tc" },
			{ 1, {
				{ 1, "so" },
				{ 1, "eo" },
			} },
			{ 1, {
				{ 1, "si" },
				{ 1, "se" },
			} },
		},
		total_height = 0.4, -- from 0 to 1, total height of horizontal split
		horizontal_layout = {
			{ 2, "tc" },
			{ 3, {
				{ 1, "so" },
				{ 1, "si" },
			} },
			{ 3, {
				{ 1, "eo" },
				{ 1, "se" },
			} },
		},
	},

	save_current_file = true,
	save_all_files = false,
	compile_directory = ".", -- working directory of compile_command, relatively to current file's path
	compile_command = {
		c = { exec = "gcc", args = { "-Wall", "$(FNAME)", "-o", "$(FNOEXT)" } },
		cpp = { exec = "g++", args = { "-Wall", "$(FNAME)", "-o", "$(FNOEXT)" } },
		rust = { exec = "rustc", args = { "$(FNAME)" } },
		java = { exec = "javac", args = { "$(FNAME)" } },
	},
	running_directory = ".", -- working directory of run_command, relatively to current file's path
	run_command = {
		c = { exec = "./$(FNOEXT)" },
		cpp = { exec = "./$(FNOEXT)" },
		rust = { exec = "./$(FNOEXT)" },
		python = { exec = "python", args = { "$(FNAME)" } },
		java = { exec = "java", args = { "$(FNOEXT)" } },
	},
	multiple_testing = -1, -- how many testcases to run at the same time. Set it to 0 to run all them together, -1 to use amount of available parallelism, or any positive number to run how many testcases you want
	maximum_time = 5000, -- maximum time (in milliseconds) given to a process. If it's excedeed process will be killed
	output_compare_method = "squish", -- "exact", "squish" or custom function returning true if comparison is valid
	view_output_diff = false, -- view diff between standard output and expected output in their respective windows

	testcases_use_single_file = false,
	testcases_auto_detect_storage = true, -- if true auto detect storage method (single or multiple files). If both are present use the one specified in testcases_use_single_file
	testcases_single_file_format = "$(FNOEXT).testcases",
	testcases_input_file_format = "$(FNOEXT)_input$(TCNUM).txt",
	testcases_output_file_format = "$(FNOEXT)_output$(TCNUM).txt",
	testcases_directory = ".", -- where testcases are located, relatively to current file's path

	companion_port = 27121, -- competitive companion port
	receive_print_message = true,
	template_file = false,
	received_problems_directory = false, -- whether to use flexible or fixed directories for received problems, it can be false, string or function
	received_contests_directory = false,
	open_received_problems = true,
	open_received_contests = true,
}

---Return an updated configuration table with given options
---@param cfg_tbl table | nil: configuration table to be updated
---@param opts table | nil: table containing new options
---@return table: table with updated configuration
function M.update_config_table(cfg_tbl, opts)
	if not opts then
		return vim.deepcopy(cfg_tbl or default_config)
	end

	local function notify_warning(msg)
		vim.schedule(function()
			vim.notify("CompetiTest.nvim: " .. msg, vim.log.levels.WARN, { title = "CompetiTest" })
		end)
	end

	-- check deprecated testcases options
	if opts.testcases_files_format then
		opts.testcases_input_file_format = string.gsub(opts.testcases_files_format, "%$%(INOUT%)", opts.input_name or "input")
		opts.testcases_output_file_format = string.gsub(opts.testcases_files_format, "%$%(INOUT%)", opts.output_name or "output")
		opts.testcases_files_format = nil
		notify_warning(
			"option 'testcases_files_format' has been deprecated in favour of 'testcases_input_file_format' and 'testcases_output_file_format'."
		)
	end
	if opts.input_name then
		opts.input_name = nil
		notify_warning("option 'input_name' has been deprecated. See 'testcases_input_file_format'.")
	end
	if opts.output_name then
		opts.output_name = nil
		notify_warning("option 'output_name' has been deprecated. See 'testcases_output_file_format'.")
	end
	-- check deprecated ui options
	if opts.runner_ui then
		for _, option in ipairs({ "total_width", "total_height" }) do
			if opts.runner_ui[option] then
				opts.popup_ui = opts.popup_ui or {}
				opts.popup_ui[option] = opts.runner_ui[option]
				opts.runner_ui[option] = nil
				notify_warning("option 'runner_ui." .. option .. "' has been deprecated in favour of 'popup_ui." .. option .. "'.")
			end
		end
		if opts.runner_ui.selector_width then
			opts.runner_ui.selector_width = nil
			notify_warning("option 'runner_ui.selector_width' has been deprecated. See 'popup_ui.layout'.")
		end
	end

	local new_config = vim.tbl_deep_extend("force", cfg_tbl or default_config, opts)
	-- commands arguments lists need to be replaced and not extended
	for lang, cmd in pairs(opts.compile_command or {}) do
		if cmd.args then
			new_config.compile_command[lang].args = cmd.args
		end
	end
	for lang, cmd in pairs(opts.run_command or {}) do
		if cmd.args then
			new_config.run_command[lang].args = cmd.args
		end
	end
	return new_config
end

-- CompetiTest configuration after setup() is called
M.current_setup = nil

-- Table to store buffer configs
M.buffer_configs = {}

---Load local configuration for given directory
---@param directory string
---@return table | nil: table containing local configuration, or nil when it's absent or incorrect
function M.load_local_config(directory)
	local utils = require("competitest.utils")
	local prev_len
	while prev_len ~= #directory do
		prev_len = #directory
		local config_file = directory .. "/" .. M.current_setup.local_config_file_name
		if utils.does_file_exist(config_file) then
			local local_config = dofile(config_file)
			if type(local_config) ~= "table" then
				utils.notify("load_buffer_config: '" .. config_file .. "' doesn't return a table.")
				return nil
			end
			return local_config
		end
		directory = vim.fn.fnamemodify(directory, ":h")
	end
end

---Load local configuration for given directory, extending it with setup options
---@param directory string
---@return table: table containing local configuration, extended with setup options
function M.load_local_config_and_extend(directory)
	return M.update_config_table(M.current_setup, M.load_local_config(directory))
end

---Load buffer specific configuration and store it in M.buffer_configs
---@param bufnr integer
function M.load_buffer_config(bufnr)
	local directory = vim.api.nvim_buf_call(bufnr, function()
		return vim.fn.expand("%:p:h")
	end)
	M.buffer_configs[bufnr] = M.load_local_config_and_extend(directory)
end

---Get buffer configuration
---@param bufnr integer: buffer number
---@return table: table containing buffer configuration
function M.get_buffer_config(bufnr)
	if not M.buffer_configs[bufnr] then
		M.load_buffer_config(bufnr)
	end
	return M.buffer_configs[bufnr]
end

return M
