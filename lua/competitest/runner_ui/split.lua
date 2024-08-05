local nui_split = require("nui.split")
local M = {}
M.init_ui_only = true -- no method show_ui() because ui is re-initialized to create layout every time it's opened

---Initialize popup UI
---@param windows table: table containing windows
---@param config table: table containing user configuration
---@param init_winid integer: id of window associated to runner
function M.init_ui(windows, config, init_winid)
	local split_settings = {
		enter = false,
		relative = { type = "win" },
		size = "50%",
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

	local settings = {} -- windows splits settings
	settings.tc = vim.deepcopy(split_settings)
	split_settings.win_options.number = config.runner_ui.show_nu
	split_settings.win_options.relativenumber = config.runner_ui.show_rnu
	settings.si = vim.deepcopy(split_settings)
	settings.so = vim.deepcopy(split_settings)
	settings.so.diff = true
	settings.se = vim.deepcopy(split_settings)
	settings.eo = vim.deepcopy(split_settings)
	settings.eo.diff = true

	---Get first windows in the given layout
	---@param layout table: layout description
	---@return string: first window name
	local function get_first_window(layout)
		if type(layout[1]) == "table" then -- a list of windows doesn't have number as first element
			return get_first_window(layout[1])
		elseif type(layout[2]) == "table" then
			return get_first_window(layout[2])
		end
		return layout[2]
	end

	---Recursively compute split layout
	---@param layout table: layout description
	---@param winid integer: starting window id
	---@param vertical boolean: whether to proceed vertically or horizontally
	local function create_layout(layout, winid, vertical)
		local dimension = vertical and "height" or "width"
		local total_width = vim.api["nvim_win_get_" .. dimension](winid)

		local layout_width = 0
		for _, l in ipairs(layout) do
			layout_width = layout_width + l[1]
		end

		local windows_sizes = {}
		for i, l in ipairs(layout) do
			windows_sizes[i] = math.floor(total_width * l[1] / layout_width + 0.5)
			if i ~= #layout then -- there's a vertical/horizontal separator for all windows except the last one
				windows_sizes[i] = windows_sizes[i] - 1
			end
		end

		local winfixdim = "winfix" .. dimension
		vim.wo[winid][winfixdim] = false
		local windows_id = { winid }
		for i, l in ipairs(layout) do
			if i ~= 1 then
				local fw = get_first_window(l)
				settings[fw].position = vertical and "bottom" or "right"
				settings[fw].relative.winid = windows_id[i - 1]
				windows[fw] = nui_split(settings[fw])
				windows[fw]:mount()
				windows_id[i] = windows[fw].winid
				vim.wo[windows_id[i]][winfixdim] = false -- unfix current window size
				vim.api["nvim_win_set_" .. dimension](windows_id[i - 1], windows_sizes[i - 1]) -- set previous window size
				vim.wo[windows_id[i - 1]][winfixdim] = true -- fix previous window size
				if settings[fw].diff then
					vim.fn.win_execute(windows_id[i], "diffthis")
				end
			end
		end
		vim.wo[windows_id[#layout]][winfixdim] = true -- fix last window size

		for i, l in ipairs(layout) do
			if type(l[2]) == "table" then
				create_layout(l[2], windows_id[i], not vertical)
			end
		end
	end

	local total_width = vim.api.nvim_win_get_width(init_winid)
	local total_height = vim.api.nvim_win_get_height(init_winid)
	if config.split_ui.relative_to_editor then
		total_width, total_height = require("competitest.utils").get_ui_size()
	end
	total_width = math.floor(total_width * config.split_ui.total_width + 0.5)
	total_height = math.floor(total_height * config.split_ui.total_height + 0.5)

	local is_split_vertical = config.split_ui.position == "left" or config.split_ui.position == "right"
	local current_layout = config.split_ui[(is_split_vertical and "vertical" or "horizontal") .. "_layout"]
	-- create first window
	local fw = get_first_window(current_layout)
	settings[fw].relative = config.split_ui.relative_to_editor and "editor" or { type = "win", winid = init_winid }
	settings[fw].position = config.split_ui.position
	settings[fw].size = is_split_vertical and total_width or total_height
	windows[fw] = nui_split(settings[fw])
	windows[fw]:mount()
	vim.wo[windows[fw].winid]["winfixwidth"] = true
	vim.wo[windows[fw].winid]["winfixheight"] = true

	local old_equalalways = vim.o.equalalways
	vim.o.equalalways = false
	create_layout(current_layout, windows[fw].winid, is_split_vertical)
	vim.o.equalalways = old_equalalways
end

return M
