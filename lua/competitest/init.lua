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
		total_width = 0.8, -- from 0 to 1, total width of testcases popup and details popups together
		total_height = 0.8, -- from 0 to 1, total height of testcases popup and details popups together
		selector_width = 0.3, -- from 0 to 1, how large should the testcases selector popup be, compared to total_width
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
	multiple_testing = -1, -- how many testcases to run at the same time. Set it to 0 to run all them together, -1 to use the number of available cpu cores, or any positive number to run how many testcases you want
	maximum_time = 5000, -- maximum time (in milliseconds) given to a process. If it's excedeed process will be killed
	output_compare_method = "squish", -- "exact", "squish" or custom function returning true if comparison is valid

	input_name = "input",
	output_name = "output",
	-- $(INOUT) will be substituted with input_name or output_name content
	testcases_files_format = "$(FNOEXT)_$(INOUT)$(TCNUM).txt",
	testcases_use_single_file = false,
	testcases_single_file_format = "$(FNOEXT).testcases",
	testcases_directory = ".", -- where testcases are located, relatively to current file's path

	companion_port = 27121, -- competitive companion port
	receive_print_message = true,
}

---Return an updated configuration table with given options
---@param cfg_tbl table | nil: configuration table to be updated
---@param opts table | nil: table containing new options
---@return table: table with updated configuration
function M.update_config_table(cfg_tbl, opts)
	-- local new_config = vim.deepcopy(cfg_tbl or default_config)
	local new_config = cfg_tbl or default_config

	if opts then
		-- check deprecated options
		if opts.testcases_compare_method then
			opts.output_compare_method = opts.testcases_compare_method
			opts.testcases_compare_method = nil
			vim.defer_fn(function()
				vim.notify(
					"CompetiTest.nvim: option 'testcases_compare_method' has been deprecated in favour of 'output_compare_method'.",
					vim.log.levels.WARN
				)
			end, 1000)
		end
		new_config = vim.tbl_deep_extend("force", new_config, opts)

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
	end
	return new_config
end

---Setup CompetiTest
---@param opts table: a table containing user configuration
function M.setup(opts)
	M.current_setup = M.update_config_table(M.current_setup, opts)

	if not M.current_setup.loaded then
		M.current_setup = vim.tbl_extend("force", M.current_setup, { loaded = true })

		-- CompetiTest commands
		vim.cmd([[
    function! s:convert_command_completion(...) abort
      return "auto\nfiles_to_singlefile\nsinglefile_to_files"
    endfunction

    command! CompetiTestAdd lua require("competitest.commands").edit_testcase(true)
    command! -nargs=? CompetiTestEdit lua require("competitest.commands").edit_testcase(false, <q-args>)
    command! -nargs=? CompetiTestDelete lua require("competitest.commands").delete_testcase(<q-args>)
    command! -nargs=1 -complete=custom,s:convert_command_completion CompetiTestConvert lua require("competitest.commands").convert_testcases(<q-args>)
    command! -nargs=* CompetiTestRun lua require("competitest.commands").run_testcases(<q-args>, true)
    command! -nargs=* CompetiTestRunNC lua require("competitest.commands").run_testcases(<q-args>, false)
    command! CompetiTestRunNE lua require("competitest.runner_ui").show_ui()
    command! CompetiTestReceive lua require("competitest.commands").receive_testcases()
    ]])

		-- create highlight groups
		M.setup_highlight_groups()
		vim.api.nvim_command("autocmd ColorScheme * lua require('competitest').setup_highlight_groups()")

		-- resize ui autocommand
		vim.api.nvim_command("autocmd VimResized * lua require('competitest').resize_ui()")
	end
end

---Resize CompetiTest user interface if visible
function M.resize_ui()
	vim.schedule(function()
		require("competitest.editor").start_ui("resized")
		require("competitest.picker").start_ui("resized")
		require("competitest.runner_ui").init_ui(nil, true)
	end)
end

---Create CompetiTest highlight groups
function M.setup_highlight_groups()
	local highlight_groups = {
		{ "CompetiTestRunning", "cterm=bold gui=bold" },
		{ "CompetiTestDone", "cterm=none gui=none" },
		{ "CompetiTestCorrect", "ctermfg=green guifg=#00ff00" },
		{ "CompetiTestWarning", "ctermfg=yellow guifg=orange" },
		{ "CompetiTestWrong", "ctermfg=red guifg=#ff0000" },
	}
	for _, hl in ipairs(highlight_groups) do
		vim.api.nvim_command("hi! def " .. hl[1] .. " " .. hl[2])
	end
end

return M
