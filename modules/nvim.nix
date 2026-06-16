{
  delib,
  pkgs,
  hm,
  ...
}:
let
  winresizer = import ../packages/winresizer.nix { inherit pkgs; };
  skkeleton = import ../packages/skkeleton.nix { inherit pkgs; };
  skkDictionary = "${pkgs.skkDictionaries.l}/share/skk/SKK-JISYO.L";
  jupyterPythonPackages = ps: [
    ps.cairosvg
    ps.debugpy
    ps.ipykernel
    ps."jupyter-client"
    ps."jupyter-core"
    ps.jupytext
    ps.kaleido
    ps.matplotlib
    ps.nbconvert
    ps.nbformat
    ps.numpy
    ps.pandas
    ps.pillow
    ps.plotly
    ps.pnglatex
    ps.pynvim
    ps.pyperclip
    ps.requests
    ps."scikit-learn"
    ps."websocket-client"
  ];
  jupyterPython = pkgs.python3.withPackages jupyterPythonPackages;
  jupyterKernelSpec = {
    argv = [
      "${jupyterPython}/bin/python3"
      "-m"
      "ipykernel_launcher"
      "-f"
      "{connection_file}"
    ];
    display_name = "Python 3 (Nix)";
    language = "python";
    metadata = {
      debugger = true;
    };
  };
  jupyterKernelSpecJson = builtins.toJSON jupyterKernelSpec;
  nvimPythonHost =
    pkgs.runCommand "nvim-jupyter-python-host" { nativeBuildInputs = [ pkgs.makeWrapper ]; }
      ''
        mkdir -p "$out/bin"
        makeWrapper ${jupyterPython}/bin/python3 "$out/bin/nvim-python3" \
          --unset PYTHONPATH \
          --unset PYTHONSAFEPATH
      '';
  moltenRemotePluginPack = pkgs.neovimUtils.packDir {
    molten.start = [ pkgs.vimPlugins.molten-nvim ];
  };
  moltenRemotePluginManifest = pkgs.runCommand "molten-rplugin.vim" { } ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    export NVIM_RPLUGIN_MANIFEST="$out"

    ${pkgs.neovim-unwrapped}/bin/nvim \
      -u ${pkgs.writeText "manifest.vim" ""} \
      -i NONE \
      -n \
      --cmd "set packpath^=${moltenRemotePluginPack}" \
      --cmd "set rtp^=${moltenRemotePluginPack}" \
      --cmd "lua vim.g.python3_host_prog = '${nvimPythonHost}/bin/nvim-python3'; vim.g.loaded_node_provider = 0; vim.g.loaded_perl_provider = 0; vim.g.loaded_ruby_provider = 0" \
      +UpdateRemotePlugins \
      +quit! >log 2>&1 || {
        cat log
        exit 1
      }

    test -s "$out"
  '';
  nixManagedPlugins = {
    emmet-vim = pkgs.vimPlugins.emmet-vim;
    which-key-nvim = pkgs.vimPlugins.which-key-nvim;
    nvim-autopairs = pkgs.vimPlugins.nvim-autopairs;
    nvim-surround = pkgs.vimPlugins.nvim-surround;
    vim-astro = pkgs.vimPlugins.vim-astro;
    bufferline-nvim = pkgs.vimPlugins.bufferline-nvim;
    gitsigns-nvim = pkgs.vimPlugins.gitsigns-nvim;
    indent-blankline-nvim = pkgs.vimPlugins.indent-blankline-nvim;
    diffview-nvim = pkgs.vimPlugins.diffview-nvim;
    neogit = pkgs.vimPlugins.neogit;
    trouble-nvim = pkgs.vimPlugins.trouble-nvim;
    tiny-inline-diagnostic-nvim = pkgs.vimPlugins.tiny-inline-diagnostic-nvim;
    aerial-nvim = pkgs.vimPlugins.aerial-nvim;
    nvim-navic = pkgs.vimPlugins.nvim-navic;
    todo-comments-nvim = pkgs.vimPlugins.todo-comments-nvim;
    persistence-nvim = pkgs.vimPlugins.persistence-nvim;
    nvim-web-devicons = pkgs.vimPlugins.nvim-web-devicons;
    comment-nvim = pkgs.vimPlugins.comment-nvim;
    nvim-cmp = pkgs.vimPlugins.nvim-cmp;
    cmp-nvim-lsp = pkgs.vimPlugins.cmp-nvim-lsp;
    cmp-buffer = pkgs.vimPlugins.cmp-buffer;
    cmp-path = pkgs.vimPlugins.cmp-path;
    cmp-cmdline = pkgs.vimPlugins.cmp-cmdline;
    cmp_luasnip = pkgs.vimPlugins.cmp_luasnip;
    conform-nvim = pkgs.vimPlugins.conform-nvim;
    copilot-vim = pkgs.vimPlugins.copilot-vim;
    ccc-nvim = pkgs.vimPlugins.ccc-nvim;
    nvim-colorizer-lua = pkgs.vimPlugins.nvim-colorizer-lua;
    nvim-dap = pkgs.vimPlugins.nvim-dap;
    nvim-dap-python = pkgs.vimPlugins.nvim-dap-python;
    nvim-dap-ui = pkgs.vimPlugins.nvim-dap-ui;
    nvim-nio = pkgs.vimPlugins.nvim-nio;
    image-nvim = pkgs.vimPlugins.image-nvim;
    jupytext-nvim = pkgs.vimPlugins.jupytext-nvim;
    molten-nvim = pkgs.vimPlugins.molten-nvim;
    otter-nvim = pkgs.vimPlugins.otter-nvim;
    quarto-nvim = pkgs.vimPlugins.quarto-nvim;
    dashboard-nvim = pkgs.vimPlugins.dashboard-nvim;
    presence-nvim = pkgs.vimPlugins.presence-nvim;
    hop-nvim = pkgs.vimPlugins.hop-nvim;
    nvim-lspconfig = pkgs.vimPlugins.nvim-lspconfig;
    lualine-nvim = pkgs.vimPlugins.lualine-nvim;
    markdown-preview-nvim = pkgs.vimPlugins.markdown-preview-nvim;
    neo-tree-nvim = pkgs.vimPlugins.neo-tree-nvim;
    plenary-nvim = pkgs.vimPlugins.plenary-nvim;
    nui-nvim = pkgs.vimPlugins.nui-nvim;
    tokyonight-nvim = pkgs.vimPlugins.tokyonight-nvim;
    noice-nvim = pkgs.vimPlugins.noice-nvim;
    nvim-notify = pkgs.vimPlugins.nvim-notify;
    denops-vim = pkgs.vimPlugins.denops-vim;
    luasnip = pkgs.vimPlugins.luasnip;
    friendly-snippets = pkgs.vimPlugins.friendly-snippets;
    telescope-nvim = pkgs.vimPlugins.telescope-nvim;
    toggleterm-nvim = pkgs.vimPlugins.toggleterm-nvim;
    nvim-ts-autotag = pkgs.vimPlugins.nvim-ts-autotag;
    nvim-treesitter = pkgs.vimPlugins.nvim-treesitter.withPlugins (
      parsers: with parsers; [
        lua
        c
        cpp
        javascript
        typescript
        tsx
        python
        json
        yaml
        html
        xml
        markdown
        markdown_inline
        bash
        css
        scss
        astro
      ]
    );
    vim-test = pkgs.vimPlugins.vim-test;
    lazygit-nvim = pkgs.vimPlugins.lazygit-nvim;
    codecompanion-nvim = pkgs.vimPlugins.codecompanion-nvim;
    yazi-nvim = pkgs.vimPlugins.yazi-nvim;
    inherit skkeleton winresizer;
  };
  nixManagedPluginPaths = builtins.mapAttrs (_: plugin: toString plugin) nixManagedPlugins;
  nixManagedPluginsLua =
    let
      renderEntry = name: "[${builtins.toJSON name}] = ${builtins.toJSON nixManagedPluginPaths.${name}}";
    in
    ''
      return {
      ${builtins.concatStringsSep ",\n" (map renderEntry (builtins.attrNames nixManagedPluginPaths))}
      }
    '';
  skkeletonDictionariesLua = ''
    return {
      global_dictionaries = {
        { ${builtins.toJSON skkDictionary}, "euc-jp" },
      },
    }
  '';
  nvimPluginModuleNames =
    let
      pluginFiles = pkgs.lib.filterAttrs (
        name: type: type == "regular" && pkgs.lib.hasSuffix ".lua" name
      ) (builtins.readDir ../config/nvim/lua/plugins);
    in
    map (name: "plugins.${pkgs.lib.removeSuffix ".lua" name}") (builtins.attrNames pluginFiles);
  luaList = values: "{ ${builtins.concatStringsSep ", " (map builtins.toJSON values)} }";
  nvimLuaConfig = pkgs.runCommand "nvim-lua-config" { } ''
    mkdir -p "$out"
    cp -R ${../config/nvim/lua}/. "$out/"
    chmod -R u+w "$out"
    cat > "$out/nix-managed-plugins.lua" <<'EOF'
    ${nixManagedPluginsLua}
    EOF
    cat > "$out/skkeleton-dictionaries.lua" <<'EOF'
    ${skkeletonDictionariesLua}
    EOF
  '';
  nvimPluginLoaderLua = ''
    require("core.input-source")
    require("features.web")
    require("features.platformio")

    for _, path in ipairs({ vim.fn.stdpath("data"), vim.fn.stdpath("state"), vim.fn.stdpath("cache") }) do
      vim.fn.mkdir(path, "p")
    end

    local plugin_modules = ${luaList nvimPluginModuleNames}
    local specs = {}

    local function is_enabled(spec)
      return type(spec) == "table" and spec.enabled ~= false
    end

    local function add_spec(spec)
      if not is_enabled(spec) then
        return
      end

      if type(spec.dependencies) == "table" then
        for _, dep in ipairs(spec.dependencies) do
          add_spec(dep)
        end
      end

      if spec.init or spec.config or spec.keys or spec.priority then
        table.insert(specs, {
          spec = spec,
          index = #specs + 1,
        })
      end
    end

    for _, module in ipairs(plugin_modules) do
      local ok, result = pcall(require, module)
      if ok and type(result) == "table" then
        for _, spec in ipairs(result) do
          add_spec(spec)
        end
      elseif not ok then
        vim.schedule(function()
          vim.notify(("nixvim plugin module failed: %s\n%s"):format(module, result), vim.log.levels.ERROR)
        end)
      end
    end

    table.sort(specs, function(left, right)
      local left_priority = left.spec.priority or 0
      local right_priority = right.spec.priority or 0
      if left_priority == right_priority then
        return left.index < right.index
      end
      return left_priority > right_priority
    end)

    local function spec_key(spec)
      return spec.name or spec[1] or spec.dir
    end

    local function spec_name(spec)
      return spec_key(spec) or "unknown"
    end

    local specs_by_key = {}
    for _, entry in ipairs(specs) do
      local key = spec_key(entry.spec)
      if key then
        local current = specs_by_key[key]
        if not current or (type(entry.spec.config) == "function" and type(current.config) ~= "function") then
          specs_by_key[key] = entry.spec
        end
      end
    end

    local function canonical_spec(spec)
      local key = spec_key(spec)
      return (key and specs_by_key[key]) or spec
    end

    local configured = setmetatable({}, { __mode = "k" })
    local configuring = setmetatable({}, { __mode = "k" })
    local lazy_group = vim.api.nvim_create_augroup("NixvimPluginLazyConfig", { clear = true })

    local function as_list(value)
      if value == nil then
        return {}
      end
      if type(value) == "table" then
        return value
      end
      return { value }
    end

    local function has_trigger(value)
      return #as_list(value) > 0
    end

    local function has_lazy_trigger(spec)
      return spec.lazy == true or has_trigger(spec.event) or has_trigger(spec.ft)
    end

    local function config_at_start(spec)
      if type(spec.config) ~= "function" and type(spec.dependencies) ~= "table" then
        return false
      end
      if spec.lazy == false then
        return true
      end
      return not has_lazy_trigger(spec)
    end

    local function run_hook(kind, spec)
      local hook = spec[kind]
      if type(hook) ~= "function" then
        return true
      end

      local ok, err = pcall(hook, spec, spec.opts or {})
      if not ok then
        vim.schedule(function()
          vim.notify(
            ("nixvim plugin %s %s failed:\n%s"):format(spec_name(spec), kind, err),
            vim.log.levels.ERROR
          )
        end)
        return false
      end
      return true
    end

    local configure_spec

    local function configure_dependencies(spec)
      if type(spec.dependencies) ~= "table" then
        return true
      end

      for _, dep in ipairs(spec.dependencies) do
        if is_enabled(dep) then
          local dependency = canonical_spec(dep)
          if dependency ~= spec and not configure_spec(dependency) then
            return false
          end
        end
      end

      return true
    end

    configure_spec = function(spec)
      spec = canonical_spec(spec)
      if configured[spec] then
        return true
      end
      if configuring[spec] then
        return false
      end

      configuring[spec] = true
      local ok = configure_dependencies(spec)
      if ok and type(spec.config) == "function" then
        ok = run_hook("config", spec)
      end
      configuring[spec] = nil
      if ok then
        configured[spec] = true
      end
      return ok
    end

    local function keymap_opts(mapping)
      local opts = {}
      for key, value in pairs(mapping) do
        if type(key) == "string" and key ~= "mode" then
          opts[key] = value
        end
      end
      return opts
    end

    local function feed_mapping(keys, mode)
      local termcodes = vim.api.nvim_replace_termcodes(keys, true, false, true)
      vim.api.nvim_feedkeys(termcodes, mode or "m", false)
    end

    local function apply_lazy_key(spec, mapping)
      local lhs = mapping[1]
      local rhs = mapping[2]
      local opts = keymap_opts(mapping)

      if rhs ~= nil then
        vim.keymap.set(mapping.mode or "n", lhs, function()
          local ok = configure_spec(spec)
          if not ok then
            return opts.expr and "" or nil
          end

          if type(rhs) == "function" then
            return rhs()
          end
          if opts.expr then
            return rhs
          end
          feed_mapping(rhs)
          return nil
        end, opts)
        return
      end

      local replaying = false
      vim.keymap.set(mapping.mode or "n", lhs, function()
        if replaying then
          return nil
        end

        local ok = configure_spec(spec)
        if not ok then
          return nil
        end

        replaying = true
        vim.schedule(function()
          feed_mapping(lhs)
          vim.defer_fn(function()
            replaying = false
          end, 20)
        end)
        return nil
      end, opts)
    end

    local function apply_keys(spec)
      if type(spec.keys) ~= "table" then
        return
      end

      for _, mapping in ipairs(spec.keys) do
        if type(mapping) == "table" and mapping[1] then
          if type(spec.config) == "function" and not config_at_start(spec) then
            apply_lazy_key(spec, mapping)
          elseif mapping[2] ~= nil then
            vim.keymap.set(mapping.mode or "n", mapping[1], mapping[2], keymap_opts(mapping))
          end
        end
      end
    end

    local function register_event_triggers(spec)
      if type(spec.config) ~= "function" or config_at_start(spec) then
        return
      end

      for _, event in ipairs(as_list(spec.event)) do
        if type(event) == "string" then
          if event == "VeryLazy" then
            vim.api.nvim_create_autocmd("User", {
              group = lazy_group,
              pattern = "VeryLazy",
              once = true,
              callback = function()
                configure_spec(spec)
              end,
            })
          else
            vim.api.nvim_create_autocmd(event, {
              group = lazy_group,
              once = true,
              callback = function()
                configure_spec(spec)
              end,
            })
          end
        end
      end
    end

    local function register_ft_triggers(spec)
      if type(spec.config) ~= "function" or config_at_start(spec) or not has_trigger(spec.ft) then
        return
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = lazy_group,
        pattern = as_list(spec.ft),
        once = true,
        callback = function()
          configure_spec(spec)
        end,
      })
    end

    vim.api.nvim_create_autocmd("VimEnter", {
      group = lazy_group,
      once = true,
      callback = function()
        vim.schedule(function()
          vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy", modeline = false })
        end)
      end,
    })

    for _, entry in ipairs(specs) do
      run_hook("init", entry.spec)
    end

    for _, entry in ipairs(specs) do
      apply_keys(entry.spec)
    end

    for _, entry in ipairs(specs) do
      register_event_triggers(entry.spec)
      register_ft_triggers(entry.spec)
    end

    for _, entry in ipairs(specs) do
      if config_at_start(entry.spec) then
        configure_spec(entry.spec)
      end
    end
  '';
in
delib.module {
  name = "nvim";

  home.always = {
    programs.nixvim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      wrapRc = true;
      nixpkgs.useGlobalPackages = true;
      version.enableNixpkgsReleaseCheck = false;
      withNodeJs = true;
      withPython3 = true;
      withRuby = false;
      env.NVIM_SYSTEM_RPLUGIN_MANIFEST = "${moltenRemotePluginManifest}";
      extraConfigLuaPre =
        ''
          if vim.fn.has("wsl") == 1 and vim.fn.executable("clip.exe") == 1 and vim.fn.executable("powershell.exe") == 1 then
            vim.g.clipboard = {
              name = "wsl-clipboard",
              copy = {
                ["+"] = { "clip.exe" },
                ["*"] = { "clip.exe" },
              },
              paste = {
                ["+"] = {
                  "powershell.exe",
                  "-NoLogo",
                  "-NoProfile",
                  "-Command",
                  "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; Get-Clipboard -Raw",
                },
                ["*"] = {
                  "powershell.exe",
                  "-NoLogo",
                  "-NoProfile",
                  "-Command",
                  "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; Get-Clipboard -Raw",
                },
              },
              cache_enabled = 0,
            }
          end

          local is_wsl = vim.fn.has("wsl") == 1
          if is_wsl then
            vim.keymap.set({ "n", "i", "v" }, "<C-h>", "<Left>", { noremap = true, silent = true, desc = "Move left" })
            vim.keymap.set({ "n", "i", "v" }, "<C-j>", "<Down>", { noremap = true, silent = true, desc = "Move down" })
            vim.keymap.set({ "n", "i", "v" }, "<C-k>", "<Up>", { noremap = true, silent = true, desc = "Move up" })
            vim.keymap.set({ "n", "i", "v" }, "<C-l>", "<Right>", { noremap = true, silent = true, desc = "Move right" })
          else
            vim.keymap.set("n", "<C-h>", "<C-w>h", { noremap = true, silent = true })
            vim.keymap.set("n", "<C-j>", "<C-w>j", { noremap = true, silent = true })
            vim.keymap.set("n", "<C-k>", "<C-w>k", { noremap = true, silent = true })
            vim.keymap.set("n", "<C-l>", "<C-w>l", { noremap = true, silent = true })
            vim.keymap.set("t", "<C-h>", "<Cmd>wincmd h<CR>", { noremap = true, silent = true })
            vim.keymap.set("t", "<C-j>", "<Cmd>wincmd j<CR>", { noremap = true, silent = true })
            vim.keymap.set("t", "<C-k>", "<Cmd>wincmd k<CR>", { noremap = true, silent = true })
            vim.keymap.set("t", "<C-l>", "<Cmd>wincmd l<CR>", { noremap = true, silent = true })
          end
        ''
        + pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
          vim.g.clipboard = {
            name = "pbcopy",
            copy = {
              ["+"] = "/usr/bin/pbcopy",
              ["*"] = "/usr/bin/pbcopy",
            },
            paste = {
              ["+"] = { "/usr/bin/pbpaste" },
              ["*"] = { "/usr/bin/pbpaste" },
            },
            cache_enabled = 0,
          }
        ''
        + ''
          vim.opt.fillchars:append({ eob = " " })
        '';
      extraConfigLua = nvimPluginLoaderLua;
      extraPlugins = builtins.attrValues nixManagedPlugins;
      extraFiles."lua".source = nvimLuaConfig;
      globals = {
        mapleader = " ";
        maplocalleader = " ";
      };
      opts = {
        autoindent = true;
        clipboard = "unnamedplus";
        completeopt = [
          "menu"
          "menuone"
          "noselect"
        ];
        cursorline = true;
        expandtab = true;
        hidden = true;
        ignorecase = true;
        number = true;
        pumblend = 12;
        relativenumber = false;
        scrolloff = 8;
        shiftwidth = 2;
        signcolumn = "yes";
        smartcase = true;
        smartindent = true;
        softtabstop = 2;
        splitbelow = true;
        splitright = true;
        sidescrolloff = 8;
        tabstop = 2;
        termguicolors = true;
        timeoutlen = 300;
        undofile = true;
        updatetime = 250;
        winblend = 12;
      };
      diagnostic.settings = {
        severity_sort = true;
        signs = true;
        underline = true;
        update_in_insert = false;
        virtual_text = false;
        virtual_lines = false;
        float = {
          border = "rounded";
          header = "";
          prefix = "";
          source = "if_many";
        };
      };
      filetype.extension = {
        js = "javascript";
        mjs = "javascript";
        cjs = "javascript";
        jsx = "javascriptreact";
        tsx = "typescriptreact";
        ino = "cpp";
      };
      userCommands.SelectAll = {
        command = "normal! ggVG";
        desc = "Select the entire buffer";
      };
      autoGroups.IndentSettings.clear = true;
      autoCmd = [
        {
          event = "FileType";
          group = "IndentSettings";
          pattern = [ "python" ];
          callback.__raw = ''
            function()
              vim.opt_local.expandtab = true
              vim.opt_local.shiftwidth = 4
              vim.opt_local.tabstop = 4
              vim.opt_local.softtabstop = 4
            end
          '';
        }
        {
          event = "FileType";
          group = "IndentSettings";
          pattern = [
            "html"
            "css"
            "sass"
            "scss"
            "javascript"
            "typescript"
            "typescriptreact"
            "javascriptreact"
            "astro"
            "nix"
            "json"
            "jsonc"
            "markdown"
          ];
          callback.__raw = ''
            function()
              vim.opt_local.expandtab = true
              vim.opt_local.shiftwidth = 2
              vim.opt_local.tabstop = 2
              vim.opt_local.softtabstop = 2
            end
          '';
        }
        {
          event = "FileType";
          group = "IndentSettings";
          pattern = [ "go" ];
          callback.__raw = ''
            function()
              vim.opt_local.expandtab = false
              vim.opt_local.shiftwidth = 4
              vim.opt_local.tabstop = 4
              vim.opt_local.softtabstop = 0
            end
          '';
        }
      ];
      keymaps = [
        {
          mode = "i";
          key = "kj";
          action = "<Esc>";
          options.silent = true;
        }
        {
          mode = "t";
          key = "<C-s>";
          action = "<C-\\><C-n>";
          options = {
            noremap = true;
            silent = true;
          };
        }
        {
          mode = [
            "n"
            "i"
            "v"
          ];
          key = "<leader>va";
          action = "<Esc>ggVG";
          options = {
            silent = true;
            desc = "Select all";
          };
        }
        {
          mode = "n";
          key = "K";
          action.__raw = ''
            function()
              for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
                if client:supports_method("textDocument/hover") then
                  vim.lsp.buf.hover({
                    border = "rounded",
                    focus = false,
                    focusable = false,
                    max_width = math.min(80, math.floor(vim.o.columns * 0.6)),
                    max_height = math.min(12, math.floor(vim.o.lines * 0.35)),
                  })
                  return
                end
              end
            end
          '';
          options = {
            silent = true;
            desc = "Hover";
          };
        }
        {
          mode = "n";
          key = "<C-Tab>";
          action = "<Cmd>BufferLineCycleNext<CR>";
          options = {
            silent = true;
            desc = "Next buffer";
          };
        }
        {
          mode = "n";
          key = "<C-S-Tab>";
          action = "<Cmd>BufferLineCyclePrev<CR>";
          options = {
            silent = true;
            desc = "Previous buffer";
          };
        }
        {
          mode = "t";
          key = "<C-Tab>";
          action.__raw = ''function() vim.cmd("BufferLineCycleNext") end'';
          options = {
            silent = true;
            desc = "Next buffer";
          };
        }
        {
          mode = "t";
          key = "<C-S-Tab>";
          action.__raw = ''function() vim.cmd("BufferLineCyclePrev") end'';
          options = {
            silent = true;
            desc = "Previous buffer";
          };
        }
        {
          mode = "t";
          key = "]b";
          action.__raw = ''function() vim.cmd("BufferLineCycleNext") end'';
          options = {
            silent = true;
            desc = "Next buffer";
          };
        }
        {
          mode = "t";
          key = "[b";
          action.__raw = ''function() vim.cmd("BufferLineCyclePrev") end'';
          options = {
            silent = true;
            desc = "Previous buffer";
          };
        }
      ]
      ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        {
          mode = [
            "n"
            "i"
            "v"
          ];
          key = "<D-a>";
          action = "<Esc>ggVG";
          options = {
            silent = true;
            desc = "Select all";
          };
        }
      ];
      extraPython3Packages = jupyterPythonPackages;
      extraLuaPackages = ps: [
        ps.magick
      ];

      extraPackages =
        with pkgs;
        [
          lua-language-server
          clang-tools
          pyright
          gopls
          nil
          jupyterPython
          imagemagick
          vscode-langservers-extracted
          fd
          lazygit
          ripgrep
          stylua
          nixfmt
          gofumpt
          gotools
          deno
        ]
        ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
          macism
        ];
    };

    xdg.dataFile."jupyter/kernels/nix-python3/kernel.json".text = jupyterKernelSpecJson;
    home.file."Library/Jupyter/kernels/nix-python3/kernel.json".text = jupyterKernelSpecJson;

    home.activation.cleanupLegacyLazyNvim = hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -e "$HOME/.local/share/nvim/lazy/lazy.nvim" ]; then
        $DRY_RUN_CMD rm -rf "$HOME/.local/share/nvim/lazy/lazy.nvim"
      fi
    '';
  };
}
