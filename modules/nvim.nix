{
  delib,
  pkgs,
  hm,
  ...
}:
let
  winresizer = import ../packages/winresizer.nix { inherit pkgs; };
  jupyterPythonPackages = ps: [
    ps.cairosvg
    ps.debugpy
    ps.ipykernel
    ps."jupyter-client"
    ps."jupyter-core"
    ps.jupytext
    ps.kaleido
    ps.nbformat
    ps.pillow
    ps.plotly
    ps.pnglatex
    ps.pynvim
    ps.pyperclip
    ps.requests
    ps."websocket-client"
  ];
  jupyterPython = pkgs.python3.withPackages jupyterPythonPackages;
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
    inherit winresizer;
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
in
delib.module {
  name = "nvim";

  home.always = {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      withNodeJs = true;
      withPython3 = true;
      withRuby = false;
      extraWrapperArgs = [
        "--set"
        "NVIM_SYSTEM_RPLUGIN_MANIFEST"
        "${moltenRemotePluginManifest}"
      ];
      extraPython3Packages = jupyterPythonPackages;
      extraLuaPackages = ps: [
        ps.magick
      ];

      extraPackages = with pkgs; [
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
      ];
    };

    xdg.configFile."nvim/init.lua".source = ../config/nvim/init.lua;
    xdg.configFile."nvim/lua".source = ../config/nvim/lua;
    xdg.configFile."nvim/lazy-path.lua".text = ''
      return ${builtins.toJSON (toString pkgs.vimPlugins.lazy-nvim)}
    '';
    xdg.configFile."nvim/nix-managed-plugins.lua".text = nixManagedPluginsLua;

    home.activation.cleanupLegacyLazyNvim = hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -e "$HOME/.local/share/nvim/lazy/lazy.nvim" ]; then
        $DRY_RUN_CMD rm -rf "$HOME/.local/share/nvim/lazy/lazy.nvim"
      fi
    '';
  };
}
