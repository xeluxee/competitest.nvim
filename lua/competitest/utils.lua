local cgc = require("competitest.config").get_config
local luv = vim.loop
local M = {}

-- buffer dependent modifiers
M.modifiers = {
	-- $(): replace it with a dollar
	[""] = "$",

	-- $(HOME): home user directory
	["HOME"] = function()
		return vim.loop.os_homedir()
	end,

	-- $(FNAME): full file name
	["FNAME"] = function()
		return vim.fn.expand("%:t")
	end,

	-- $(FNOEXT): file name without extension
	["FNOEXT"] = function()
		return vim.fn.expand("%:t:r")
	end,

	-- $(FEXT): file extension
	["FEXT"] = function()
		return vim.fn.expand("%:e")
	end,

	-- $(FTYPE): file type
	["FTYPE"] = function()
		return vim.bo.filetype
	end,

	-- $(FABSPATH): absolute path of current file
	["FABSPATH"] = function()
		return vim.fn.expand("%:p")
	end,

	-- $(FRELPATH): file path, relative to neovim's current working directory
	["FRELPATH"] = function()
		return vim.fn.expand("%")
	end,

	-- $(ABSDIR): absolute path of folder that contains file
	["ABSDIR"] = function()
		return vim.fn.expand("%:p:h")
	end,

	-- $(RELDIR): path of folder that contains file, relative to neovim's current working directory
	["RELDIR"] = function()
		return vim.fn.expand("%:h")
	end,

	-- $(TCNUM): testcase number; it will be set later
	["TCNUM"] = nil,

	-- $(INOUT): whether it's an input or output testcase; it will be set later
	["INOUT"] = nil,
}

---Convert a string with dollars into a real string
---@param str string: the string to evaluate
---@param tcnum integer | string: test case number or identifier
---@param inout string: input or output file
---@param bufnr integer | nil: number representing the buffer in which the function should be executed
---@return string | nil: the converted string, or nil if it failed
function M.eval_string(str, tcnum, inout, bufnr)
	bufnr = bufnr or vim.fn.bufnr()
	M.modifiers["TCNUM"] = tostring(tcnum) -- testcase number
	M.modifiers["INOUT"] = inout -- whether this file represents input or output

	local evaluated_str = ""
	local mod_start = 0 -- modifier starting position (0 means idle state)
	for i = 1, #str do
		local c = string.sub(str, i, i) -- current character
		if mod_start == -1 then -- if mod_start is -1 an opening parentheses is expected because a dollar was just encountered
			if c == "(" then
				mod_start = i
			else
				vim.notify("CompetiTest.nvim: eval_string: '$' isn't followed by '(' in the following string!\n" .. str, vim.log.levels.ERROR)
				return nil
			end
		elseif mod_start == 0 then
			if c == "$" then
				mod_start = -1 -- wait for parentheses
			else
				evaluated_str = evaluated_str .. c
			end
		elseif mod_start ~= 0 and c == ")" then
			local mod = string.sub(str, mod_start + 1, i - 1)
			local rep = M.modifiers[mod] -- replacement
			if type(rep) == "string" then
				evaluated_str = evaluated_str .. rep
			elseif type(rep) == "function" then
				evaluated_str = evaluated_str .. vim.api.nvim_buf_call(bufnr, rep)
			else
				vim.notify("CompetiTest.nvim: eval_string: unrecognized modifier $(" .. mod .. ")", vim.log.levels.ERROR)
				return nil
			end
			mod_start = 0
		end
	end

	M.modifiers["TCNUM"] = nil
	M.modifiers["INOUT"] = nil
	return evaluated_str
end

---Return true if the given file exists, otherwise false
---@param filepath string
---@return boolean
function M.does_file_exists(filepath)
	local fd = luv.fs_open(filepath, "r", 438)
	if fd == nil then
		return false
	else
		assert(luv.fs_close(fd), "CompetiTest.nvim: does_file_exists: unable to close '" .. filepath .. "'")
		return true
	end
end

---This function returns the content of the specified file as a string, or nil if the given path is invalid
---@param filepath string
---@return string | nil
function M.load_file_as_string(filepath)
	local fd = luv.fs_open(filepath, "r", 438)
	if fd == nil then
		return nil
	end
	local stat = assert(luv.fs_fstat(fd), "CompetiTest.nvim: load_file_as_string: cannot stat file '" .. filepath .. "'")
	local content = assert(luv.fs_read(fd, stat.size, 0), "CompetiTest.nvim: load_file_as_string: cannot read file '" .. filepath .. "'")
	assert(luv.fs_close(fd), "CompetiTest.nvim: load_file_as_string: unable to close '" .. filepath .. "'")
	return string.gsub(content, "\r\n", "\n") -- convert CRLF to LF
end

---Write the content of the given string on the given file
---@param filepath string
---@param content string
function M.write_string_on_file(filepath, content)
	local fd = assert(luv.fs_open(filepath, "w", 420), "CompetiTest.nvim: write_string_on_file: cannot open file '" .. filepath .. "'")
	assert(luv.fs_write(fd, content, 0), "CompetiTest.nvim: write_string_on_file: cannot write on file '" .. filepath .. "'")
	assert(luv.fs_close(fd), "CompetiTest.nvim: write_string_on_file: unable to close '" .. filepath .. "'")
end

---Delete the given file
---@param filepath string
function M.delete_file(filepath)
	assert(luv.fs_unlink(filepath), "CompetiTest.nvim: delete_file: cannot delete file '" .. filepath .. "'")
end

---Get the path where testcases associated with a buffer are kept
---@param bufnr integer: buffer number
---@return string: absolute path of testcases directory
function M.get_testcases_path(bufnr)
	return vim.api.nvim_buf_call(bufnr, function()
		return vim.fn.expand("%:p:h") .. "/" .. cgc(bufnr).testcases_directory .. "/"
	end)
end

---Get filenames of all the testcases associated with the given buffer
---@param bufnr integer: buffer number
---@return table
function M.get_testcases(bufnr)
	local tcdir = M.get_testcases_path(bufnr)
	local dir = assert(luv.fs_opendir(tcdir), "CompetiTest.nvim: get_testcases_in_directory: cannot open directory '" .. tcdir .. "'")
	local input_match = "^" .. M.eval_string(cgc(bufnr).testcases_files_format, "(%d+)", cgc(bufnr).input_name, bufnr) .. "$"
	local output_match = "^" .. M.eval_string(cgc(bufnr).testcases_files_format, "(%d+)", cgc(bufnr).output_name, bufnr) .. "$"
	local tcs = {} -- testcases

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
				tcs[tcnum].input = entry[1].name
			else
				-- check if the given file is part of a testcase and is an output file
				tcnum = match_number(entry[1].name, output_match)
				if tcnum then
					if not tcs[tcnum] then
						tcs[tcnum] = {}
					end
					tcs[tcnum].output = entry[1].name
				end
			end
		end
	end
	assert(luv.fs_closedir(dir), "CompetiTest.nvim: get_testcases_in_directory: unable to close '" .. tcdir .. "'")
	return tcs
end

---Get the content (input and output) of the N-th testcase associated with a buffer
---@param bufnr integer: buffer number
---@param tcnum integer: testcase number
---@param only_filename boolean: if true absolute path won't be included in input_file and output_file
---@return table: a table with five fields (input_file, output_file, input, output and exists) is returned
function M.get_nth_testcase(bufnr, tcnum, only_filename)
	local tc = {}
	local tcdir = M.get_testcases_path(bufnr)
	tc.input_file = M.eval_string(cgc(bufnr).testcases_files_format, tcnum, cgc(bufnr).input_name, bufnr)
	tc.output_file = M.eval_string(cgc(bufnr).testcases_files_format, tcnum, cgc(bufnr).output_name, bufnr)
	tc.input = M.load_file_as_string(tcdir .. tc.input_file)
	tc.output = M.load_file_as_string(tcdir .. tc.output_file)
	if not only_filename then
		tc.input_file = tcdir .. tc.input_file
		tc.output_file = tcdir .. tc.output_file
	end
	tc.exists = true
	if not tc.input and not tc.output then
		tc.exists = false
	end
	return tc
end

---Get the first non-existing testcase number, counting from 0
---@param bufnr integer: buffer number
---@return integer: testcase number
function M.get_first_free_testcase(bufnr)
	local tcnum = 0
	while true do
		local tc = M.get_nth_testcase(bufnr, tcnum)
		if not tc.exists then
			return tcnum
		end
		tcnum = tcnum + 1
	end
end

---Get Neovim UI width and height
---@return integer: width, number of columns
---@return integer: height, number of rows
function M.get_ui_size()
	local height = vim.o.lines - vim.o.cmdheight
	if vim.o.laststatus ~= 0 then
		height = height - 1
	end
	return vim.o.columns, height
end

return M
