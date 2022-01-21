local setup = require("competitest").current_setup
local M = {}

-- Table to store buffer configs
M.buf_configs = {}

---Return true if the given file exists, otherwise false
---@param filepath string
---@return boolean
local function does_file_exists(filepath)
	local fd = vim.loop.fs_open(filepath, "r", 438)
	if fd == nil then
		return false
	else
		assert(vim.loop.fs_close(fd), "CompetiTest.nvim: does_file_exists: unable to close '" .. filepath .. "'")
		return true
	end
end

---Load buffer specific configuration and store it in M.buf_configs
---@param bufnr integer
function M.load_buf_config(bufnr)
	M.buf_configs[bufnr] = setup
	local dir = vim.api.nvim_buf_call(bufnr, function()
		return vim.fn.expand("%:p:h")
	end)
	local prev_len = #dir
	while true do
		local config_file = dir .. "/" .. setup.local_config_file_name
		if does_file_exists(config_file) then
			local local_config = dofile(config_file)
			if type(local_config) == "table" then
				M.buf_configs[bufnr] = vim.tbl_deep_extend("force", M.buf_configs[bufnr], dofile(config_file))
			else
				vim.notify("CompetiTest.nvim: load_buf_config: '" .. config_file .. "' doesn't return a table.", vim.log.levels.ERROR)
			end
			return
		end
		dir = vim.fn.fnamemodify(dir, ":h")
		if prev_len == #dir then
			return
		end
		prev_len = #dir
	end
end

---Get an options from buffer configuration
---@param bufnr integer: buffer number
---@return table: a table with buffer configuration
function M.get_config(bufnr)
	if not M.buf_configs[bufnr] then
		M.load_buf_config(bufnr)
	end
	return M.buf_configs[bufnr]
end

return M
