{
  delib,
  pkgs,
  hm,
  ...
}:
delib.module {
  name = "nvim";

  home.always = {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;

      extraPackages = with pkgs; [
        lua-language-server
        pyright
        gopls
        nil
        nodePackages.typescript-language-server
        nodePackages.typescript
        nodePackages."@tailwindcss/language-server"
      ];
    };

    xdg.configFile."nvim/init.lua".source = ../config/nvim/init.lua;
    xdg.configFile."nvim/lua".source = ../config/nvim/lua;
    xdg.configFile."nvim/lazy-path.lua".text = ''
      return ${builtins.toJSON (toString pkgs.vimPlugins.lazy-nvim)}
    '';

    home.activation.cleanupLegacyLazyNvim = hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -e "$HOME/.local/share/nvim/lazy/lazy.nvim" ]; then
        $DRY_RUN_CMD rm -rf "$HOME/.local/share/nvim/lazy/lazy.nvim"
      fi
    '';
  };
}
