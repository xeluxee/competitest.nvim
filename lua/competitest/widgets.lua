local api = vim.api
local utils = require("competitest.utils")
local M = {}

---Testcase editor UI mappings
---@class (exact) competitest.TestcaseEditorUI.mappings
---@field switch_window keymaps move cursor to the other window
---@field save_and_close keymaps save testcase and close testcase editor UI
---@field cancel keymaps close testcase editor UI without saving

---Testcase editor UI data
---@class (exact) competitest.TestcaseEditorUI
---@field private ui_visible boolean
---@field private bufnr integer buffer number
---@field private tcnum string testcase number as string
---@field private callback fun(testcase: competitest.FullTestcase)? function used to send back data (new input and output content)
---@field private restore_winid integer? bring the cursor to the given window after popups are closed
---@field private input_popup NuiPopup
---@field private output_popup NuiPopup
local editor = {}

---Open testcase editor UI with input and output windows
---@param bufnr integer | nil buffer number, or `nil` to resize UI
---@param tcnum integer? testcase number (only used for popup title)
---@param input_content string initial input content
---@param output_content string initial output content
---@param callback fun(testcase: competitest.FullTestcase)? function used to send back data (new input and output content)
---@param restore_winid integer? bring the cursor to the given window after popups are closed
function M.editor(bufnr, tcnum, input_content, output_content, callback, restore_winid)
	---Send back input and output data with callback
	local function send_data()
		if editor.callback then
			local function get_buf_text(buf)
				return table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
			end
			editor.callback({
				input = get_buf_text(editor.input_popup.bufnr),
				output = get_buf_text(editor.output_popup.bufnr),
			})
		end
		vim.bo[editor.input_popup.bufnr].modified = false
		vim.bo[editor.output_popup.bufnr].modified = false
	end

	---Close testcase editor UI
	local function delete_ui()
		if api.nvim_get_mode().mode == "i" then
			api.nvim_command("stopinsert")
		end
		editor.input_popup:unmount()
		editor.output_popup:unmount()
		editor.ui_visible = false
		if editor.restore_winid and api.nvim_win_is_valid(editor.restore_winid) then
			api.nvim_set_current_win(editor.restore_winid)
		end
	end

	---@type string[], string[]
	local input_lines, output_lines
	if bufnr == nil then -- resize UI
		if not editor.ui_visible then
			return
		end
		input_lines = api.nvim_buf_get_lines(editor.input_popup.bufnr, 0, -1, false)
		output_lines = api.nvim_buf_get_lines(editor.output_popup.bufnr, 0, -1, false)
		delete_ui()
	else
		editor.bufnr = bufnr
		editor.tcnum = tcnum and tostring(tcnum) .. " " or ""
		input_lines = vim.split(input_content or "", "\n", { plain = true })
		output_lines = vim.split(output_content or "", "\n", { plain = true })
		editor.callback = callback
		editor.restore_winid = restore_winid
	end

	local config = require("competitest.config").get_buffer_config(editor.bufnr)
	local vim_width, vim_height = utils.get_ui_size()

	local popup_width = math.floor(config.editor_ui.popup_width * vim_width)
	local popup_height = math.floor(config.editor_ui.popup_height * vim_height)
	---@type nui_popup_options
	local input_popup_settings = {
		enter = true,
		focusable = true,
		border = {
			style = config.floating_border,
			highlight = config.floating_border_highlight,
			text = {
				top = " Input " .. editor.tcnum,
				top_align = "center",
			},
		},
		relative = "editor",
		position = {
			row = math.floor((vim_height - popup_height) / 2),
			col = math.floor(vim_width / 2) - popup_width - 1,
		},
		size = {
			width = popup_width,
			height = popup_height,
		},
		buf_options = {
			modifiable = true,
			readonly = false,
			filetype = "CompetiTest",
			buftype = "acwrite",
		},
		win_options = {
			number = config.editor_ui.show_nu,
			relativenumber = config.editor_ui.show_rnu,
		},
	}
	local nui_popup = require("nui.popup")
	editor.input_popup = nui_popup(input_popup_settings)

	local output_popup_settings = input_popup_settings
	output_popup_settings.border.text.top = " Output " .. editor.tcnum
	output_popup_settings.position.col = math.floor(vim_width / 2) + 1
	editor.output_popup = nui_popup(output_popup_settings)

	-- mount/open the component
	editor.output_popup:mount()
	api.nvim_buf_set_name(editor.output_popup.bufnr, "CompetiTestEditOutput")
	editor.input_popup:mount()
	api.nvim_buf_set_name(editor.input_popup.bufnr, "CompetiTestEditInput")
	editor.ui_visible = true

	---Creates mappings in popup buffer following settings specified in config
	---@param p NuiPopup
	---@param m "n" | "i" mappings mode (normal or insert)
	---@param k competitest.TestcaseEditorUI.mappings
	---@param ow integer other popup winid
	local function set_popup_keymaps(p, m, k, ow)
		for action, maps in pairs(k) do
			if type(maps) == "string" then -- turn single string into a table
				k[action] = { maps }
			end
		end
		k = vim.tbl_extend("keep", k, {
			switch_window = {},
			save_and_close = {},
			cancel = {},
		})

		for _, map in ipairs(k.switch_window) do
			p:map(m, map, function()
				api.nvim_set_current_win(ow)
			end, { noremap = true })
		end

		for _, map in ipairs(k.save_and_close) do
			p:map(m, map, function()
				send_data()
				delete_ui()
			end, { noremap = true })
		end

		for _, map in ipairs(k.cancel) do
			p:map(m, map, function()
				delete_ui()
			end, { noremap = true })
		end
	end

	-- set keymaps
	set_popup_keymaps(editor.input_popup, "n", config.editor_ui.normal_mode_mappings, editor.output_popup.winid)
	set_popup_keymaps(editor.input_popup, "i", config.editor_ui.insert_mode_mappings, editor.output_popup.winid)
	set_popup_keymaps(editor.output_popup, "n", config.editor_ui.normal_mode_mappings, editor.input_popup.winid)
	set_popup_keymaps(editor.output_popup, "i", config.editor_ui.insert_mode_mappings, editor.input_popup.winid)

	-- autocommands for writing testcase with ":w", closing UI with ":q" and doing both with ":wq"
	local nui_event = require("nui.utils.autocmd").event
	editor.input_popup:on(nui_event.BufWriteCmd, send_data)
	editor.output_popup:on(nui_event.BufWriteCmd, send_data)
	editor.input_popup:on(nui_event.WinClosed, delete_ui)
	editor.output_popup:on(nui_event.WinClosed, delete_ui)

	-- set content
	api.nvim_buf_set_lines(editor.input_popup.bufnr, 0, 1, false, input_lines)
	api.nvim_buf_set_lines(editor.output_popup.bufnr, 0, 1, false, output_lines)
end

---Testcase picker UI data
---@class (exact) competitest.TestcasePickerUI
---@field private ui_visible boolean
---@field private bufnr integer buffer number
---@field private menu_items NuiTree.Node[] menu items
---@field private title string picker menu title
---@field private callback fun(tcnum: integer)? function used to send back data (chosen testcase)
---@field private restore_winid integer? bring the cursor to the given window after menu is closed
---@field private menu NuiMenu
local picker = {}

---Open testcase picker UI to choose a testcase
---@param bufnr integer | nil buffer number, or `nil` to resize UI
---@param tctbl competitest.TcTable
---@param title string floating window title
---@param callback fun(tcnum: integer)? function used to send back data (chosen testcase)
---@param restore_winid integer? bring the cursor to the given window after menu is closed
function M.picker(bufnr, tctbl, title, callback, restore_winid)
	---Close testcase picker UI
	---@param unmount boolean whether to unmount picker UI or not
	---@param tcnum integer? chosen testcase to be sent to callback
	local function delete_ui(unmount, tcnum)
		if unmount then
			picker.menu:unmount()
		end
		picker.ui_visible = false
		if picker.restore_winid and api.nvim_win_is_valid(picker.restore_winid) then
			api.nvim_set_current_win(picker.restore_winid)
		end
		if tcnum and picker.callback then
			picker.callback(tcnum)
		end
	end

	local nui_menu = require("nui.menu")
	if bufnr == nil then -- resize UI
		if not picker.ui_visible then
			return
		end
		delete_ui(true)
	else
		if next(tctbl) == nil then
			utils.notify("there's no testcase to pick from.")
			return
		end
		picker.bufnr = bufnr
		picker.menu_items = {}
		for tcnum, _ in pairs(tctbl) do
			table.insert(picker.menu_items, nui_menu.item("Testcase " .. tcnum, { tcnum = tcnum }))
		end
		picker.title = title and " " .. title .. " " or " Testcase Picker "
		picker.callback = callback
		picker.restore_winid = restore_winid
	end

	local config = require("competitest.config").get_buffer_config(picker.bufnr)
	local vim_width, vim_height = utils.get_ui_size()

	picker.menu = nui_menu({
		enter = true,
		border = {
			style = config.floating_border,
			highlight = config.floating_border_highlight,
			text = {
				top = picker.title,
				top_align = "center",
			},
		},
		relative = "editor",
		position = "50%",
		size = {
			width = math.floor(vim_width * config.picker_ui.width),
			height = math.floor(vim_height * config.picker_ui.height),
		},
		buf_options = {
			filetype = "CompetiTest",
		},
	}, {
		lines = picker.menu_items,
		keymap = config.picker_ui.mappings,
		on_close = function()
			delete_ui(false)
		end,
		on_submit = function(item)
			delete_ui(false, item.tcnum)
		end,
	})

	picker.menu:mount()
	api.nvim_buf_set_name(picker.menu.bufnr, "CompetiTestPicker")
	picker.ui_visible = true
end

---Single-line input UI data
---@class (exact) competitest.InputWidget
---@field private ui_visible boolean
---@field private title string input popup title
---@field private default_text string default input popup text
---@field private border_style nui_popup_border_option_style
---@field private callback_on_submit fun(text: string) callback called on submit, accepts input text
---@field private callback_on_close fun()? callback called when the operation is cancelled
---@field private skip_on_close boolean skip the next `on_close` callback when input popup is closed
---@field private popup NuiPopup
local input = {}

---Open a single-line input popup UI
---@param title string | nil input popup title, or `nil` to resize UI
---@param default_text string default input popup text
---@param border_style nui_popup_border_option_style
---@param callback_only boolean if `true` don't mount a popup and directly call `callback_on_submit` with `default_text`
---@param callback_on_submit fun(text: string) callback called on submit, accepts input text as argument
---@param callback_on_close fun()? callback called when the operation is cancelled
function M.input(title, default_text, border_style, callback_only, callback_on_submit, callback_on_close)
	if title == nil then -- resize UI
		if not input.ui_visible then
			return
		end
		input.skip_on_close = true
		input.default_text = api.nvim_buf_get_lines(input.popup.bufnr, 0, -1, false)[1]
		input.popup:unmount()
	else
		if callback_only then
			callback_on_submit(default_text)
			return
		end
		input.title = title
		input.default_text = default_text
		input.border_style = border_style
		input.callback_on_submit = callback_on_submit
		input.callback_on_close = callback_on_close
	end

	local nui_input = require("nui.input")

	input.popup = nui_input({
		relative = "editor",
		position = "50%",
		size = "50%",
		border = {
			style = input.border_style,
			text = {
				top = " " .. input.title .. " ",
			},
		},
	}, {
		on_close = function()
			if input.skip_on_close then
				input.skip_on_close = false
				return
			end
			input.ui_visible = false
			if input.callback_on_close then
				input.callback_on_close()
			end
		end,
		on_submit = function(text)
			input.ui_visible = false
			input.callback_on_submit(text)
		end,
	})

	input.popup:mount()
	input.ui_visible = true
	-- do not use builtin default_value to properly resize input window
	api.nvim_buf_set_lines(input.popup.bufnr, 0, -1, false, { input.default_text })
	api.nvim_command("startinsert!")
end

---Resize widgets if they are visible
function M.resize_widgets()
	M.editor(nil)
	M.picker(nil)
	M.input(nil)
end

return M
