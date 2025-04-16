---@alias keymap string keymap left-hand side
---@alias keymaps keymap | keymap[] one or more keymaps

---@module "nui.popup"
---@module "nui.menu"

---Testcase picker UI options
---@class (exact) competitest.Config.picker_ui
---@field width number ratio between picker width and Neovim width (between 0 and 1)
---@field height number ratio between picker height and Neovim height (between 0 and 1)
---@field mappings table<_nui_menu_keymap_action, keymaps>

---Testcase editor UI options
---@class (exact) competitest.Config.editor_ui
---@field popup_width number ratio between single popup width and Neovim width (between 0 and 0.5 because there are two adjacent popups)
---@field popup_height number ratio between popups height and Neovim height (between 0 and 1)
---@field show_nu boolean show lines number
---@field show_rnu boolean show lines relative number
---@field normal_mode_mappings competitest.TestcaseEditorUI.mappings editor UI normal mode mappings
---@field insert_mode_mappings competitest.TestcaseEditorUI.mappings editor UI insert mode mappings

---Runner UI viewer popup, to view in detail a stream (input, expected output, stdout or stderr)
---@class (exact) competitest.Config.runner_ui.viewer
---@field width number ratio between viewer popup width and Neovim width (between 0 and 1)
---@field height number ratio between viewer popup height and Neovim height (between 0 and 1)
---@field show_nu boolean show lines number
---@field show_rnu boolean show lines relative number
---@field close_mappings keymaps mappings to close viewer popup

---Runner UI options
---@class (exact) competitest.Config.runner_ui
---@field interface "popup" | "split" interface type
---@field selector_show_nu boolean show lines number in testcase selector window
---@field selector_show_rnu boolean show lines relative number in testcase selector window
---@field show_nu boolean show lines number in details windows
---@field show_rnu boolean show lines relative number in details windows
---@field mappings table<competitest.RunnerUI.user_action, keymaps>
---@field viewer competitest.Config.runner_ui.viewer

---Runner popup UI options
---@class (exact) competitest.Config.popup_ui
---@field total_width number ratio between total popup UI width and Neovim width (between 0 and 1)
---@field total_height number ratio between total popup UI height and Neovim height (between 0 and 1)
---@field layout competitest.RunnerUI.layout popup UI layout

---Runner split UI options
---@class (exact) competitest.Config.split_ui
---@field position "right" | "left" | "bottom" | "top"
---@field relative_to_editor boolean open split relative to editor or to local window
---@field total_width number ratio between vertical split UI total width and Neovim width (between 0 and 1)
---@field vertical_layout competitest.RunnerUI.layout vertical split UI layout
---@field total_height number ratio between horizontal split UI total height and Neovim height (between 0 and 1)
---@field horizontal_layout competitest.RunnerUI.layout horizontal split UI layout

---CompetiTest configuration
---@class (exact) competitest.Config
---@field local_config_file_name string configuration file name, local to folders
---@field floating_border nui_popup_border_option_style
---@field floating_border_highlight string floating windows border highlight group
---@field picker_ui competitest.Config.picker_ui
---@field editor_ui competitest.Config.editor_ui
---@field runner_ui competitest.Config.runner_ui
---@field popup_ui competitest.Config.popup_ui
---@field split_ui competitest.Config.split_ui
---@field save_current_file boolean save current file before running testcases
---@field save_all_files boolean save all the opened files before running testcases
---@field compile_directory string working directory of compiler, relative to current file path
---@field compile_command { [string]: competitest.SystemCommand } command used to compile code, for each file type
---@field running_directory string working directory of your solutions, relative to current file path
---@field run_command { [string]: competitest.SystemCommand } command used to run your solutions, for each file type
---@field multiple_testing -1 | 0 | integer how many testcases to run at the same time: `0` to run all them together, `-1` to use the amount of available parallelism, or any positive number to run that number of testcases
---@field maximum_time integer maximum execution time (in milliseconds) given to a process: any process exceeding it will be killed
---@field output_compare_method competitest.Compare.builtin_method | competitest.Compare.method how output (stdout) and expected output should be compared: `"exact"` for character-by-character comparison, `"squish"` to compare stripping duplicated or extra white spaces and newlines, custom function accepting strings `output`, `expected_output` and returning `true` if and only if `output` is correct
---@field view_output_diff boolean view diff between output (stdout) and expected output in their respective windows
---@field testcases_use_single_file boolean store testcases in a single file instead of using multiple text files
---@field testcases_auto_detect_storage boolean automatically detect testcases storage method (single or multiple files); if both are present use the one specified in `testcases_use_single_file`
---@field testcases_single_file_format string string with CompetiTest file-format modifiers representing how single testcases files should be named
---@field testcases_input_file_format string string with CompetiTest file-format modifiers representing how testcases input files should be named
---@field testcases_output_file_format string string with CompetiTest file-format modifiers representing how testcases output files should be named
---@field testcases_directory string where testcases files are located, relative to current file path
---@field companion_port integer competitive-companion port
---@field receive_print_message boolean notify user that CompetiTest is ready to receive testcases, problems, contests or that they have just been received
---@field start_receiving_persistently_on_setup boolean start receiving testcases, problems and contests persistently, soon after calling `setup()`
---@field template_file false | string | table<string, string> templates used when creating source files for received problems or contests: `false` to not use templates, string with CompetiTest file-format modifiers or table associating file extension to template file path
---@field evaluate_template_modifiers boolean evaluate CompetiTest receive modifiers inside a template file
---@field date_format string string used to format `$(DATE)` receive modifier, it should follow the formatting rules as per Lua's [`os.date`](https://www.lua.org/pil/22.1.html) function
---@field received_files_extension string default file extension for received problems
---@field received_problems_path string | fun(task: competitest.CCTask, file_extension: string): string path where received problems (not contests) are stored: it can be a string containing CompetiTest receive modifiers or a function accepting two arguments, a table with [task details](https://github.com/jmerle/competitive-companion/#the-format) and the preferred file extension, and returning the absolute path to store received problem
---@field received_problems_prompt_path boolean when receiving a problem ask user confirmation about the path where it will be stored
---@field received_contests_directory string | fun(task: competitest.CCTask, file_extension: string): string directory where received contests are stored: it can be string or function, see `received_problems_path`
---@field received_contests_problems_path string | fun(task: competitest.CCTask, file_extension: string): string relative path from contest root directory for each problem in a received contest: it can be string or function, see `received_problems_path`
---@field received_contests_prompt_directory boolean when receiving a contest ask user confirmation about the directory where it will be stored
---@field received_contests_prompt_extension boolean when receiving a contest ask user confirmation about the file extension to use for source files
---@field open_received_problems boolean automatically open source files when receiving a single problem
---@field open_received_contests boolean automatically open source files when receiving a contest
---@field replace_received_testcases boolean this option only applies when receiving testcases: if `true` replace existing testcases with received ones, otherwise ask user what to do

---Default CompetiTest configuration
---@type competitest.Config
local default_config = {
	local_config_file_name = ".competitest.lua",

	floating_border = "rounded",
	floating_border_highlight = "FloatBorder",
	picker_ui = {
		width = 0.2,
		height = 0.3,
		mappings = {
			focus_next = { "j", "<down>", "<Tab>" },
			focus_prev = { "k", "<up>", "<S-Tab>" },
			close = { "<esc>", "<C-c>", "q", "Q" },
			submit = "<cr>",
		},
	},
	editor_ui = {
		popup_width = 0.4,
		popup_height = 0.6,
		show_nu = true,
		show_rnu = false,
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
	runner_ui = {
		interface = "popup",
		selector_show_nu = false,
		selector_show_rnu = false,
		show_nu = true,
		show_rnu = false,
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
		viewer = {
			width = 0.5,
			height = 0.5,
			show_nu = true,
			show_rnu = false,
			close_mappings = { "q", "Q" },
		},
	},
	popup_ui = {
		total_width = 0.8,
		total_height = 0.8,
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
		position = "right",
		relative_to_editor = true,
		total_width = 0.3,
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
		total_height = 0.4,
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
	compile_directory = ".",
	compile_command = {
		c = { exec = "gcc", args = { "-Wall", "$(FNAME)", "-o", "$(FNOEXT)" } },
		cpp = { exec = "g++", args = { "-Wall", "$(FNAME)", "-o", "$(FNOEXT)" } },
		rust = { exec = "rustc", args = { "$(FNAME)" } },
		java = { exec = "javac", args = { "$(FNAME)" } },
	},
	running_directory = ".",
	run_command = {
		c = { exec = "./$(FNOEXT)" },
		cpp = { exec = "./$(FNOEXT)" },
		rust = { exec = "./$(FNOEXT)" },
		python = { exec = "python", args = { "$(FNAME)" } },
		java = { exec = "java", args = { "$(FNOEXT)" } },
	},
	multiple_testing = -1,
	maximum_time = 5000,
	output_compare_method = "squish",
	view_output_diff = false,

	testcases_use_single_file = false,
	testcases_auto_detect_storage = true,
	testcases_single_file_format = "$(FNOEXT).testcases",
	testcases_input_file_format = "$(FNOEXT)_input$(TCNUM).txt",
	testcases_output_file_format = "$(FNOEXT)_output$(TCNUM).txt",
	testcases_directory = ".",

	companion_port = 27121,
	receive_print_message = true,
	start_receiving_persistently_on_setup = false,
	template_file = false,
	evaluate_template_modifiers = false,
	date_format = "%c",
	received_files_extension = "cpp",
	received_problems_path = "$(CWD)/$(PROBLEM).$(FEXT)",
	received_problems_prompt_path = true,
	received_contests_directory = "$(CWD)",
	received_contests_problems_path = "$(PROBLEM).$(FEXT)",
	received_contests_prompt_directory = true,
	received_contests_prompt_extension = true,
	open_received_problems = true,
	open_received_contests = true,
	replace_received_testcases = false,
}

local M = {}

---Return a configuration updated with given options
---@param cfg_tbl competitest.Config? configuration to be updated
---@param opts competitest.Config? new options
---@return competitest.Config # updated configuration
function M.update_config_table(cfg_tbl, opts)
	if not opts then
		return vim.deepcopy(cfg_tbl or default_config)
	end

	--[[
	-- check deprecated options
	local function notify_warning(msg)
		vim.schedule(function()
			vim.notify("CompetiTest.nvim: " .. msg, vim.log.levels.WARN, { title = "CompetiTest" })
		end)
	end
	]]

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

---CompetiTest configuration after `setup()` is called
---@type competitest.Config
M.current_setup = nil

---Buffer configurations
---@type table<integer, competitest.Config>
M.buffer_configs = {}

---Load local configuration for given directory
---@param directory string
---@return competitest.Config? # local configuration, or `nil` when it's absent or incorrect
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
---@return competitest.Config # local configuration, extended with setup options
function M.load_local_config_and_extend(directory)
	return M.update_config_table(M.current_setup, M.load_local_config(directory))
end

---Load buffer specific configuration and store it in `M.buffer_configs`
---@param bufnr integer
function M.load_buffer_config(bufnr)
	local directory = vim.api.nvim_buf_call(bufnr, function()
		return vim.fn.expand("%:p:h")
	end)
	M.buffer_configs[bufnr] = M.load_local_config_and_extend(directory)
end

---Get buffer configuration
---@param bufnr integer buffer number
---@return competitest.Config # buffer configuration
function M.get_buffer_config(bufnr)
	if not M.buffer_configs[bufnr] then
		M.load_buffer_config(bufnr)
	end
	return M.buffer_configs[bufnr]
end

return M
