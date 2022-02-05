local api = vim.api
local luv = vim.loop
local cgc = require("competitest.config").get_config
local utils = require("competitest.utils")
local M = {}

---Get the path where testcases associated with a buffer are kept
---@param bufnr integer: buffer number
---@return string: absolute path of testcases directory
function M.get_testcases_path(bufnr)
	return api.nvim_buf_call(bufnr, function()
		return vim.fn.expand("%:p:h") .. "/" .. cgc(bufnr).testcases_directory .. "/"
	end)
end

---Load testcases from a single msgpack/json encoded file
---@param bufnr integer: buffer number
---@return table: a table of tables made by two strings, input and output
function M.load_testcases_from_single_file(bufnr)
	local tcdir = M.get_testcases_path(bufnr)
	local fpath = tcdir .. utils.eval_string(cgc(bufnr).testcases_single_file_format, 0, "", bufnr)
	local msg = utils.load_file_as_string(fpath) or vim.mpack.encode({})
	return vim.mpack.decode(msg)
end

---Load testcases from sparse input and output files
---@param bufnr integer: buffer number
---@return table: a table of tables made by two strings, input and output
function M.load_testcases_from_files(bufnr)
	local cfg = cgc(bufnr)
	local tcdir = M.get_testcases_path(bufnr)
	local input_match = "^" .. utils.eval_string(cfg.testcases_files_format, "(%d+)", cfg.input_name, bufnr) .. "$"
	local output_match = "^" .. utils.eval_string(cfg.testcases_files_format, "(%d+)", cfg.output_name, bufnr) .. "$"

	---The following function checks if a file belongs to a testcase, and if true returns testcase number
	---It finds all the matches in str, checks if they are all equal and return their value
	---@param str string
	---@param match string
	---@return integer | nil: return testcase number or nil if conditions aren't respected
	local function match_number(str, match)
		local list = { string.match(str, match) }
		local value = list[1]
		for _, v in ipairs(list) do
			if v ~= value then
				return nil
			end
		end
		return tonumber(value)
	end

	local tcs = {} -- testcases
	local dir = assert(luv.fs_opendir(tcdir), "CompetiTest.nvim: get_testcases: cannot open directory '" .. tcdir .. "'")
	while true do -- read all the files in directory
		local entry = luv.fs_readdir(dir)
		if entry == nil then
			break
		end
		if entry[1].type == "file" then
			-- check if the given file is part of a testcase and is an input file
			local tcnum = match_number(entry[1].name, input_match)
			if tcnum then
				if not tcs[tcnum] then
					tcs[tcnum] = {}
				end
				tcs[tcnum].input = utils.load_file_as_string(tcdir .. entry[1].name)
			else
				-- check if the given file is part of a testcase and is an output file
				tcnum = match_number(entry[1].name, output_match)
				if tcnum then
					if not tcs[tcnum] then
						tcs[tcnum] = {}
					end
					tcs[tcnum].output = utils.load_file_as_string(tcdir .. entry[1].name)
				end
			end
		end
	end
	assert(luv.fs_closedir(dir), "CompetiTest.nvim: get_testcases: unable to close '" .. tcdir .. "'")
	return tcs
end

---Load all the testcases associated with the given buffer
---@param bufnr integer: buffer number
---@return table: a table of tables made by two strings, input and output
function M.get_testcases(bufnr)
	if cgc(bufnr).testcases_use_single_file then
		return M.load_testcases_from_single_file(bufnr)
	else
		return M.load_testcases_from_files(bufnr)
	end
end

---Write all the testcases on a single msgpack/json encoded file
---@param bufnr integer: buffer number
---@param tctbl table: a table of tables made by two strings, input and output
function M.write_testcases_on_single_file(bufnr, tctbl)
	for tcnum, tc in pairs(tctbl) do
		if tc.input == "" then
			tc.input = nil
		end
		if tc.output == "" then
			tc.output = nil
		end
		if not tc.input and not tc.output then
			tc = nil
		end
		tctbl[tcnum] = tc
	end

	local tcdir = M.get_testcases_path(bufnr)
	local fpath = tcdir .. utils.eval_string(cgc(bufnr).testcases_single_file_format, 0, "", bufnr)
	if next(tctbl) == nil then
		if utils.does_file_exists(fpath) then
			utils.delete_file(fpath)
		end
	else
		utils.write_string_on_file(fpath, vim.mpack.encode(tctbl))
	end
end

---Write a testcase on input and output file, or delete them if the specified content is empty
---@param bufnr integer: buffer number
---@param tcnum integer: testcase number
---@param input string | nil: input content, or empty string or nil to delete input file
---@param output string | nil: output content, or empty string or nil to delete output file
function M.write_testcase_on_files(bufnr, tcnum, input, output)
	local function update_file(fpath, content)
		if not content or content == "" then
			if utils.does_file_exists(fpath) then
				utils.delete_file(fpath)
			end
		else
			utils.write_string_on_file(fpath, content)
		end
	end

	local cfg = cgc(bufnr)
	local tcdir = M.get_testcases_path(bufnr)
	local input_file = tcdir .. utils.eval_string(cfg.testcases_files_format, tcnum, cfg.input_name, bufnr)
	local output_file = tcdir .. utils.eval_string(cfg.testcases_files_format, tcnum, cfg.output_name, bufnr)
	update_file(input_file, input)
	update_file(output_file, output)
end

return M
