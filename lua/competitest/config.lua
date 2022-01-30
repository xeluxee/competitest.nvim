local competitest = require("competitest")
local utils = require("competitest.utils")
local M = {}

-- Table to store buffer configs
M.buf_configs = {}

---Load buffer specific configuration and store it in M.buf_configs
---@param bufnr integer
function M.load_buffer_config(bufnr)
	local local_config

	local dir = vim.api.nvim_buf_call(bufnr, function()
		return vim.fn.expand("%:p:h")
	end)
	local prev_len = #dir
	while not local_config do
		local config_file = dir .. "/" .. competitest.current_setup.local_config_file_name
		if utils.does_file_exists(config_file) then
			local_config = dofile(config_file)
			if type(local_config) ~= "table" then
				vim.notify("CompetiTest.nvim: load_buffer_config: '" .. config_file .. "' doesn't return a table.", vim.log.levels.ERROR)
			end
		end
		dir = vim.fn.fnamemodify(dir, ":h")
		if prev_len == #dir then
			break
		end
		prev_len = #dir
	end

	M.buf_configs[bufnr] = competitest.update_config_table(competitest.current_setup, local_config)
end

---Get buffer configuration
---@param bufnr integer: buffer number
---@return table: a table with buffer configuration
function M.get_config(bufnr)
	if not M.buf_configs[bufnr] then
		M.load_buffer_config(bufnr)
	end
	return M.buf_configs[bufnr]
end

return M
