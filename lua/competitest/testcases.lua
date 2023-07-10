local luv = vim.loop
local gbc = require("competitest.config").get_buffer_config
local utils = require("competitest.utils")
local M = {
	single_file = {}, -- methods for loading/writing testcases, for single msgpack-encoded file
	io_files = {}, -- methods for loading/writing testcases, for pairs of input and output files
}

---------------- NORMAL METHODS ----------------

---Load testcases from a single msgpack-encoded file
---@param filepath string
---@return table: testcases table, a table made by pairs of input and output strings. If the given file doesn't exist return an empty table
function M.single_file.load(filepath)
	local msg = utils.load_file_as_string(filepath) or vim.mpack.encode({})
	return vim.mpack.decode(msg)
end

---Write testcases on a single msgpack-encoded file, or delete it if the given table is empty
---@param filepath string
---@param tctbl table: testcases table, a table made by pairs of input and output strings
function M.single_file.write(filepath, tctbl)
	for tcnum, tc in pairs(tctbl) do
		if tc.input == "" then
			tc.input = nil
		end
		if tc.output == "" then
			tc.output = nil
		end
		if not tc.input and not tc.output then
			tctbl[tcnum] = nil
		end
	end

	if next(tctbl) == nil then
		if utils.does_file_exist(filepath) then
			utils.delete_file(filepath)
		end
	else
		utils.write_string_on_file(filepath, vim.mpack.encode(tctbl))
	end
end

---Load testcases from all the pairs of input and output files
---@param directory string: directory where testcases files are stored
---@param input_file_match string: lua pattern-match string for input file, using (%d+) to match testcase number
---@param output_file_match string: lua pattern-match string for output file, using (%d+) to match testcase number
---@return table: testcases table, a table made by pairs of input and output strings
function M.io_files.load(directory, input_file_match, output_file_match)
	---The following function checks if a file belongs to a testcase, and if true returns testcase number
	---It finds all the matches, checks if they are all equal and return their value
	---@param filename string
	---@param match string
	---@return integer | nil: return testcase number or nil if there's no match
	local function match_number(filename, match)
		local list = { string.match(filename, match) }
		local value = list[1]
		for _, v in ipairs(list) do
			if v ~= value then
				return nil
			end
		end
		return tonumber(value)
	end

	local dir = luv.fs_opendir(directory)
	if not dir then
		return {}
	end

	local tctbl = {} -- testcases
	while true do -- read all the files in directory
		local entry = luv.fs_readdir(dir)
		if entry == nil then
			break
		end
		if entry[1].type == "file" then
			-- check if the given file is part of a testcase and is an input file
			local tcnum = match_number(entry[1].name, input_file_match)
			if tcnum then
				if not tctbl[tcnum] then
					tctbl[tcnum] = {}
				end
				tctbl[tcnum].input = utils.load_file_as_string(directory .. entry[1].name)
			else
				-- check if the given file is part of a testcase and is an output file
				tcnum = match_number(entry[1].name, output_file_match)
				if tcnum then
					if not tctbl[tcnum] then
						tctbl[tcnum] = {}
					end
					tctbl[tcnum].output = utils.load_file_as_string(directory .. entry[1].name)
				end
			end
		end
	end
	assert(luv.fs_closedir(dir), "CompetiTest.nvim: io_files.load: unable to close '" .. directory .. "'")
	return tctbl
end

---Write testcases on pairs of input and output files
---@param directory string: directory where testcases files will be stored
---@param tctbl table: testcases table, a table made by pairs of input and output strings
---@param input_file_format string: format for naming input files, using %d to specify testcase number
---@param output_file_format string: format for naming output files, using %d to specify testcase number
function M.io_files.write(directory, tctbl, input_file_format, output_file_format)
	local function write_file(fpath, content)
		if not content or content == "" then
			if utils.does_file_exist(fpath) then
				utils.delete_file(fpath)
			end
		else
			utils.write_string_on_file(fpath, content)
		end
	end

	for tcnum, tc in pairs(tctbl) do
		local input_file = directory .. string.format(input_file_format, tcnum)
		local output_file = directory .. string.format(output_file_format, tcnum)
		write_file(input_file, tc.input)
		write_file(output_file, tc.output)
	end
end

---Load testcases from all the pairs of input and output files, using strings with CompetiTest file-format modifiers to determine input and output files name
---@param directory string: directory where testcases files are stored
---@param filepath string: absolute path of file to which testcases belong, used to evaluate format string
---@param input_file_format string: string with CompetiTest file-format modifiers to match input files name
---@param output_file_format string: string with CompetiTest file-format modifiers to match output files name
---@return table: testcases table, a table made by pairs of input and output strings
function M.io_files.load_eval_format_string(directory, filepath, input_file_format, output_file_format)
	local function compute_match(format)
		local format_string_parts = vim.split(format, "$(TCNUM)", { plain = true })
		for index, str in ipairs(format_string_parts) do
			str = utils.eval_string(filepath, str)
			if not str then
				return nil
			end
			str = string.gsub(str, "([^%w])", "%%%1") -- escape pattern magic characters
			format_string_parts[index] = str
		end
		return "^" .. table.concat(format_string_parts, "(%d+)") .. "$"
	end

	input_file_format = compute_match(input_file_format)
	output_file_format = compute_match(output_file_format)
	if not input_file_format or not output_file_format then
		return {} -- bad formatting
	end
	return M.io_files.load(directory, input_file_format, output_file_format)
end

---Write testcases on pairs of input and output files, using strings with CompetiTest file-format modifiers to determine input and output files name
---@param directory string: directory where testcases files will be stored
---@param tctbl table: testcases table, a table made by pairs of input and output strings
---@param filepath string: absolute path of file to which testcases belong, used to evaluate format string
---@param input_file_format string: string with CompetiTest file-format modifiers to match input files name
---@param output_file_format string: string with CompetiTest file-format modifiers to match output files name
function M.io_files.write_eval_format_string(directory, tctbl, filepath, input_file_format, output_file_format)
	local function compute_format(format)
		local format_string_parts = vim.split(format, "$(TCNUM)", { plain = true })
		for index, str in ipairs(format_string_parts) do
			str = utils.eval_string(filepath, str)
			if not str then
				return nil
			end
			str = string.gsub(str, "%%", "%%%%") -- escape percent sign
			format_string_parts[index] = str
		end
		return table.concat(format_string_parts, "%d")
	end

	input_file_format = compute_format(input_file_format)
	output_file_format = compute_format(output_file_format)
	if not input_file_format or not output_file_format then
		return -- bad formatting
	end
	M.io_files.write(directory, tctbl, input_file_format, output_file_format)
end

---------------- BUFFER METHODS ----------------

---Get the path where testcases associated with a buffer are kept
---@param bufnr integer: buffer number
---@return string: absolute path of testcases directory
local function buf_get_testcases_path(bufnr)
	return vim.api.nvim_buf_call(bufnr, function()
		return vim.fn.expand("%:p:h") .. "/" .. gbc(bufnr).testcases_directory .. "/"
	end)
end

---Load testcases from a single msgpack-encoded file associated with the given buffer
---@param bufnr integer: buffer number
---@return table: testcases table, a table made by pairs of input and output strings. If the given file doesn't exist return an empty table
function M.single_file.buf_load(bufnr)
	local filepath = buf_get_testcases_path(bufnr) .. utils.buf_eval_string(bufnr, gbc(bufnr).testcases_single_file_format, nil)
	return M.single_file.load(filepath)
end

---Write testcases on a single msgpack-encoded file associated with the given buffer, or delete it if the given table is empty
---@param bufnr integer: buffer number
---@param tctbl table: testcases table, a table made by pairs of input and output strings
function M.single_file.buf_write(bufnr, tctbl)
	local filepath = buf_get_testcases_path(bufnr) .. utils.buf_eval_string(bufnr, gbc(bufnr).testcases_single_file_format, nil)
	M.single_file.write(filepath, tctbl)
end

---Load testcases from all the pairs of input and output files associated with the given buffer
---@param bufnr integer: buffer number
---@return table: testcases table, a table made by pairs of input and output strings
function M.io_files.buf_load(bufnr)
	return M.io_files.load_eval_format_string(
		buf_get_testcases_path(bufnr),
		vim.api.nvim_buf_get_name(bufnr),
		gbc(bufnr).testcases_input_file_format,
		gbc(bufnr).testcases_output_file_format
	)
end

---Write testcases on pairs of input and output files associated with the given buffer
---@param bufnr integer: buffer number
---@param tctbl table: testcases table, a table made by pairs of input and output strings
function M.io_files.buf_write(bufnr, tctbl)
	M.io_files.write_eval_format_string(
		buf_get_testcases_path(bufnr),
		tctbl,
		vim.api.nvim_buf_get_name(bufnr),
		gbc(bufnr).testcases_input_file_format,
		gbc(bufnr).testcases_output_file_format
	)
end

---Write a single testcase on a pair of input and output files associated with the given buffer
---@param bufnr integer: buffer number
---@param tcnum integer | string: testcase number or identifier
---@param input string | nil: input content, or empty string or nil to delete input file
---@param output string | nil: output content, or empty string or nil to delete output file
function M.io_files.buf_write_pair(bufnr, tcnum, input, output)
	M.io_files.buf_write(bufnr, { [tcnum] = { input = input, output = output } })
end

---------------- MISCELLANEOUS METHODS ----------------

---Load all the testcases associated with the given buffer, from single msgpack-encoded file or from pairs of input and output files
---@param bufnr integer: buffer number
---@return table: a table of tables made by two strings, input and output
function M.buf_get_testcases(bufnr)
	local loader1 = M.io_files.buf_load
	local loader2 = M.single_file.buf_load
	if gbc(bufnr).testcases_use_single_file then
		loader1, loader2 = loader2, loader1
	end

	local tctbl = loader1(bufnr)
	if next(tctbl) == nil and gbc(bufnr).testcases_auto_detect_storage then
		tctbl = loader2(bufnr)
	end
	return tctbl
end

---Write testcases on single msgpack-encoded file or on pairs of input and output files associated with the given buffer
---@param bufnr integer: buffer number
---@param tctbl table: testcases table, a table made by pairs of input and output strings
---@param use_single_file boolean | nil: whether to store testcases in a single file or not. When nil use the storage method specified in testcases_use_single_file
function M.buf_write_testcases(bufnr, tctbl, use_single_file)
	if use_single_file == nil then -- use storage methods specified in testcases_use_single_file
		use_single_file = gbc(bufnr).testcases_use_single_file
	end

	if use_single_file then
		M.single_file.buf_write(bufnr, tctbl)
	else
		M.io_files.buf_write(bufnr, tctbl)
	end
end

return M
