local config = require("competitest.config")
local editor = require("competitest.editor")
local picker = require("competitest.picker")
local runner = require("competitest.runner")
local runner_ui = require("competitest.runner_ui")
local utils = require("competitest.utils")
local M = {}

function M.add_testcase()
	local bufnr = vim.fn.bufnr()
	config.load_buf_config(bufnr)
	local tcnum = utils.get_first_free_testcase(bufnr)
	editor.edit_testcase(bufnr, tcnum, vim.api.nvim_get_current_win(), false)
end

function M.edit_testcase(tcnum)
	local bufnr = vim.fn.bufnr()
	config.load_buf_config(bufnr)
	local winid = vim.api.nvim_get_current_win()

	local function start_editor(item) -- item.id is testcase number
		editor.edit_testcase(bufnr, item.id, winid, true)
	end

	if tcnum then
		start_editor({ id = tcnum })
	else
		picker.pick_testcase("Edit a Testcase", bufnr, start_editor, winid)
	end
end

function M.delete_testcase(tcnum)
	local bufnr = vim.fn.bufnr()
	config.load_buf_config(bufnr)

	local function delete_files(item) -- item.id is testcase number
		local tc = item.id and utils.get_nth_testcase(bufnr, item.id)
		if not tc or not tc.exists then
			vim.notify("CompetiTest.nvim: delete_testcase: testcase " .. (item.id or tcnum) .. " doesn't exist!", vim.log.levels.ERROR)
			return
		end
		local choice = vim.fn.confirm("Are you sure you want to delete Testcase " .. item.id .. "?", "&Yes\n&No")
		if choice == 2 then
			return
		end -- user chose "No"
		if tc.input then
			utils.delete_file(tc.input_file)
		end
		if tc.output then
			utils.delete_file(tc.output_file)
		end
	end

	if tcnum then
		delete_files({ id = tonumber(tcnum) })
	else
		picker.pick_testcase("Remove a Testcase", bufnr, delete_files, vim.api.nvim_get_current_win())
	end
end

function M.run_testcases(testcases, compile)
	local bufnr = vim.fn.bufnr()
	config.load_buf_config(bufnr)
	local tctbl = {}
	if testcases == "" then
		tctbl = utils.get_testcases(vim.fn.bufnr())
	else
		local tclist = vim.split(testcases, " ", { trimempty = true })
		for _, tcnum in ipairs(tclist) do
			tcnum = tonumber(tcnum)
			local tc = utils.get_nth_testcase(bufnr, tcnum, true)
			if not tc.exists then
				vim.notify("CompetiTest.nvim: run_testcases: testcase " .. tcnum .. " doesn't exist!", vim.log.levels.ERROR)
			else
				tctbl[tcnum] = { input = tc.input_file, output = tc.output_file }
			end
		end
	end
	local r = runner:new(vim.fn.bufnr(), vim.api.nvim_get_current_win())
	r:run_testcases(tctbl, compile)
	r:show_ui()
end

function M.show_runner_ui()
	if not runner_ui.options.ui_visible and runner_ui.runner then
		runner_ui.show_ui()
	end
end

return M
