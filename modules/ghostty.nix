{
  delib,
  host,
  pkgs,
  ...
}:
let
  ghostty = import ../lib/ghostty.nix { inherit pkgs; };
in
delib.module {
  name = "ghostty";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled =
    { myconfig, ... }:
    {
      xdg.configFile = {
        "ghostty/config".source = ghostty.mkConfig myconfig;
        "ghostty/shaders/aurora.glsl".source = ghostty.shaders.aurora;
        "ghostty/shaders/liquid_glass_focus.glsl".source = ghostty.shaders.liquidGlassFocus;
        "ghostty/shaders/readability_scrim.glsl".source = ghostty.shaders.readabilityScrim myconfig;
        "ghostty/shaders/cursor_tail.glsl".source = ghostty.shaders.cursorTail;
        "ghostty/shaders/ripple_rectangle_cursor.glsl".source = ghostty.shaders.rippleRectangleCursor;
      };
    };
}
