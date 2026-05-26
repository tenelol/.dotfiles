if vim.fn.has("mac") ~= 1 then
	return
end

local macism = "macism"

if vim.fn.executable(macism) ~= 1 then
	return
end

local default_source = vim.g.nvim_default_input_source or "com.apple.keylayout.ABC"
local insert_source = vim.g.nvim_insert_input_source or "net.mtgto.inputmethod.macSKK.ascii"
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

local function remember_insert_source(source)
	if source and source ~= "" and source ~= default_source then
		insert_source = source
	end
end

local function switch_to_default(remember_current)
	local source = current_source()

	if remember_current then
		remember_insert_source(source)
	end

	if source and source ~= default_source then
		select_source(default_source)
	end
end

local function is_insert_like_mode()
	local mode = vim.api.nvim_get_mode().mode
	local first = mode:sub(1, 1)

	return first == "i" or first == "R"
end

vim.api.nvim_create_autocmd("VimEnter", {
	group = group,
	callback = function()
		switch_to_default(false)
	end,
})

vim.api.nvim_create_autocmd("InsertEnter", {
	group = group,
	callback = function()
		if insert_source and current_source() ~= insert_source then
			select_source(insert_source)
		end
	end,
})

vim.api.nvim_create_autocmd("InsertLeave", {
	group = group,
	callback = function()
		switch_to_default(true)
	end,
})

vim.api.nvim_create_autocmd("FocusGained", {
	group = group,
	callback = function()
		if not is_insert_like_mode() then
			switch_to_default(false)
		end
	end,
})
