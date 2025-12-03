{ config, pkgs, ... }:

{
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
    ];

  };

  xdg.configFile."nvim/init.lua".source = ../../nvim/init.lua;
  xdg.configFile."nvim/lua".source = ../../nvim/lua;

}
