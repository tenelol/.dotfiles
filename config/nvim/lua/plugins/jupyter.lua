local plugin = require("nix-plugin")

local function molten_cmd(command)
	return ("<cmd>%s<cr>"):format(command)
end

local function current_buffer_is_ipynb()
	return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":e") == "ipynb"
end

local function available_kernel_names()
	local ok, kernels = pcall(vim.fn.MoltenAvailableKernels)
	if not ok then
		return {}
	end

	return kernels
end

local function running_buffer_kernel_ids()
	local ok, kernels = pcall(vim.fn.MoltenRunningKernels, true)
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

local function preferred_kernel_name()
	local available = available_kernel_names()
	local path = vim.api.nvim_buf_get_name(0)
	local kernel = notebook_kernel_name(path)

	if kernel and has_value(available, kernel) then
		return kernel
	end
	if has_value(available, "python3") then
		return "python3"
	end

	return available[1]
end

local function init_current_buffer_kernel()
	local running = running_buffer_kernel_ids()
	if #running > 0 then
		return running[1]
	end

	local kernel = preferred_kernel_name()
	if not kernel then
		vim.notify("No Jupyter kernel is available", vim.log.levels.ERROR)
		return nil
	end

	local ok, err = pcall(vim.cmd, "MoltenInit " .. vim.fn.fnameescape(kernel))
	if not ok then
		vim.notify("Jupyter kernel init failed: " .. tostring(err), vim.log.levels.ERROR)
		return nil
	end

	local initialized = running_buffer_kernel_ids()
	return initialized[#initialized] or kernel
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

local function evaluate_ipynb_cell(cell, kernel_id)
	local end_line = vim.api.nvim_buf_get_lines(0, cell.end_line - 1, cell.end_line, false)[1] or ""
	local ok, err = pcall(vim.fn.MoltenEvaluateRange, kernel_id, cell.start_line, cell.end_line, 1, #end_line + 1)
	if not ok then
		vim.notify("Jupyter cell execution failed: " .. tostring(err), vim.log.levels.ERROR)
		return false
	end

	vim.defer_fn(function()
		pcall(vim.cmd, "MoltenShowOutput")
	end, 100)

	return true
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

	local running = running_buffer_kernel_ids()
	if #running > 0 then
		evaluate_ipynb_cell(cell, running[1])
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local pending = true
	local group = vim.api.nvim_create_augroup("JupyterKernelReadyRun", { clear = false })

	local function with_notebook_buffer(callback)
		if not vim.api.nvim_buf_is_valid(bufnr) then
			pending = false
			return nil
		end

		return vim.api.nvim_buf_call(bufnr, callback)
	end

	local function evaluate_when_ready()
		if not pending then
			return
		end

		pending = false
		with_notebook_buffer(function()
			local kernels = running_buffer_kernel_ids()
			if #kernels == 0 then
				vim.notify("Jupyter kernel did not become available", vim.log.levels.ERROR)
				return
			end

			evaluate_ipynb_cell(cell, kernels[#kernels])
		end)
	end

	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "MoltenKernelReady",
		callback = function(event)
			if not vim.api.nvim_buf_is_valid(bufnr) then
				pending = false
				return true
			end

			local kernel_id = event.data and event.data.kernel_id
			local matched = with_notebook_buffer(function()
				return not kernel_id or has_value(running_buffer_kernel_ids(), kernel_id)
			end)
			if matched then
				evaluate_when_ready()
				return true
			end

			return false
		end,
	})

	local kernel = init_current_buffer_kernel()
	if not kernel then
		pending = false
		return
	end

	vim.notify("Jupyter kernel is starting; cell will run when ready", vim.log.levels.INFO)
end

local function run_current_cell()
	if current_buffer_is_ipynb() then
		run_current_ipynb_cell()
		return
	end

	require("quarto.runner").run_cell()
end

local function current_notebook_path()
	local path = vim.api.nvim_buf_get_name(0)
	if path == "" then
		vim.notify("Current buffer has no file path", vim.log.levels.ERROR)
		return nil
	end

	if vim.fn.fnamemodify(path, ":e") ~= "ipynb" then
		vim.notify("Current file is not an ipynb notebook", vim.log.levels.WARN)
		return nil
	end

	return path
end

local function remove_remote_html_scripts(path)
	local lines = vim.fn.readfile(path)
	local html = table.concat(lines, "\n")
	local cleaned = html
	cleaned = cleaned:gsub('<script src=""></script>', "")
	cleaned = cleaned:gsub(
		'<script type="module">%s*import mermaid from .-cdnjs%.cloudflare%.com.-;%s*mermaid%.initialize%b()%s*;?%s*</script>',
		""
	)

	if cleaned ~= html then
		vim.fn.writefile(vim.split(cleaned, "\n", { plain = true }), path)
	end
end

local function export_current_notebook_html(opts)
	local path = current_notebook_path()
	if not path then
		return
	end

	if vim.bo.modified then
		vim.cmd("silent write")
	end

	local output_dir = opts.args
	local output_path
	if output_dir and output_dir ~= "" then
		if not vim.startswith(output_dir, "/") then
			output_dir = vim.fs.normalize(vim.fn.getcwd() .. "/" .. output_dir)
		else
			output_dir = vim.fs.normalize(output_dir)
		end

		vim.fn.mkdir(output_dir, "p")
		output_path = vim.fs.joinpath(output_dir, vim.fn.fnamemodify(path, ":t:r") .. ".html")
	else
		output_path = vim.fn.fnamemodify(path, ":r") .. ".html"
	end

	local cmd = {
		"jupyter",
		"nbconvert",
		"--to",
		"html",
		"--template",
		"classic",
		"--embed-images",
		"--HTMLExporter.require_js_url=",
		"--HTMLExporter.mathjax_url=",
		"--HTMLExporter.jquery_url=",
		"--HTMLExporter.jupyter_widgets_base_url=",
		path,
	}
	if output_dir and output_dir ~= "" then
		vim.list_extend(cmd, { "--output-dir", output_dir })
	end

	local result = vim.system(cmd):wait()
	if result.code == 0 then
		remove_remote_html_scripts(output_path)
		vim.notify(("Exported notebook HTML: %s"):format(output_path), vim.log.levels.INFO)
		return
	end

	local message = result.stderr ~= "" and result.stderr or "Notebook HTML export failed"
	vim.notify(message, vim.log.levels.ERROR)
end

local function setup_jupytext_metadata_fallback()
	local ok, utils = pcall(require, "jupytext.utils")
	if not ok then
		return
	end

	local language_extensions = {
		python = "py",
		python3 = "py",
		julia = "jl",
		r = "r",
		R = "r",
		bash = "sh",
	}
	local language_names = {
		python3 = "python",
	}

	utils.get_ipynb_metadata = function(filename)
		local file = io.open(filename, "r")
		if not file then
			return { language = "python", extension = "py" }
		end

		local ok_decode, notebook = pcall(vim.json.decode, file:read("*a"))
		file:close()
		if not ok_decode or type(notebook) ~= "table" then
			return { language = "python", extension = "py" }
		end

		local metadata = notebook.metadata or {}
		local kernelspec = metadata.kernelspec or {}
		local language_info = metadata.language_info or {}
		local language = kernelspec.language or language_info.name or language_names[kernelspec.name] or "python"
		local extension = language_extensions[language] or language_info.file_extension or "py"
		extension = extension:gsub("^%.", "")

		return { language = language, extension = extension }
	end
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

	vim.api.nvim_create_user_command("IpynbHtml", export_current_notebook_html, {
		nargs = "?",
		complete = "dir",
		desc = "Export current ipynb notebook to HTML",
	})
end

local function setup_ipynb_output_sync()
	local function is_ipynb(path)
		return path and vim.fn.fnamemodify(path, ":e") == "ipynb"
	end

	local group = vim.api.nvim_create_augroup("JupyterNotebookOutput", { clear = true })

	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		pattern = "*.ipynb",
		callback = function(event)
			if not is_ipynb(event.file) then
				return
			end

			local ok, status = pcall(require, "molten.status")
			if ok and status.initialized() == "Molten" then
				local kernels = running_buffer_kernel_ids()
				if #kernels > 0 then
					pcall(
						vim.cmd,
						("MoltenExportOutput! %s %s"):format(
							vim.fn.fnameescape(event.file),
							vim.fn.fnameescape(kernels[1])
						)
					)
				end
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
		lazy = false,
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
			setup_jupytext_metadata_fallback()
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
