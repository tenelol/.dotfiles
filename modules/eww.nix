{ delib, host, hm, ... }:
delib.module {
  name = "eww";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    home.activation.installEwwConfig = hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -e "$HOME/.config/eww" ]; then
        $DRY_RUN_CMD rm -rf "$HOME/.config/eww"
      fi
      $DRY_RUN_CMD mkdir -p "$HOME/.config/eww"
      $DRY_RUN_CMD cp -r ${../config/eww}/. "$HOME/.config/eww/"
      $DRY_RUN_CMD chmod -R u+rwX "$HOME/.config/eww"
      $DRY_RUN_CMD find "$HOME/.config/eww/scripts" -type f -exec chmod +x {} \;
      $DRY_RUN_CMD touch "$HOME/.config/eww/eww.yuck" "$HOME/.config/eww/eww.scss"
    '';
  };
}
