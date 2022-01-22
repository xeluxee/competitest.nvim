local api = vim.api
local nui_popup = require("nui.popup")
local nui_event = require("nui.utils.autocmd").event
local M = {}

M.popups = {}
M.options = {}
M.tcdata = {}

function M.compute_layout()
	local vim_width, vim_height = require("competitest.utils").get_ui_size()

	local total_width = math.floor(vim_width * M.runner.config.runner_ui.total_width)
	local total_height = math.floor(vim_height * M.runner.config.runner_ui.total_height)
	if total_height % 2 == 1 then
		total_height = total_height + 1
	end
	local testcases_popup_width = math.floor(total_width * M.runner.config.runner_ui.selector_width)
	local details_popups_width = math.floor((total_width - testcases_popup_width) / 2)

	local sizes = {}
	-- selector popup
	sizes[1] = {
		width = testcases_popup_width,
		height = total_height,
	}
	-- details popups
	sizes[2] = {
		width = details_popups_width,
		height = total_height / 2 - 1,
	}
	-- viewer popup
	sizes[3] = {
		width = math.floor(vim_width * M.runner.config.runner_ui.viewer.width),
		height = math.floor(vim_height * M.runner.config.runner_ui.viewer.height),
	}

	local positions = {}
	-- selector popup
	positions[1] = {
		row = math.floor((vim_height - total_height) / 2) - 1,
		col = math.floor((vim_width - total_width) / 2) - 3,
	}
	-- stdout popup
	positions[2] = {
		row = positions[1].row,
		col = positions[1].col + testcases_popup_width + 2,
	}
	-- expected output popup
	positions[3] = {
		row = positions[1].row,
		col = positions[2].col + details_popups_width + 2,
	}
	-- input popup
	positions[4] = {
		row = positions[1].row + total_height / 2 + 1,
		col = positions[2].col,
	}
	-- stderr popup
	positions[5] = {
		row = positions[4].row,
		col = positions[3].col,
	}
	-- viewer popup
	positions[6] = "50%"

	return sizes, positions
end

function M.init_ui(self, resized)
	local was_viewer_visible = M.options.viewer_visible
	if resized then
		if M.options.ui_visible then
			M.options.cursor_position = api.nvim_win_get_cursor(M.popups.tc.winid)
		else
			return
		end
	end
	if self then
		M.runner = self
	end
	M.options.restore_winid = nil
	M.delete_ui()
	M.options.restore_winid = M.runner.restore_winid

	local popup_settings = {
		enter = true,
		zindex = 50,
		border = {
			style = M.runner.config.floating_border,
			highlight = M.runner.config.floating_border_highlight,
			text = { top_align = "center" },
		},
		relative = "editor",
		buf_options = {
			modifiable = false,
			readonly = false,
			filetype = "CompetiTest",
		},
		win_options = {
			number = M.runner.config.runner_ui.selector_show_nu,
			relativenumber = M.runner.config.runner_ui.selector_show_rnu,
			wrap = false,
			spell = false,
		},
	}
	local sizes, positions = M.compute_layout()

	-- testcases selector popup
	popup_settings.border.text.top = " Testcases "
	popup_settings.size = sizes[1]
	popup_settings.position = positions[1]
	M.popups.tc = nui_popup(vim.deepcopy(popup_settings))

	popup_settings.win_options.number = M.runner.config.runner_ui.show_nu
	popup_settings.win_options.relativenumber = M.runner.config.runner_ui.show_rnu
	-- stdout popup
	popup_settings.border.text.top = " Output "
	popup_settings.enter = false
	popup_settings.size = sizes[2]
	popup_settings.position = positions[2]
	M.popups.so = nui_popup(popup_settings)

	-- expected output popup
	popup_settings.border.text.top = " Expected Output "
	popup_settings.size = sizes[2]
	popup_settings.position = positions[3]
	M.popups.eo = nui_popup(popup_settings)

	-- stdin popup
	popup_settings.border.text.top = " Input "
	popup_settings.size = sizes[2]
	popup_settings.position = positions[4]
	M.popups.si = nui_popup(popup_settings)

	-- stderr popup
	popup_settings.border.text.top = " Errors "
	popup_settings.size = sizes[2]
	popup_settings.position = positions[5]
	M.popups.se = nui_popup(popup_settings)

	M.popups.so:mount()
	api.nvim_buf_set_name(M.popups.so.bufnr, "CompetiTestOutput")
	M.popups.eo:mount()
	api.nvim_buf_set_name(M.popups.eo.bufnr, "CompetiTestExpectedOutput")
	M.popups.si:mount()
	api.nvim_buf_set_name(M.popups.si.bufnr, "CompetiTestInput")
	M.popups.se:mount()
	api.nvim_buf_set_name(M.popups.se.bufnr, "CompetiTestErrors")
	M.popups.tc:mount()
	api.nvim_buf_set_name(M.popups.tc.bufnr, "CompetiTestTestcases")
	M.options.ui_visible = true

	local function get_testcase_index_by_line()
		return api.nvim_win_get_cursor(M.popups.tc.winid)[1]
	end

	-- set keymaps
	for action, maps in pairs(M.runner.config.runner_ui.mappings) do
		if type(maps) == "string" then -- turn string into table
			M.runner.config.runner_ui.mappings[action] = { maps }
		end
	end

	local function close_popups()
		if M.options.viewer_visible then
			M.options.viewer_visible = false
			M.popups.vw:unmount()
			M.popups.vw = nil
			api.nvim_set_current_win(M.popups.tc.winid)
		else
			M.hide_ui()
		end
	end

	-- close popups keymaps
	for _, map in ipairs(M.runner.config.runner_ui.mappings.close) do
		M.popups.so:map("n", map, close_popups, { noremap = true })
		M.popups.eo:map("n", map, close_popups, { noremap = true })
		M.popups.si:map("n", map, close_popups, { noremap = true })
		M.popups.se:map("n", map, close_popups, { noremap = true })
		M.popups.tc:map("n", map, close_popups, { noremap = true })
	end

	-- kill process keymap
	for _, map in ipairs(M.runner.config.runner_ui.mappings.kill) do
		M.popups.tc:map("n", map, function()
			local tcindex = get_testcase_index_by_line()
			M.runner:kill_process(tcindex)
			M.runner.run_next_tc()
		end, { noremap = true })
	end

	-- kill all processes keymaps
	for _, map in ipairs(M.runner.config.runner_ui.mappings.kill_all) do
		M.popups.tc:map("n", map, function()
			M.runner:kill_all_processes()
		end, { noremap = true })
	end

	-- run again keymaps
	for _, map in ipairs(M.runner.config.runner_ui.mappings.run_again) do
		M.popups.tc:map("n", map, function()
			local tcindex = get_testcase_index_by_line()
			M.runner:kill_process(tcindex)
			vim.schedule(function()
				M.runner.run_next_tc(tcindex)
			end)
		end, { noremap = true })
	end

	-- run again all testcases keymaps
	for _, map in ipairs(M.runner.config.runner_ui.mappings.run_all_again) do
		M.popups.tc:map("n", map, function()
			M.runner:kill_all_processes()
			vim.schedule(function()
				M.runner:run_testcases()
			end)
		end, { noremap = true })
	end

	---Opens a popup to view text in a bigger window
	---@param text_type integer: 1 -> stdout, 2 -> expected output, 3 -> stdin, 4 -> stderr
	local function open_viewer_popup(text_type)
		text_type = text_type or M.options.viewer_type
		M.options.viewer_type = text_type
		local data = {
			{ title = " Output ", bufnr = M.popups.so.bufnr },
			{ title = " Expected Output ", bufnr = M.popups.eo.bufnr },
			{ title = " Input ", bufnr = M.popups.si.bufnr },
			{ title = " Errors ", bufnr = M.popups.se.bufnr },
		}

		local viewer_popup_settings = {
			enter = true,
			zindex = 60,
			bufnr = data[text_type].bufnr,
			border = {
				style = M.runner.config.floating_border,
				highlight = M.runner.config.floating_border_highlight,
				text = {
					top = data[text_type].title,
					top_align = "center",
				},
			},
			relative = "editor",
			size = sizes[3],
			position = positions[6],
			buf_options = {
				modifiable = false,
				readonly = false,
				filetype = "CompetiTest",
			},
			win_options = {
				number = M.runner.config.runner_ui.viewer.show_nu,
				relativenumber = M.runner.config.runner_ui.viewer.show_rnu,
			},
		}

		M.popups.vw = nui_popup(viewer_popup_settings)
		M.popups.vw:mount()
		M.options.viewer_visible = true

		-- close viewer popup keymaps
		for _, map in ipairs(M.runner.config.runner_ui.viewer.close_mappings) do
			M.popups.vw:map("n", map, close_popups, { noremap = true })
		end
	end

	-- view output (stdout) in a bigger window keymaps
	for _, map in ipairs(M.runner.config.runner_ui.mappings.view_stdout) do
		M.popups.tc:map("n", map, function()
			open_viewer_popup(1)
		end, { noremap = true })
	end

	-- view expected output in a bigger window keymaps
	for _, map in ipairs(M.runner.config.runner_ui.mappings.view_output) do
		M.popups.tc:map("n", map, function()
			open_viewer_popup(2)
		end, { noremap = true })
	end

	-- view input (stdin) in a bigger window keymaps
	for _, map in ipairs(M.runner.config.runner_ui.mappings.view_input) do
		M.popups.tc:map("n", map, function()
			open_viewer_popup(3)
		end, { noremap = true })
	end

	-- view stderr in a bigger window keymaps
	for _, map in ipairs(M.runner.config.runner_ui.mappings.view_stderr) do
		M.popups.tc:map("n", map, function()
			open_viewer_popup(4)
		end, { noremap = true })
	end

	M.popups.tc:on(nui_event.CursorMoved, function()
		local tcindex = get_testcase_index_by_line()
		if tcindex ~= M.options.update_testcase then
			M.options.update_testcase = tcindex
			M.options.update_details = true
			M.update_ui()
		end
	end)

	M.options.update_popups = true
	M.update_ui(nil, resized)
	if was_viewer_visible then
		vim.schedule(open_viewer_popup)
	end
end

---Return a string of length len, starting with str.
---If str's length is greater than len, str will be truncated
---Otherwise the remaining space will be filled with a fill char (fchar)
---@param len integer: length of final string
---@param str string: initial string
---@param fchar string: char to fill remaining spaces with
---@return string
local function adjust_string(len, str, fchar)
	local strlen = vim.fn.strwidth(str)
	if strlen <= len then
		for _ = strlen + 1, len do
			str = str .. fchar
		end
		return str
	else
		return vim.fn.strcharpart(str, 0, len - 1) .. "…"
	end
end

---Update TCRunner user interface content
---@param tcdata table: updated testcases data from self.tcdata
M.update_ui = vim.schedule_wrap(function(tcdata, resized)
	if tcdata then
		M.tcdata = tcdata
	end
	if not M.options.ui_visible or #M.tcdata == 0 then
		return
	end

	-- update popups content if not already updated
	if M.options.update_popups then
		M.options.update_popups = false
		M.options.update_details = true

		local lines = {}
		local hlregions = {}

		for tcindex, data in ipairs(M.tcdata) do
			local l = { header = "TC " .. data.tcnum, status = data.status, time = "" }
			if type(data.tcnum) == "string" then
				l.header = data.tcnum
			end
			if data.time and data.time ~= -1 then
				l.time = string.format("%.3f seconds", data.time / 1000)
			end
			local hl = { line = tcindex - 1, start_pos = 10, end_pos = 10 + #l.status, group = data.hlgroup }

			table.insert(lines, l)
			table.insert(hlregions, hl)
		end

		-- render lines
		local buffer_lines = {}
		for _, line in pairs(lines) do
			local line_str = adjust_string(10, line.header, " ") .. adjust_string(10, line.status, " ") .. line.time
			table.insert(buffer_lines, line_str)
		end
		local bufnr = M.popups.tc.bufnr
		api.nvim_buf_set_option(bufnr, "modifiable", true)
		api.nvim_buf_set_lines(bufnr, 0, -1, false, buffer_lines)
		-- render highlights
		for _, hl in pairs(hlregions) do
			api.nvim_buf_add_highlight(bufnr, -1, hl.group, hl.line, hl.start_pos, hl.end_pos)
		end
		api.nvim_buf_set_option(bufnr, "modifiable", false)
	end

	if resized then
		api.nvim_win_set_cursor(M.popups.tc.winid, M.options.cursor_position)
	end

	-- update details popups if not already updated
	if M.options.update_details then
		M.options.update_details = false

		local data = M.tcdata[M.options.update_testcase or 1]
		if not data then
			return
		end

		local function set_buf_content(bufnr, content)
			content = content or ""
			api.nvim_buf_set_option(bufnr, "modifiable", true)
			api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, "\n"))
			api.nvim_buf_set_option(bufnr, "modifiable", false)
		end

		set_buf_content(M.popups.so.bufnr, data.stdout)
		set_buf_content(M.popups.eo.bufnr, data.expout)
		set_buf_content(M.popups.si.bufnr, data.stdin)
		set_buf_content(M.popups.se.bufnr, data.stderr)
	end
end)

function M.show_ui()
	M.popups.so:show()
	M.popups.eo:show()
	M.popups.si:show()
	M.popups.se:show()
	M.popups.tc:show()
	M.options.ui_visible = true
	api.nvim_set_current_win(M.popups.tc.winid)
end

function M.hide_ui()
	for p, _ in pairs(M.popups) do
		if M.popups[p] then
			M.popups[p]:hide()
		end
	end
	M.options.ui_visible = false
	api.nvim_set_current_win(M.options.restore_winid or 0)
end

function M.delete_ui()
	for p, _ in pairs(M.popups) do
		if M.popups[p] then
			M.popups[p]:unmount()
			M.popups[p] = nil
		end
	end
	M.options.ui_visible = false
	M.options.viewer_visible = false
	api.nvim_set_current_win(M.options.restore_winid or 0)
end

return M
