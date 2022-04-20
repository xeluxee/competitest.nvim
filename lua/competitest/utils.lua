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

---Show a CompetiTest notification with vim.notify
---@param msg string: message to display
---@param log_level string | nil: a log level among the ones available in vim.log.levels. When nil it defaults to ERROR
function M.notify(msg, log_level)
	vim.notify("CompetiTest.nvim: " .. msg, vim.log.levels[log_level or "ERROR"], { title = "CompetiTest" })
end

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
				M.notify("eval_string: '$' isn't followed by '(' in the following string!\n" .. str)
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
				M.notify("eval_string: unrecognized modifier $(" .. mod .. ")")
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

---Create the specified directory if it doesn't exist
---@param dirpath string: directory absolute path
function M.create_directory(dirpath)
	if not luv.fs_opendir(dirpath) then
		dirpath = string.gsub(dirpath, "[/\\]+$", "") -- trim trailing slashes
		local upper_dir = vim.fn.fnamemodify(dirpath, ":h")
		if upper_dir ~= dirpath then
			M.create_directory(upper_dir)
		end
		assert(luv.fs_mkdir(dirpath, 493), "CompetiTest.nvim: create_directory: cannot create directory '" .. dirpath .. "'")
	end
end

---Write the content of the given string on a file
---@param filepath string
---@param content string
function M.write_string_on_file(filepath, content)
	M.create_directory(vim.fn.fnamemodify(filepath, ":h"))
	local fd = assert(luv.fs_open(filepath, "w", 420), "CompetiTest.nvim: write_string_on_file: cannot open file '" .. filepath .. "'")
	assert(luv.fs_write(fd, content, 0), "CompetiTest.nvim: write_string_on_file: cannot write on file '" .. filepath .. "'")
	assert(luv.fs_close(fd), "CompetiTest.nvim: write_string_on_file: unable to close '" .. filepath .. "'")
end

---Delete the given file
---@param filepath string
function M.delete_file(filepath)
	assert(luv.fs_unlink(filepath), "CompetiTest.nvim: delete_file: cannot delete file '" .. filepath .. "'")
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
