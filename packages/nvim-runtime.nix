{ pkgs }:
let
  inherit (pkgs) lib;

  winresizer = import ./winresizer.nix { inherit pkgs; };

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
    metadata.debugger = true;
  };

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
    inherit (pkgs.vimPlugins)
      mini-animate
      snacks-nvim
      emmet-vim
      which-key-nvim
      nvim-autopairs
      nvim-surround
      vim-astro
      bufferline-nvim
      gitsigns-nvim
      diffview-nvim
      neogit
      trouble-nvim
      tiny-inline-diagnostic-nvim
      aerial-nvim
      nvim-navic
      todo-comments-nvim
      persistence-nvim
      nvim-web-devicons
      comment-nvim
      nvim-cmp
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      cmp-cmdline
      cmp_luasnip
      conform-nvim
      copilot-vim
      ccc-nvim
      nvim-colorizer-lua
      nvim-dap
      nvim-dap-python
      nvim-dap-ui
      nvim-nio
      image-nvim
      jupytext-nvim
      molten-nvim
      otter-nvim
      quarto-nvim
      dashboard-nvim
      edgy-nvim
      presence-nvim
      hop-nvim
      nvim-lspconfig
      lualine-nvim
      markdown-preview-nvim
      render-markdown-nvim
      orgmode
      neo-tree-nvim
      plenary-nvim
      nui-nvim
      tokyonight-nvim
      noice-nvim
      nvim-notify
      luasnip
      friendly-snippets
      telescope-nvim
      grug-far-nvim
      toggleterm-nvim
      nvim-ts-autotag
      vim-test
      lazygit-nvim
      codecompanion-nvim
      yazi-nvim
      ;
    nvim-treesitter = pkgs.vimPlugins.nvim-treesitter.withPlugins (
      parsers: with parsers; [
        lua
        nix
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
        prisma
      ]
    );
    inherit winresizer;
  };

  nixManagedPluginPaths = builtins.mapAttrs (_: toString) nixManagedPlugins;
  nixManagedPluginsLua = "return ${lib.generators.toLua { } nixManagedPluginPaths}\n";

  nvimPluginModuleNames =
    let
      pluginFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".lua" name) (
        builtins.readDir ../modules/nvim/files/lua/plugins
      );
    in
    map (name: "plugins.${lib.removeSuffix ".lua" name}") (builtins.attrNames pluginFiles);

  nvimPluginModulesLua = "return ${lib.generators.toLua { } nvimPluginModuleNames}\n";

  nvimLuaConfig = pkgs.runCommand "nvim-lua-config" { } ''
    mkdir -p "$out"
    cp -R ${../modules/nvim/files/lua}/. "$out/"
    chmod -R u+w "$out"
    cat > "$out/nix-managed-plugins.lua" <<'EOF'
    ${nixManagedPluginsLua}
    EOF
    cat > "$out/nix-plugin-modules.lua" <<'EOF'
    ${nvimPluginModulesLua}
    EOF
  '';
in
{
  inherit
    jupyterPython
    jupyterPythonPackages
    moltenRemotePluginManifest
    nixManagedPlugins
    nvimLuaConfig
    ;

  jupyterKernelSpecJson = builtins.toJSON jupyterKernelSpec;
}
