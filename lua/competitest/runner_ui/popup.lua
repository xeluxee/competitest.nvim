local nui_popup = require("nui.popup")
local M = {}

---@param config table: table containing user configuration
function M.compute_layout(config)
	local sizes = { tc = {}, si = {}, so = {}, se = {}, eo = {} }
	local positions = { tc = {}, si = {}, so = {}, se = {}, eo = {} }

	---Recursively compute popup layout
	---@param layout table: layout description
	---@param vertical boolean: whether to proceed vertically or horizontally
	---@param width integer: rectangle width
	---@param height integer: rectangle height
	---@param col integer: starting column
	---@param row integer: starting row
	local function compute_layout(layout, vertical, width, height, col, row)
		if type(layout) == "string" then
			sizes[layout].width = width - 2
			sizes[layout].height = height - 2
			positions[layout].col = col
			positions[layout].row = row
			return
		end

		local layout_width = 0
		for _, l in ipairs(layout) do
			layout_width = layout_width + l[1]
		end

		local current_size = 0
		local dimension = vertical and height or width
		for i, l in ipairs(layout) do
			local popup_size = math.floor(dimension * l[1] / layout_width + 0.5)
			if i == #layout then
				popup_size = dimension - current_size
			end

			if vertical then
				compute_layout(l[2], not vertical, width, popup_size, col, row + current_size)
			else
				compute_layout(l[2], not vertical, popup_size, height, col + current_size, row)
			end
			current_size = current_size + popup_size
		end
	end

	local vim_width, vim_height = require("competitest.utils").get_ui_size()
	local total_width = math.floor(vim_width * config.popup_ui.total_width + 0.5)
	local total_height = math.floor(vim_height * config.popup_ui.total_height + 0.5)
	local initial_col = math.floor((vim_width - total_width) / 2 + 0.5)
	local initial_row = math.floor((vim_height - total_height) / 2 + 0.5)

	compute_layout(config.popup_ui.layout, false, total_width, total_height, initial_col, initial_row)
	return sizes, positions
end

---Initialize popup UI
---@param windows table: table containing windows
---@param config table: table containing user configuration
function M.init_ui(windows, config)
	local popup_settings = {
		zindex = 50,
		border = {
			style = config.floating_border,
			highlight = config.floating_border_highlight,
			text = { top_align = "center" },
		},
		relative = "editor",
		buf_options = {
			modifiable = false,
			readonly = false,
			filetype = "CompetiTest",
		},
		win_options = {
			number = config.runner_ui.selector_show_nu,
			relativenumber = config.runner_ui.selector_show_rnu,
			wrap = false,
			spell = false,
		},
	}
	local sizes, positions = M.compute_layout(config)

	-- testcases selector popup
	popup_settings.border.text.top = " Testcases "
	popup_settings.size = sizes["tc"]
	popup_settings.position = positions["tc"]
	windows.tc = nui_popup(vim.deepcopy(popup_settings))

	popup_settings.win_options.number = config.runner_ui.show_nu
	popup_settings.win_options.relativenumber = config.runner_ui.show_rnu
	-- stdout popup
	popup_settings.border.text.top = " Output "
	popup_settings.size = sizes["so"]
	popup_settings.position = positions["so"]
	windows.so = nui_popup(popup_settings)

	-- expected output popup
	popup_settings.border.text.top = " Expected Output"
	popup_settings.size = sizes["eo"]
	popup_settings.position = positions["eo"]
	windows.eo = nui_popup(popup_settings)

	-- stdin popup
	popup_settings.border.text.top = " Input "
	popup_settings.size = sizes["si"]
	popup_settings.position = positions["si"]
	windows.si = nui_popup(popup_settings)

	-- stderr popup
	popup_settings.border.text.top = " Errors "
	popup_settings.size = sizes["se"]
	popup_settings.position = positions["se"]
	windows.se = nui_popup(popup_settings)

	windows.so:mount()
	windows.eo:mount()
	windows.si:mount()
	windows.se:mount()
	windows.tc:mount()
end

-- Show popup UI
function M.show_ui(windows)
	for n, w in pairs(windows) do
		if n ~= "vw" then -- show ui but not viewer popup
			w:show()
		end
	end
end

return M
