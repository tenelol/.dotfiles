{
  delib,
  pkgs,
  hm,
  ...
}:
let
  winresizer = import ../packages/winresizer.nix { inherit pkgs; };
  nixManagedPlugins = {
    emmet-vim = pkgs.vimPlugins.emmet-vim;
    which-key-nvim = pkgs.vimPlugins.which-key-nvim;
    nvim-autopairs = pkgs.vimPlugins.nvim-autopairs;
    nvim-surround = pkgs.vimPlugins.nvim-surround;
    vim-astro = pkgs.vimPlugins.vim-astro;
    barbar-nvim = pkgs.vimPlugins.barbar-nvim;
    gitsigns-nvim = pkgs.vimPlugins.gitsigns-nvim;
    trouble-nvim = pkgs.vimPlugins.trouble-nvim;
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
    nvim-colorizer-lua = pkgs.vimPlugins.nvim-colorizer-lua;
    nvim-dap = pkgs.vimPlugins.nvim-dap;
    nvim-dap-python = pkgs.vimPlugins.nvim-dap-python;
    nvim-dap-ui = pkgs.vimPlugins.nvim-dap-ui;
    nvim-nio = pkgs.vimPlugins.nvim-nio;
    dashboard-nvim = pkgs.vimPlugins.dashboard-nvim;
    presence-nvim = pkgs.vimPlugins.presence-nvim;
    hop-nvim = pkgs.vimPlugins.hop-nvim;
    nvim-lspconfig = pkgs.vimPlugins.nvim-lspconfig;
    lualine-nvim = pkgs.vimPlugins.lualine-nvim;
    markdown-preview-nvim = pkgs.vimPlugins.markdown-preview-nvim;
    neo-tree-nvim = pkgs.vimPlugins.neo-tree-nvim;
    plenary-nvim = pkgs.vimPlugins.plenary-nvim;
    nui-nvim = pkgs.vimPlugins.nui-nvim;
    nightfox-nvim = pkgs.vimPlugins.nightfox-nvim;
    noice-nvim = pkgs.vimPlugins.noice-nvim;
    nvim-notify = pkgs.vimPlugins.nvim-notify;
    luasnip = pkgs.vimPlugins.luasnip;
    friendly-snippets = pkgs.vimPlugins.friendly-snippets;
    smear-cursor-nvim = pkgs.vimPlugins.smear-cursor-nvim;
    telescope-nvim = pkgs.vimPlugins.telescope-nvim;
    toggleterm-nvim = pkgs.vimPlugins.toggleterm-nvim;
    nvim-ts-autotag = pkgs.vimPlugins.nvim-ts-autotag;
    nvim-treesitter = pkgs.vimPlugins.nvim-treesitter.withPlugins (
      parsers: with parsers; [
        lua
        javascript
        typescript
        tsx
        python
        json
        html
        markdown
        css
        scss
        astro
      ]
    );
    vim-test = pkgs.vimPlugins.vim-test;
    inherit winresizer;
  };
  nixManagedPluginPaths = builtins.mapAttrs (_: plugin: toString plugin) nixManagedPlugins;
  nixManagedPluginsLua =
    let
      renderEntry = name: ''  [${builtins.toJSON name}] = ${builtins.toJSON nixManagedPluginPaths.${name}}'';
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

      extraPackages = with pkgs; [
        lua-language-server
        pyright
        gopls
        nil
        python3Packages.debugpy
        python3
        typescript-language-server
        nodePackages.eslint
        nodePackages.typescript
        tailwindcss-language-server
        vscode-langservers-extracted
        marksman
        astro-language-server
        fd
        prettierd
        prettier
        ripgrep
        sassc
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
