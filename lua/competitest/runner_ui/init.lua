local api = vim.api
local nui_event = require("nui.utils.autocmd").event
local utils = require("competitest.utils")

---@alias competitest.RunnerUI.textual_window # runner UI window showing textual data
---| "si" standard input window
---| "so" standard output window
---| "se" standard error window
---| "eo" expected output window

---@alias competitest.RunnerUI.standard_window # runner UI standard window, i.e. a textual window or testcases selector window
---| competitest.RunnerUI.textual_window textual windows
---| "tc" testcases selector window

---@alias competitest.RunnerUI.window # runner UI window
---| competitest.RunnerUI.standard_window standard windows
---| "vw" viewer popup window

---Runner UI layout window definition
---@class (exact) competitest.RunnerUI.layout.window
---@field [1] number ratio between window size and the sizes of other windows in the same layout
---@field [2] competitest.RunnerUI.standard_window | competitest.RunnerUI.layout standard window type or another layout for a sub-layout

---@alias competitest.RunnerUI.layout competitest.RunnerUI.layout.window[] Runner UI layout

---@alias competitest.RunnerUI.windows_table table<competitest.RunnerUI.window, NuiPopup | NuiSplit> table associating runner UI window name to `NuiPopup` or `NuiSplit` object

---Runner UI interface
---@class (exact) competitest.RunnerUI.interface
---@field init_ui fun(windows: competitest.RunnerUI.windows_table, config: competitest.Config, init_winid: integer?) function to initialize UI, accepting runner UI windows table, current CompetiTest configuration and optionally the id of window associated to runner
---@field show_ui fun(windows: competitest.RunnerUI.windows_table)? function to show UI when already initialized, or `nil` if UI always needs to be re-initialized

---@alias competitest.RunnerUI.user_action # Runner UI user action
---| "run_again" run again a testcase
---| "run_all_again" run again all testcases
---| "kill" kill a testcase
---| "kill_all" kill all testcases
---| "view_input" view input (stdin) in a bigger window
---| "view_output" view expected output in a bigger window
---| "view_stdout" view program output (stdout) in a bigger window
---| "view_stderr" view program errors (stderr) in a bigger window
---| "toggle_diff" toggle diff view between actual and expected output
---| "close" close runner UI

---Testcases Runner UI
---@class (exact) competitest.RunnerUI
---@field private runner competitest.TCRunner
---@field private ui_initialized boolean
---@field private ui_visible boolean
---@field private viewer_initialized boolean
---@field private viewer_visible boolean
---@field private viewer_content competitest.RunnerUI.textual_window?
---@field private diff_view boolean
---@field restore_winid integer? bring the cursor to the given window when runner UI is closed
---@field update_details boolean one-time request for `self:update_ui()` to update details windows
---@field update_windows boolean one-time request for `self:update_ui()` to update all the windows
---@field private update_testcase integer? index of testcase to update
---@field private windows competitest.RunnerUI.windows_table
---@field private interface competitest.RunnerUI.interface
---@field private make_viewer_visible boolean one-time request for `self:update_ui()` to open viewer after updating details
local RunnerUI = {}
RunnerUI.__index = RunnerUI ---@diagnostic disable-line: inject-field

---Create a new `RunnerUI`
---@param runner competitest.TCRunner associated testcase runner
---@return competitest.RunnerUI? # a new `RunnerUI`, or `nil` on failure
function RunnerUI:new(runner)
	---@type competitest.RunnerUI.interface
	local interface
	if runner.config.runner_ui.interface == "popup" then
		interface = require("competitest.runner_ui.popup")
	elseif runner.config.runner_ui.interface == "split" then
		interface = require("competitest.runner_ui.split")
	else
		utils.notify("RunnerUI:new: unrecognized user interface " .. vim.inspect(runner.config.runner_ui.interface) .. ".")
		return nil
	end

	---@type competitest.RunnerUI
	local this = {
		runner = runner,
		ui_initialized = false,
		ui_visible = false,
		viewer_initialized = false,
		viewer_visible = false,
		viewer_content = nil,
		diff_view = runner.config.view_output_diff,
		restore_winid = runner.restore_winid,
		update_details = false,
		update_windows = false,
		update_testcase = nil,
		windows = {},
		interface = interface,
		make_viewer_visible = false,
	}
	setmetatable(this, self)
	return this
end

---Re-initialize UI, this method is called every time Neovim window gets resized (`autocmd VimResized`)
function RunnerUI:resize_ui()
	local cursor_position = self.ui_visible and api.nvim_win_get_cursor(self.windows.tc.winid) -- restore cursor position later
	local was_viewer_visible = self.viewer_visible -- make viewer visible later
	self:delete()
	if cursor_position then -- if cursor_position isn't nil ui was visible
		self.make_viewer_visible = was_viewer_visible
		self:show_ui()
		vim.schedule(function()
			api.nvim_win_set_cursor(self.windows.tc.winid, cursor_position)
		end)
	end
end

---Show Runner UI if not already shown.
---It initializes UI if called for the first time or resized.
function RunnerUI:show_ui()
	if not self.ui_initialized or (not self.interface.show_ui and not self.ui_visible) then -- initialize ui
		self.interface.init_ui(self.windows, self.runner.config, self.restore_winid)

		-- set buffer name and variable
		local windows_names = {
			si = "Input", -- standard input
			so = "Output", -- standard output
			se = "Errors", -- standard error
			eo = "Expected Output", -- expected output
			tc = "Testcases", -- testcases selector
		}
		for n, w in pairs(self.windows) do
			if n ~= "vw" then
				api.nvim_buf_set_var(w.bufnr, "competitest_title", windows_names[n])
				api.nvim_buf_set_name(w.bufnr, "CompetiTest" .. string.gsub(windows_names[n], " ", "") .. w.bufnr)
			end
		end

		-- set keymaps

		---@type table<competitest.RunnerUI.user_action, keymap[]>
		local runner_ui_mappings = {}
		for action, maps in pairs(self.runner.config.runner_ui.mappings) do
			if type(maps) == "string" then -- turn string into table
				runner_ui_mappings[action] = { maps }
			else
				runner_ui_mappings[action] = maps
			end
		end

		local function hide_ui() -- hide viewer popup if visible, otherwise close ui
			if self.viewer_visible then
				self.windows.vw:hide()
				api.nvim_set_current_win(self.windows.tc.winid)
				self.viewer_visible = false
			else
				self:hide_ui()
			end
		end

		-- close windows keymaps
		for _, map in ipairs(runner_ui_mappings.close) do
			for n, w in pairs(self.windows) do
				if n ~= "vw" then
					w:map("n", map, hide_ui, { noremap = true })

					w:on(nui_event.QuitPre, function() -- close windows with ":q"
						local winid -- window of buffer shown in viewer
						if self.viewer_visible and n == self.viewer_content then
							winid = w.winid
						end
						self:delete()
						if winid and api.nvim_win_is_valid(winid) then -- workaround to close last split
							api.nvim_buf_delete(api.nvim_win_get_buf(winid), { force = true })
						end
					end)
				end
			end
		end

		local function get_testcase_index_by_line()
			return api.nvim_win_get_cursor(self.windows.tc.winid)[1]
		end

		-- kill current process
		for _, map in ipairs(runner_ui_mappings.kill) do
			self.windows.tc:map("n", map, function()
				local tcindex = get_testcase_index_by_line()
				self.runner:kill_process(tcindex)
			end, { noremap = true })
		end

		-- kill all processes
		for _, map in ipairs(runner_ui_mappings.kill_all) do
			self.windows.tc:map("n", map, function()
				self.runner:kill_all_processes()
			end, { noremap = true })
		end

		-- run again current testcase
		for _, map in ipairs(runner_ui_mappings.run_again) do
			self.windows.tc:map("n", map, function()
				local tcindex = get_testcase_index_by_line()
				self.runner:kill_process(tcindex)
				vim.schedule(function()
					self.runner:run_testcase(tcindex)
				end)
			end, { noremap = true })
		end

		-- run again all testcases
		for _, map in ipairs(runner_ui_mappings.run_all_again) do
			self.windows.tc:map("n", map, function()
				self.runner:kill_all_processes()
				vim.schedule(function()
					self.runner:run_testcases()
				end)
			end, { noremap = true })
		end

		-- toggle diff view between expected and standard output
		for _, map in ipairs(runner_ui_mappings.toggle_diff) do
			self.windows.tc:map("n", map, function()
				self:toggle_diff_view()
			end, { noremap = true })
		end

		local function open_viewer(keymap, window_name) -- create a mapping to open viewer popup
			self.windows.tc:map("n", keymap, function()
				self:show_viewer_popup(window_name)
			end, { noremap = true })
		end

		-- view output (stdout) in a bigger window
		for _, map in ipairs(runner_ui_mappings.view_stdout) do
			open_viewer(map, "so")
		end
		-- view expected output in a bigger window
		for _, map in ipairs(runner_ui_mappings.view_output) do
			open_viewer(map, "eo")
		end
		-- view input (stdin) in a bigger window
		for _, map in ipairs(runner_ui_mappings.view_input) do
			open_viewer(map, "si")
		end
		-- view stderr in a bigger window
		for _, map in ipairs(runner_ui_mappings.view_stderr) do
			open_viewer(map, "se")
		end

		self.windows.tc:on(nui_event.CursorMoved, function()
			local tcindex = get_testcase_index_by_line()
			if tcindex ~= self.update_testcase then
				self.update_testcase = tcindex
				self.update_details = true
				self:update_ui()
			end
		end)

		self.ui_initialized = true
		self.ui_visible = true
		self.update_windows = true
		self:update_ui()
	elseif not self.ui_visible then -- show ui
		self.interface.show_ui(self.windows)
		self.ui_visible = true
	end

	if self.diff_view then -- enable diff view if previously enabled
		self.diff_view = false
		self:toggle_diff_view()
	end
	api.nvim_set_current_win(self.windows.tc.winid)
end

---Enable or disable diffview in given window
---@param winid integer
---@param enable_diff boolean
local function win_set_diff(winid, enable_diff)
	if winid and api.nvim_win_is_valid(winid) then
		api.nvim_win_call(winid, function()
			api.nvim_command(enable_diff and "diffthis" or "diffoff")
			vim.wo.foldlevel = 1 -- unfold unchanged text
		end)
	end
end

---@private
---Toggle diffview between standard output and expected output windows
function RunnerUI:toggle_diff_view()
	self.diff_view = not self.diff_view
	win_set_diff(self.windows.eo.winid, self.diff_view)
	win_set_diff(self.windows.so.winid, self.diff_view)
end

---@private
---Disable diffview between standard output and expected output windows
function RunnerUI:disable_diff_view()
	win_set_diff(self.windows.eo.winid, false)
	win_set_diff(self.windows.so.winid, false)
end

---@private
---Hide RunnerUI preserving buffers, so it can be shown later
function RunnerUI:hide_ui()
	if self.ui_visible then
		self:disable_diff_view() -- disable diff when closing windows to prevent conflicts with other diffviews
		for _, w in pairs(self.windows) do
			if w then -- if a window is uninitialized its value is nil
				w:hide()
			end
		end
		self.ui_visible = false
		self.viewer_visible = false
		if self.restore_winid and api.nvim_win_is_valid(self.restore_winid) then
			api.nvim_set_current_win(self.restore_winid)
		end
	end
end

---@private
---Delete RunnerUI and uninitialize all the windows
function RunnerUI:delete()
	if self.ui_visible then
		self:disable_diff_view() -- disable diff when closing windows to prevent conflicts with other diffviews
	end
	for name, w in pairs(self.windows) do
		if w then -- if a window is uninitialized its value is nil
			w:unmount()
			self.windows[name] = nil
		end
	end
	self.ui_initialized = false
	self.ui_visible = false
	self.viewer_initialized = false
	self.viewer_visible = false
	if self.restore_winid and api.nvim_win_is_valid(self.restore_winid) then
		api.nvim_set_current_win(self.restore_winid)
	end
end

---@private
---Open viewer popup
---@param window_name competitest.RunnerUI.textual_window? show window content in viewer popup, if `nil` show previously shown content
function RunnerUI:show_viewer_popup(window_name)
	local function get_viewer_buffer()
		return self.windows[self.viewer_content].bufnr
	end

	local function get_viewer_popup_title()
		return " " .. api.nvim_buf_get_var(get_viewer_buffer(), "competitest_title") .. " "
	end

	if window_name then
		self.viewer_content = window_name
		if self.viewer_visible then
			self.windows.vw.border:set_text("top", get_viewer_popup_title(), "center")
			api.nvim_win_set_buf(self.windows.vw.winid, get_viewer_buffer())
		end
	end

	if not self.viewer_initialized then
		local vim_width, vim_height = utils.get_ui_size()
		---@type nui_popup_options
		local viewer_popup_settings = {
			bufnr = get_viewer_buffer(),
			zindex = 55, -- popup ui has zindex 50
			border = {
				style = self.runner.config.floating_border,
				highlight = self.runner.config.floating_border_highlight,
				text = {
					top = get_viewer_popup_title(),
					top_align = "center",
				},
			},
			relative = "editor",
			size = {
				width = math.floor(vim_width * self.runner.config.runner_ui.viewer.width + 0.5),
				height = math.floor(vim_height * self.runner.config.runner_ui.viewer.height + 0.5),
			},
			position = "50%",
			win_options = {
				number = self.runner.config.runner_ui.viewer.show_nu,
				relativenumber = self.runner.config.runner_ui.viewer.show_rnu,
			},
		}

		self.windows.vw = require("nui.popup")(viewer_popup_settings)
		self.windows.vw:mount()
		self.viewer_initialized = true
		self.viewer_visible = true
	elseif not self.viewer_visible then
		self.windows.vw.bufnr = get_viewer_buffer()
		self.windows.vw:show()
		self.windows.vw.border:set_text("top", get_viewer_popup_title(), "center")
		self.viewer_visible = true
	end
	api.nvim_set_current_win(self.windows.vw.winid)
end

---Return a string of length `len`, starting with `str`.
---If `str` length is greater than `len`, `str` will be truncated.
---Otherwise the remaining space will be filled with a fill character (`fchar`)
---@param len integer length of final string
---@param str string initial string
---@param fchar string char to fill remaining spaces with
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

---Update Runner UI
function RunnerUI:update_ui()
	vim.schedule(function()
		if not self.ui_visible or next(self.runner.tcdata) == nil then
			return
		end

		-- update windows content if not already updated
		if self.update_windows then
			self.update_windows = false
			self.update_details = true

			---@type { header: string, status: string, time: string }[]
			local lines = {}
			---@type { line: integer, start_pos: integer, end_pos: integer, group: string }[]
			local hlregions = {}

			for tcindex, data in ipairs(self.runner.tcdata) do
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

			---@type string[]
			local buffer_lines = {}
			for _, line in pairs(lines) do
				local line_str = adjust_string(10, line.header, " ") .. adjust_string(10, line.status, " ") .. line.time
				table.insert(buffer_lines, line_str)
			end
			local bufnr = self.windows.tc.bufnr
			vim.bo[bufnr].modifiable = true
			api.nvim_buf_set_lines(bufnr, 0, -1, false, buffer_lines)
			-- render highlights
			for _, hl in pairs(hlregions) do
				api.nvim_buf_add_highlight(bufnr, -1, hl.group, hl.line, hl.start_pos, hl.end_pos)
			end
			vim.bo[bufnr].modifiable = false
		end

		-- update details windows if not already updated
		if self.update_details then
			self.update_details = false

			local data = self.runner.tcdata[self.update_testcase or 1]
			if not data then
				return
			end

			---Set buffer content
			---@param bufnr integer
			---@param content string[]? lines, or `nil` to make buffer empty
			local function set_buf_content(bufnr, content)
				vim.bo[bufnr].modifiable = true
				api.nvim_buf_set_lines(bufnr, 0, -1, false, content or {})
				vim.bo[bufnr].modifiable = false
			end

			set_buf_content(self.windows.so.bufnr, data.stdout)
			set_buf_content(self.windows.eo.bufnr, data.expout)
			set_buf_content(self.windows.si.bufnr, data.stdin)
			set_buf_content(self.windows.se.bufnr, data.stderr)
		end

		if self.make_viewer_visible then
			self.make_viewer_visible = false
			self:show_viewer_popup()
		end
	end)
end

return RunnerUI
