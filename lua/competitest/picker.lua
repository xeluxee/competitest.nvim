local nui_menu = require("nui.menu")
local utils = require("competitest.utils")
local M = { options = {} }

---Start a Picker UI to choose a testcase
---@param bufnr integer | nil: buffer number or nil to use current buffer
---@param tctbl table: a table of tables made by two strings, input and output
---@param title string: floating window title
---@param send_data function | nil: the function used to send back datas (chosen item)
---@param restore_winid integer | nil: bring the cursor to the given window after menu is closed
function M.start_ui(bufnr, tctbl, title, send_data, restore_winid)
	if bufnr == "resized" then
		if not M.options.ui_visible then
			return
		end
		M.delete_ui(true)
	else
		M.options.bufnr = bufnr or vim.fn.bufnr()
		M.options.menu_items = {}
		for tcnum, _ in pairs(tctbl) do
			table.insert(M.options.menu_items, nui_menu.item("Testcase " .. tcnum, { id = tcnum }))
		end
		M.options.title = title and " " .. title .. " " or " Testcase Picker "
		M.options.send_data = send_data
		M.options.restore_winid = restore_winid
	end

	local config = require("competitest.config").get_config(M.options.bufnr)
	local vim_width, vim_height = utils.get_ui_size()

	M.menu = nui_menu({
		enter = true,
		border = {
			style = config.floating_border,
			highlight = config.floating_border_highlight,
			text = {
				top = M.options.title,
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
		lines = M.options.menu_items,
		keymap = config.picker_ui.mappings,
		on_close = function()
			M.delete_ui()
		end,
		on_submit = function(item)
			M.delete_ui(false, item)
		end,
	})

	M.menu:mount()
	vim.api.nvim_buf_set_name(M.menu.bufnr, "CompetiTestPicker")
	M.options.ui_visible = true
end

function M.delete_ui(unmount, item)
	if unmount then
		M.menu:unmount()
	end
	M.options.ui_visible = false
	vim.api.nvim_set_current_win(M.options.restore_winid or 0)
	if item and M.options.send_data then
		M.options.send_data(item)
	end
end

return M
