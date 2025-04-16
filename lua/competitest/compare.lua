local utils = require("competitest.utils")
local M = {}

---@alias competitest.Compare.method fun(output: string, expected_output: string): boolean function accepting two string arguments, `output` and `expected_output`, and returning `true` if and only if `output` is correct

---@alias competitest.Compare.builtin_method # builtin method to compare output and expected output
---| "exact" character-by-character comparison
---| "squish" compare stripping duplicated or extra white spaces and newlines

---Builtin methods to compare output and expected output
---@type table<competitest.Compare.builtin_method, competitest.Compare.method>
M.methods = {
	exact = function(output, expout)
		return output == expout
	end,

	squish = function(output, expout)
		local function squish_string(str)
			str = string.gsub(str, "\n", " ")
			str = string.gsub(str, "%s+", " ")
			str = string.gsub(str, "^%s", "")
			str = string.gsub(str, "%s$", "")
			return str
		end
		output = squish_string(output)
		expout = squish_string(expout)
		return output == expout
	end,
}

---Compare output and expected output to determine if they can match
---@param output string program output
---@param expected_output string? expected result, or `nil` when it isn't provided
---@param method competitest.Compare.builtin_method | competitest.Compare.method
---@return boolean? # `true` if output matches expected output, `false` if they don't match, `nil` if `expected_output` is `nil`
function M.compare_output(output, expected_output, method)
	if expected_output == nil then
		return nil
	end

	if type(method) == "string" and M.methods[method] then
		return M.methods[method](output, expected_output)
	elseif type(method) == "function" then
		return method(output, expected_output)
	else
		vim.schedule(function()
			utils.notify("compare_output: unrecognized method '" .. vim.inspect(method) .. "'")
		end)
	end
end

return M
