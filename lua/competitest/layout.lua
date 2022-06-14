local api = vim.api
local config = require("competitest.config").get_config
local M = {}

function M.open(layout)
	local conf = config(vim.fn.bufnr())
	local layout = nil
	layout = layout or conf.default_layout
	vim.cmd(conf.layouts[layout].cmd)
	conf.layout = layout
end

function M.toggle()
end

function M.tabline(tcdata)
	local res = "%T%="
	vim.pretty_print(tcdata)
	for i, tc in pairs(tcdata) do
		-- res = 
		-- tc.status = ""
		-- tc.hlgroup = "CompetiTestRunning"
		-- tc.stdout = ""
		-- tc.stderr = ""
		-- tc.running = false
		-- tc.killed = false
		-- tc.time = nil
		res = res .. "%#" .. tc.hlgroup .. "#" .. i .. " "
	end

	vim.o.tabline = res

  -- local res = ""
  -- res = res .. "%#FL#%T%="
  -- for i, v in pairs(s.result) do
  --   res = res .. "%#"
  --   if i == s.curTest then res = res .. "f" end
  --   res = res .. v .. "#"
  --   res = res .. "%" .. i .. "@CpTest@"
  --   res = res .. " " .. i .. " "
  -- end
  -- vim.o.tabline = res
end

function M.update_ui(tcdata)
	local conf = config(vim.fn.bufnr())
	if (conf.layout == "floating") then
		require("competitest.runner_ui")(tcdata)
	else
		M.tabline(tcdata)
	end
end

return M
