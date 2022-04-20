local utils = require("competitest.utils")
local M = {}

-- Methods to determine if result is correct
-- They accepts two arguments, output and expected output
-- A boolean value is returned, true if the output is acceptable, false otherwise
M.methods = {
	-- exact: byte-byte comparison
	["exact"] = function(output, expout)
		return output == expout
	end,

	-- squish: ignore duplicates newlines and spaces when comparing
	["squish"] = function(output, expout)
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
---@param output string: program's output
---@param expected_output string: expected result
---@param method string | function: can be "exact", "squish" or a custom function that receives two arguments
---@return boolean | nil: true if output matches expected output. Returns nil if there's no expected output to compare
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
