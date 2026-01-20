{ delib, host, ... }:
delib.module {
  name = "fuzzel";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    home.activation.installFuzzelConfig = ''
      if [ -e "$HOME/.config/fuzzel" ]; then
        $DRY_RUN_CMD rm -rf "$HOME/.config/fuzzel"
      fi
      $DRY_RUN_CMD mkdir -p "$HOME/.config/fuzzel"
      $DRY_RUN_CMD cp -r ${../config/fuzzel}/. "$HOME/.config/fuzzel/"
      $DRY_RUN_CMD chmod -R u+rwX "$HOME/.config/fuzzel"
    '';
  };
}
