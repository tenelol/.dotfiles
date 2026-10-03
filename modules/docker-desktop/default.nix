{
  delib,
  hostTraits,
  host,
  hm,
  pkgs,
  ...
}:
let
  configureDockerDesktopUpdatePolicy = pkgs.writeShellApplication {
    name = "configure-docker-desktop-update-policy";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      settings_file="$HOME/Library/Group Containers/group.com.docker/settings-store.json"

      # Avoid creating this file before Docker Desktop's first-run setup.
      if [ ! -f "$settings_file" ]; then
        exit 0
      fi

      if jq --exit-status '
        .DisableUpdate == true
        and .AutoDownloadUpdates == false
        and .SilentModulesUpdate == false
      ' "$settings_file" >/dev/null; then
        exit 0
      fi

      mode=$(/usr/bin/stat -f '%Lp' "$settings_file")
      temporary_file="$(mktemp "$settings_file.XXXXXX")"
      trap 'rm -f "$temporary_file"' EXIT

      jq '
        .DisableUpdate = true
        | .AutoDownloadUpdates = false
        | .SilentModulesUpdate = false
      ' "$settings_file" > "$temporary_file"
      /bin/chmod "$mode" "$temporary_file"
      mv "$temporary_file" "$settings_file"
      trap - EXIT
    '';
  };
in
delib.scopedModule {
  name = "docker-desktop";
  scope = hostTraits.darwinDesktop;
  options = delib.singleEnableOption host.fullDesktopFeatured;
  home.ifEnabled.home.activation.configureDockerDesktopUpdatePolicy =
    hm.dag.entryAfter [ "writeBoundary" ]
      ''
        $DRY_RUN_CMD ${configureDockerDesktopUpdatePolicy}/bin/configure-docker-desktop-update-policy
      '';
}
