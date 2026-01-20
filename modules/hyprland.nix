{ delib, host, ... }:
delib.module {
  name = "hyprland";

  options = delib.singleEnableOption (
    host.name == "nixos" || host.name == "nvidia-desktop"
  );

  home.ifEnabled = {
    home.activation.installHyprConfig = ''
      if [ -e "$HOME/.config/hypr" ]; then
        $DRY_RUN_CMD rm -rf "$HOME/.config/hypr"
      fi
      $DRY_RUN_CMD mkdir -p "$HOME/.config/hypr"
      $DRY_RUN_CMD cp -r ${../config/hypr}/. "$HOME/.config/hypr/"
      $DRY_RUN_CMD chmod -R u+rwX "$HOME/.config/hypr"
      $DRY_RUN_CMD mkdir -p "$HOME/.config/hypr/scheme"
      # Ensure current.conf has the default palette so Hyprland can parse colors on first start
      if [ ! -e "$HOME/.config/hypr/scheme/current.conf" ]; then
        $DRY_RUN_CMD cp "$HOME/.config/hypr/scheme/default.conf" "$HOME/.config/hypr/scheme/current.conf"
      fi
    '';
  };
}
