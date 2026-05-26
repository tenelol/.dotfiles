if vim.fn.has("mac") ~= 1 then
	return
end

local macism = "macism"

if vim.fn.executable(macism) ~= 1 then
	return
end

local default_source = vim.g.nvim_default_input_source or "com.apple.keylayout.ABC"
local restore_source = nil
local group = vim.api.nvim_create_augroup("NvimInputSource", { clear = true })
local notified = false

local function notify_once(message)
	if notified then
		return
	end

	notified = true
	vim.schedule(function()
		vim.notify(message, vim.log.levels.WARN, { title = "input source" })
	end)
end

local function current_source()
	local output = vim.fn.system({ macism })

	if vim.v.shell_error ~= 0 then
		notify_once("macism failed to read the current input source")
		return nil
	end

	return vim.trim(output)
end

local function select_source(source)
	if not source or source == "" then
		return
	end

	local output = vim.fn.system({ macism, source })

	if vim.v.shell_error ~= 0 then
		notify_once(("macism failed to select %s: %s"):format(source, vim.trim(output)))
	end
end

local function switch_to_default()
	local source = current_source()

	if source and source ~= default_source then
		select_source(default_source)
	end
end

local function enter_nvim()
	if not restore_source then
		local source = current_source()

		if source and source ~= default_source then
			restore_source = source
		end
	end

	switch_to_default()
end

local function leave_nvim()
	if restore_source and restore_source ~= "" and current_source() ~= restore_source then
		select_source(restore_source)
	end

	restore_source = nil
end

vim.api.nvim_create_autocmd("VimEnter", {
	group = group,
	callback = enter_nvim,
})

vim.api.nvim_create_autocmd({ "InsertEnter", "CmdlineEnter", "TermEnter" }, {
	group = group,
	callback = switch_to_default,
})

vim.api.nvim_create_autocmd({ "InsertLeave", "CmdlineLeave", "TermLeave" }, {
	group = group,
	callback = switch_to_default,
})

vim.api.nvim_create_autocmd("FocusGained", {
	group = group,
	callback = enter_nvim,
})

vim.api.nvim_create_autocmd({ "FocusLost", "VimLeavePre" }, {
	group = group,
	callback = leave_nvim,
})
