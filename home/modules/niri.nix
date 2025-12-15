{ config, pkgs, ... }:
{
  xdg.configFile."niri".source = ../../niri;
}
