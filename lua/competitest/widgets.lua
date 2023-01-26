local api = vim.api
local utils = require("competitest.utils")
local M = {}

local editor = {} -- testcase editor data

---Open testcase editor UI with input and output windows
---@param bufnr integer | nil: buffer number, or nil to resize UI
---@param tcnum integer | nil: testcase number (used only for popup title)
---@param input_content string: initial input content
---@param output_content string: initial output content
---@param callback function | nil: function used to send back data (new input and output content)
---@param restore_winid integer | nil: bring the cursor to the given window after popups are closed
function M.editor(bufnr, tcnum, input_content, output_content, callback, restore_winid)
	local function delete_ui(send)
		if api.nvim_get_mode().mode == "i" then
			api.nvim_command("stopinsert")
		end
		if send and callback ~= nil then
			local function get_buf_text(buf)
				return table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
			end
			editor.callback({
				input = get_buf_text(editor.input_popup.bufnr),
				output = get_buf_text(editor.output_popup.bufnr),
			})
		end
		editor.input_popup:unmount()
		editor.output_popup:unmount()
		editor.ui_visible = false
		api.nvim_set_current_win(editor.restore_winid or 0)
	end

	if bufnr == nil then -- resize UI
		if not editor.ui_visible then
			return
		end
		input_content = api.nvim_buf_get_lines(editor.input_popup.bufnr, 0, -1, false)
		output_content = api.nvim_buf_get_lines(editor.output_popup.bufnr, 0, -1, false)
		delete_ui(false)
	else
		editor.bufnr = bufnr
		editor.tcnum = tcnum and tostring(tcnum) .. " " or ""
		input_content = vim.split(input_content or "", "\n", { plain = true })
		output_content = vim.split(output_content or "", "\n", { plain = true })
		editor.callback = callback
		editor.restore_winid = restore_winid
	end

	local config = require("competitest.config").get_buffer_config(editor.bufnr)
	local vim_width, vim_height = utils.get_ui_size()

	local popup_width = math.floor(config.editor_ui.popup_width * vim_width)
	local popup_height = math.floor(config.editor_ui.popup_height * vim_height)
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
	---@param p any: popup
	---@param m string: mode (insert or normal)
	---@param k table: table containing keymappings
	---@param ow integer: other window, winid
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
				delete_ui(true)
			end, { noremap = true })
		end

		for _, map in ipairs(k.cancel) do
			p:map(m, map, function()
				delete_ui(false)
			end, { noremap = true })
		end
	end

	-- set keymaps
	set_popup_keymaps(editor.input_popup, "n", config.editor_ui.normal_mode_mappings, editor.output_popup.winid)
	set_popup_keymaps(editor.input_popup, "i", config.editor_ui.insert_mode_mappings, editor.output_popup.winid)
	set_popup_keymaps(editor.output_popup, "n", config.editor_ui.normal_mode_mappings, editor.input_popup.winid)
	set_popup_keymaps(editor.output_popup, "i", config.editor_ui.insert_mode_mappings, editor.input_popup.winid)

	-- set content
	api.nvim_buf_set_lines(editor.input_popup.bufnr, 0, 1, false, input_content)
	api.nvim_buf_set_lines(editor.output_popup.bufnr, 0, 1, false, output_content)
end

local picker = {} -- testcase picker data

---Open testcases picker UI to choose a testcase
---@param bufnr integer | nil: buffer number, or nil to resize UI
---@param tctbl table: a table of tables made by two strings, input and output
---@param title string: floating window title
---@param callback function | nil: function used to send back data (chosen item)
---@param restore_winid integer | nil: bring the cursor to the given window after menu is closed
function M.picker(bufnr, tctbl, title, callback, restore_winid)
	local function delete_ui(unmount, item)
		if unmount then
			picker.menu:unmount()
		end
		picker.ui_visible = false
		vim.api.nvim_set_current_win(picker.restore_winid or 0)
		if item and picker.callback then
			picker.callback(item)
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
			table.insert(picker.menu_items, nui_menu.item("Testcase " .. tcnum, { id = tcnum }))
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
			delete_ui()
		end,
		on_submit = function(item)
			delete_ui(false, item)
		end,
	})

	picker.menu:mount()
	vim.api.nvim_buf_set_name(picker.menu.bufnr, "CompetiTestPicker")
	picker.ui_visible = true
end

local input = {}

---Open a single-line input popup UI
---@param title string | nil: popup title, or nil to resize UI
---@param default_text string
---@param border_style string
---@param callback function
function M.input(title, default_text, border_style, callback)
	if title == nil then -- resize UI
		if not input.ui_visible then
			return
		end
		input.default_text = api.nvim_buf_get_lines(input.popup.bufnr, 0, -1, false)[1]
		input.popup:unmount()
	else
		input.title = title
		input.default_text = default_text
		input.border_style = border_style
		input.callback = callback
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
			input.ui_visible = false
		end,
		on_submit = function(value)
			input.ui_visible = false
			input.callback(value)
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
