{ config, pkgs, ... }:
{
  xdg.configFile."niri".source = ../../config/niri;
}
