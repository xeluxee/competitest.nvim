local api = vim.api
local config = require("competitest.config").get_config
local M = {}

function M:open()
  local cur_win = api.nvim_get_current_win()
end

function M.show(layout)
	local conf = config(vim.fn.bufnr())
	local layout = nil
	layout = layout or conf.default_layout
	vim.cmd(conf.layouts[layout].cmd)
end

return M
