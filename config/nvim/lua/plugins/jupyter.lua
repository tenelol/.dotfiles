local plugin = require("nix-plugin")

local function molten_cmd(command)
	return ("<cmd>%s<cr>"):format(command)
end

local function current_buffer_is_ipynb()
	return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":e") == "ipynb"
end

local function code_fence_language(line)
	local language = line:match("^%s*```%s*([^%s`]*)")
	if not language or language == "" then
		return nil
	end

	return language:gsub("^%{", ""):gsub("%}$", "")
end

local function is_closing_code_fence(line)
	return line:match("^%s*```%s*$") ~= nil
end

local function current_markdown_code_cell()
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local cell_start = nil

	for index, line in ipairs(lines) do
		if cell_start then
			if is_closing_code_fence(line) then
				if cell_start <= cursor_line and cursor_line <= index then
					return {
						start_line = cell_start + 1,
						end_line = index - 1,
					}
				end

				cell_start = nil
			end
		elseif code_fence_language(line) then
			cell_start = index
		end
	end

	return nil
end

local function run_current_ipynb_cell()
	local cell = current_markdown_code_cell()
	if not cell then
		vim.notify("No Jupyter code cell under cursor", vim.log.levels.WARN)
		return
	end

	if cell.start_line > cell.end_line then
		vim.notify("Jupyter code cell is empty", vim.log.levels.WARN)
		return
	end

	local ok, err = pcall(vim.fn.MoltenEvaluateRange, cell.start_line, cell.end_line)
	if not ok then
		vim.notify("Jupyter cell execution failed: " .. tostring(err), vim.log.levels.ERROR)
		return
	end

	vim.defer_fn(function()
		pcall(vim.cmd, "MoltenShowOutput")
	end, 100)
end

local function run_current_cell()
	if current_buffer_is_ipynb() then
		run_current_ipynb_cell()
		return
	end

	require("quarto.runner").run_cell()
end

local function setup_notebook_commands()
	local default_notebook = {
		cells = {
			{
				cell_type = "markdown",
				metadata = {},
				source = { "" },
			},
		},
		metadata = {
			kernelspec = {
				display_name = "Python 3",
				language = "python",
				name = "python3",
			},
			language_info = {
				codemirror_mode = { name = "ipython" },
				file_extension = ".py",
				mimetype = "text/x-python",
				name = "python",
				nbconvert_exporter = "python",
				pygments_lexer = "ipython3",
			},
		},
		nbformat = 4,
		nbformat_minor = 5,
	}

	vim.api.nvim_create_user_command("NewNotebook", function(opts)
		local path = opts.args
		if vim.fn.fnamemodify(path, ":e") ~= "ipynb" then
			path = path .. ".ipynb"
		end

		local parent = vim.fn.fnamemodify(path, ":h")
		if parent ~= "" and parent ~= "." then
			vim.fn.mkdir(parent, "p")
		end

		if vim.uv.fs_stat(path) then
			vim.notify("Notebook already exists: " .. path, vim.log.levels.WARN)
			vim.cmd.edit(vim.fn.fnameescape(path))
			return
		end

		vim.fn.writefile({ vim.json.encode(default_notebook) }, path)
		vim.cmd.edit(vim.fn.fnameescape(path))
	end, {
		nargs = 1,
		complete = "file",
		desc = "Create a Python Jupyter notebook",
	})

	vim.api.nvim_create_user_command("JupyterPreview", function()
		vim.cmd("MoltenShowOutput")
	end, {
		desc = "Open current Jupyter output in Neovim",
	})

	vim.api.nvim_create_user_command("JupyterRunCell", function()
		run_current_cell()
	end, {
		desc = "Run current Jupyter cell",
	})
end

local function setup_ipynb_output_sync()
	local function is_ipynb(path)
		return path and vim.fn.fnamemodify(path, ":e") == "ipynb"
	end

	local function event_path(event)
		if event.file and event.file ~= "" then
			return event.file
		end

		return vim.api.nvim_buf_get_name(event.buf)
	end

	local function available_kernel_names()
		local ok, kernels = pcall(vim.fn.MoltenAvailableKernels)
		if not ok then
			return {}
		end

		return kernels
	end

	local function has_value(values, needle)
		for _, value in ipairs(values) do
			if value == needle then
				return true
			end
		end
		return false
	end

	local function notebook_kernel_name(path)
		local file = io.open(path, "r")
		if not file then
			return nil
		end

		local ok, notebook = pcall(vim.json.decode, file:read("*a"))
		file:close()
		if not ok then
			return nil
		end

		local kernelspec = notebook.metadata and notebook.metadata.kernelspec
		return kernelspec and kernelspec.name or nil
	end

	local function import_outputs(event)
		vim.schedule(function()
			local path = event_path(event)
			if not is_ipynb(path) then
				return
			end

			local kernel = notebook_kernel_name(path)
			if not kernel or not has_value(available_kernel_names(), kernel) then
				return
			end

			pcall(vim.cmd, "MoltenInit " .. vim.fn.fnameescape(kernel))
			pcall(vim.cmd, "MoltenImportOutput")
		end)
	end

	local group = vim.api.nvim_create_augroup("JupyterNotebookOutput", { clear = true })

	vim.api.nvim_create_autocmd("BufAdd", {
		group = group,
		pattern = "*.ipynb",
		callback = import_outputs,
	})

	vim.api.nvim_create_autocmd("BufEnter", {
		group = group,
		pattern = "*.ipynb",
		callback = function(event)
			if vim.api.nvim_get_vvar("vim_did_enter") ~= 1 then
				import_outputs(event)
			end
		end,
	})

	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = "markdown",
		callback = function(event)
			import_outputs(event)
		end,
	})

	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		pattern = "*.ipynb",
		callback = function()
			local ok, status = pcall(require, "molten.status")
			if ok and status.initialized() == "Molten" then
				pcall(vim.cmd, "MoltenExportOutput!")
			end
		end,
	})
end

return {
	plugin.spec("image-nvim", {
		lazy = true,
		opts = {
			backend = "kitty",
			processor = "magick_cli",
			integrations = {
				markdown = { enabled = false },
				asciidoc = { enabled = false },
				typst = { enabled = false },
				neorg = { enabled = false },
				syslang = { enabled = false },
				html = { enabled = false },
				css = { enabled = false },
				org = { enabled = false },
			},
			max_width = 100,
			max_height = 20,
			max_height_window_percentage = 60,
			max_width_window_percentage = 100,
			window_overlap_clear_enabled = true,
			window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "snacks_notif", "" },
		},
		config = function(_, opts)
			require("image").setup(opts)
		end,
	}),

	plugin.spec("molten-nvim", {
		cmd = {
			"MoltenDeinit",
			"MoltenDelete",
			"MoltenEnterOutput",
			"MoltenEvaluateLine",
			"MoltenEvaluateOperator",
			"MoltenEvaluateVisual",
			"MoltenExportOutput",
			"MoltenHideOutput",
			"MoltenImportOutput",
			"MoltenInfo",
			"MoltenInit",
			"MoltenReevaluateCell",
			"MoltenRestart",
			"MoltenShowOutput",
		},
		dependencies = {
			plugin.dep("image-nvim"),
		},
		init = function()
			vim.g.molten_auto_open_html_in_browser = false
			vim.g.molten_auto_open_output = true
			vim.g.molten_image_provider = "image.nvim"
			vim.g.molten_image_location = "float"
			vim.g.molten_output_virt_lines = true
			vim.g.molten_output_win_max_height = 20
			vim.g.molten_output_win_max_width = 100
			vim.g.molten_save_path = vim.fn.stdpath("data") .. "/molten"
			vim.g.molten_virt_lines_off_by_1 = true
			vim.g.molten_virt_text_output = false
			vim.g.molten_virt_text_max_lines = 20
			vim.g.molten_wrap_output = true

			setup_notebook_commands()
			setup_ipynb_output_sync()
		end,
		keys = {
			{ "<leader>ji", molten_cmd("MoltenInit"), desc = "Jupyter init kernel" },
			{ "<leader>je", molten_cmd("MoltenEvaluateOperator"), desc = "Jupyter evaluate operator" },
			{ "<leader>jl", molten_cmd("MoltenEvaluateLine"), desc = "Jupyter evaluate line" },
			{ "<leader>jr", molten_cmd("MoltenReevaluateCell"), desc = "Jupyter re-evaluate cell" },
			{ "<leader>jo", molten_cmd("MoltenShowOutput"), desc = "Jupyter show output" },
			{ "<leader>jh", molten_cmd("MoltenHideOutput"), desc = "Jupyter hide output" },
			{ "<leader>jd", molten_cmd("MoltenDelete"), desc = "Jupyter delete cell" },
			{ "<leader>jp", "<cmd>JupyterPreview<cr>", desc = "Jupyter preview output" },
			{
				"<leader>jv",
				":<C-u>MoltenEvaluateVisual<cr>gv",
				mode = "v",
				desc = "Jupyter evaluate selection",
			},
		},
	}),

	plugin.spec("jupytext-nvim", {
		lazy = false,
		config = function()
			require("jupytext").setup({
				style = "markdown",
				output_extension = "md",
				force_ft = "markdown",
			})
		end,
	}),

	plugin.spec("quarto-nvim", {
		ft = { "quarto", "markdown" },
		dependencies = {
			plugin.dep("molten-nvim"),
			plugin.dep("nvim-treesitter"),
			plugin.dep("otter-nvim"),
		},
		opts = {
			lspFeatures = {
				enabled = true,
				chunks = "all",
				languages = { "python", "bash" },
				diagnostics = {
					enabled = true,
					triggers = { "BufWritePost" },
				},
				completion = {
					enabled = true,
				},
			},
			codeRunner = {
				enabled = true,
				default_method = "molten",
			},
		},
		config = function(_, opts)
			require("quarto").setup(opts)

			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("QuartoMarkdownActivation", { clear = true }),
				pattern = "markdown",
				callback = function()
					require("quarto").activate()
				end,
			})
		end,
		keys = {
			{
				"<leader>jc",
				function()
					run_current_cell()
				end,
				desc = "Jupyter run cell",
			},
			{
				"<leader>ja",
				function()
					require("quarto.runner").run_above()
				end,
				desc = "Jupyter run above",
			},
			{
				"<leader>jA",
				function()
					require("quarto.runner").run_all()
				end,
				desc = "Jupyter run all",
			},
			{
				"<leader>jL",
				function()
					require("quarto.runner").run_line()
				end,
				desc = "Jupyter run line",
			},
			{
				"<leader>jV",
				function()
					require("quarto.runner").run_range()
				end,
				mode = "v",
				desc = "Jupyter run selection",
			},
		},
	}),
}
