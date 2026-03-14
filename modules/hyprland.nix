{ delib, host, hm, ... }:
let
  isDesktop = host.type == "desktop";
in
delib.module {
  name = "hyprland";

  options = delib.singleEnableOption isDesktop;

  home.ifEnabled = {
    home.activation.installHyprConfig = hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p "$HOME/.config/hypr"
      $DRY_RUN_CMD cp -r ${../config/hypr}/. "$HOME/.config/hypr/"
      $DRY_RUN_CMD chmod -R u+rwX "$HOME/.config/hypr"
      $DRY_RUN_CMD sed -i "s#__HOME__#$HOME#g" "$HOME/.config/hypr/hyprland/env.conf"
      $DRY_RUN_CMD mkdir -p "$HOME/.config/hypr/scheme"
      # Ensure current.conf has the default palette so Hyprland can parse colors on first start
      if [ ! -e "$HOME/.config/hypr/scheme/current.conf" ]; then
        $DRY_RUN_CMD cp "$HOME/.config/hypr/scheme/default.conf" "$HOME/.config/hypr/scheme/current.conf"
      fi
    '';
  };
}
