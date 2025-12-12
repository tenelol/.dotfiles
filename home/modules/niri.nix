{ config, pkgs, ... }:
{
  xdg.configFile."niri/config.kdl" = source = ../../niri;
}
