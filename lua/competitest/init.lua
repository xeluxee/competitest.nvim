local config = require("competitest.config")
local M = {}

---Setup CompetiTest
---@param opts table: a table containing user configuration
function M.setup(opts)
	config.current_setup = config.update_config_table(config.current_setup, opts)

	if not config.current_setup.loaded then
		config.current_setup.loaded = true

		-- CompetiTest commands
		vim.cmd([[
		function! s:convert_command_completion(...) abort
			return "auto\nfiles_to_singlefile\nsinglefile_to_files"
		endfunction
		function! s:receive_command_completion(...) abort
			return "testcases\nproblem\ncontest"
		endfunction

		command! -bar CompetiTestAdd lua require("competitest.commands").edit_testcase(true)
		command! -bar -nargs=? CompetiTestEdit lua require("competitest.commands").edit_testcase(false, <q-args>)
		command! -bar -nargs=? CompetiTestDelete lua require("competitest.commands").delete_testcase(<q-args>)
		command! -bar -nargs=1 -complete=custom,s:convert_command_completion CompetiTestConvert lua require("competitest.commands").convert_testcases(<q-args>)
		command! -bar -nargs=* CompetiTestRun lua require("competitest.commands").run_testcases(<q-args>, true)
		command! -bar -nargs=* CompetiTestRunNC lua require("competitest.commands").run_testcases(<q-args>, false)
		command! -bar CompetiTestRunNE lua require("competitest.commands").run_testcases(<q-args>, false, true)
		command! -bar -nargs=1 -complete=custom,s:receive_command_completion CompetiTestReceive lua require("competitest.commands").receive(<q-args>)
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
		require("competitest.widgets").resize_widgets()
		for _, r in pairs(require("competitest.commands").runners) do
			r:resize_ui()
		end
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
