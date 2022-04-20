local luv = vim.loop
local cgc = require("competitest.config").get_config
local testcases = require("competitest.testcases")
local utils = require("competitest.utils")
local M = {}

---Start waiting for competitive companion to send task data and save received testcases
---@param bufnr integer: buffer number
function M.start_receiving(bufnr)
	M.stop_receiving()
	local cfg = cgc(bufnr)
	local message = ""
	M.server = luv.new_tcp()
	M.server:bind("127.0.0.1", cfg.companion_port)
	M.server:listen(128, function(err)
		assert(not err, err)
		M.client = luv.new_tcp()
		M.server:accept(M.client)
		M.client:read_start(function(error, chunk)
			assert(not error, error)
			if chunk then
				message = message .. chunk
			else
				M.stop_receiving()

				message = vim.split(message, "\r\n")
				message = message[#message]
				local task = vim.json.decode(message)

				vim.schedule(function()
					if cfg.receive_print_message then
						utils.notify("testcases received successfully!", "INFO")
					end
					M.store_testcases(bufnr, task.tests, cfg.testcases_use_single_file)
				end)
			end
		end)
	end)

	-- if after 100 seconds nothing happened stop listening
	M.timer = luv.new_timer()
	M.timer:start(100000, 0, function()
		M.stop_receiving()
	end)

	if cfg.receive_print_message then
		utils.notify("ready to receive testcases. Press the green plus button in your browser.", "INFO")
	end
end

---Utility function to store received testcases
---@param bufnr integer: buffer number
---@param tclist table: table containing testcases
---@param use_single_file boolean: whether to store testcases in a single file or not
function M.store_testcases(bufnr, tclist, use_single_file)
	local tctbl = testcases.get_testcases(bufnr)
	if next(tctbl) ~= nil then
		local choice = vim.fn.confirm("Some testcases already exist. Do you want to keep them along the new ones?", "&Keep\n&Replace\n&Cancel")
		if choice == 2 then -- user chose "Replace"
			if not use_single_file then
				for tcnum, _ in pairs(tctbl) do -- delete existing files
					testcases.write_testcase_on_files(bufnr, tcnum)
				end
			end
			tctbl = {}
		elseif choice == 3 then -- user chose "Cancel"
			return
		end
	end

	local tcindex = 0
	for _, tc in ipairs(tclist) do
		while tctbl[tcindex] do
			tcindex = tcindex + 1
		end
		tctbl[tcindex] = tc
		tcindex = tcindex + 1
	end

	if use_single_file then
		testcases.write_testcases_on_single_file(bufnr, tctbl)
	else
		for tcnum, tc in pairs(tctbl) do
			testcases.write_testcase_on_files(bufnr, tcnum, tc.input, tc.output)
		end
	end
end

---Stop listening to competitive companion port
function M.stop_receiving()
	if M.client and not M.client:is_closing() then
		M.client:shutdown()
		M.client:close()
	end
	if M.server and not M.server:is_closing() then
		M.server:shutdown()
		M.server:close()
	end
	if M.timer and not M.timer:is_closing() then
		M.timer:stop()
		M.timer:close()
	end
end

return M
