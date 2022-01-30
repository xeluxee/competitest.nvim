local api = vim.api
local nui_popup = require("nui.popup")
local utils = require("competitest.utils")
local M = {}
M.popups = {}
M.options = {}

---Start a UI with input and output windows
---@param bufnr integer | nil: buffer number or nil to use current buffer
---@param tcnum integer | nil: testcase number (used only for popup title)
---@param input_content string: initial input content
---@param output_content string: initial output content
---@param send_data function | nil: the function used to send back datas (new input and output content)
---@param restore_winid integer | nil: bring the cursor to the given window after popups are closed
function M.start_ui(bufnr, tcnum, input_content, output_content, send_data, restore_winid)
	if bufnr == "resized" then
		if not M.options.ui_visible then
			return
		end
		input_content = api.nvim_buf_get_lines(M.popups.input_popup.bufnr, 0, -1, false)
		output_content = api.nvim_buf_get_lines(M.popups.output_popup.bufnr, 0, -1, false)
		M.delete_ui()
	else
		M.options.bufnr = bufnr or vim.fn.bufnr()
		M.options.tcnum = tcnum and tostring(tcnum) .. " " or ""
		input_content = vim.split(input_content or "", "\n")
		output_content = vim.split(output_content or "", "\n")
		M.options.send_data = send_data
		M.options.restore_winid = restore_winid
	end

	local config = require("competitest.config").get_config(M.options.bufnr)
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
				top = " Input " .. M.options.tcnum,
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
	M.popups.input_popup = nui_popup(input_popup_settings)

	local output_popup_settings = input_popup_settings
	output_popup_settings.border.text.top = " Output " .. M.options.tcnum
	output_popup_settings.position.col = math.floor(vim_width / 2) + 1
	M.popups.output_popup = nui_popup(output_popup_settings)

	-- mount/open the component
	M.popups.output_popup:mount()
	api.nvim_buf_set_name(M.popups.output_popup.bufnr, "CompetiTestEditOutput")
	M.popups.input_popup:mount()
	api.nvim_buf_set_name(M.popups.input_popup.bufnr, "CompetiTestEditInput")
	M.options.ui_visible = true

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
				M.delete_ui(M.options.send_data)
			end, { noremap = true })
		end

		for _, map in ipairs(k.cancel) do
			p:map(m, map, function()
				M.delete_ui()
			end, { noremap = true })
		end
	end

	-- set keymaps
	set_popup_keymaps(M.popups.input_popup, "n", config.editor_ui.normal_mode_mappings, M.popups.output_popup.winid)
	set_popup_keymaps(M.popups.input_popup, "i", config.editor_ui.insert_mode_mappings, M.popups.output_popup.winid)
	set_popup_keymaps(M.popups.output_popup, "n", config.editor_ui.normal_mode_mappings, M.popups.input_popup.winid)
	set_popup_keymaps(M.popups.output_popup, "i", config.editor_ui.insert_mode_mappings, M.popups.input_popup.winid)

	-- set content
	api.nvim_buf_set_lines(M.popups.input_popup.bufnr, 0, 1, false, input_content)
	api.nvim_buf_set_lines(M.popups.output_popup.bufnr, 0, 1, false, output_content)
end

function M.delete_ui(send_data)
	if api.nvim_get_mode().mode == "i" then
		api.nvim_command("stopinsert")
	end
	if send_data ~= nil then
		local function get_buf_text(bufnr)
			local str = ""
			local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
			for _, line in ipairs(lines) do
				str = str .. line .. "\n"
			end
			return string.sub(str, 0, -2)
		end
		send_data({
			input = get_buf_text(M.popups.input_popup.bufnr),
			output = get_buf_text(M.popups.output_popup.bufnr),
		})
	end
	M.popups.input_popup:unmount()
	M.popups.output_popup:unmount()
	M.options.ui_visible = false
	api.nvim_set_current_win(M.options.restore_winid or 0)
end

return M
