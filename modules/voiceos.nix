{
  delib,
  host,
  lib,
  ...
}:
delib.module {
  name = "voiceos";

  options = delib.singleEnableOption (
    !host.isServer && builtins.match ".*-darwin" host.system != null
  );

  darwin.ifEnabled = {
    system.activationScripts.postActivation.text = let
      voiceOsUrl = "https://voiceos-staging-releases.s3.amazonaws.com/releases/VoiceOS-Installer.dmg";
      releaseMarkerFile = "/var/db/voiceos-release-id";
      appPath = "/Applications/VoiceOS.app";
    in
      lib.mkAfter ''
        set -euo pipefail

        voiceos_url="${voiceOsUrl}"
        release_marker_file="${releaseMarkerFile}"
        app_path="${appPath}"

        headers="$(/usr/bin/curl -fsIL "$voiceos_url")"
        release_marker="$(printf '%s\n' "$headers" \
          | /usr/bin/awk 'BEGIN { IGNORECASE = 1 } /^x-amz-version-id:/ { sub(/\r$/, "", $2); print $2; exit }')"

        if [ -z "$release_marker" ]; then
          release_marker="$(printf '%s\n' "$headers" \
            | /usr/bin/awk 'BEGIN { IGNORECASE = 1 } /^etag:/ { gsub(/\r|"/, "", $2); print $2; exit }')"
        fi

        installed_marker=""
        if [ -f "$release_marker_file" ]; then
          installed_marker="$(/bin/cat "$release_marker_file")"
        fi

        if [ -d "$app_path" ] && [ -n "$release_marker" ] && [ "$release_marker" = "$installed_marker" ]; then
          echo "VoiceOS is already up to date."
          exit 0
        fi

        tmpdir="$(/usr/bin/mktemp -d)"
        attach_log="$tmpdir/voiceos-attach.log"
        dmg_path="$tmpdir/VoiceOS-Installer.dmg"
        mount_point=""

        cleanup() {
          if [ -n "$mount_point" ] && [ -d "$mount_point" ]; then
            /usr/bin/hdiutil detach "$mount_point" >/dev/null 2>&1 || true
          fi

          /bin/rm -rf "$tmpdir"
        }

        trap cleanup EXIT

        echo "Installing VoiceOS from $voiceos_url"
        /usr/bin/curl -fL "$voiceos_url" -o "$dmg_path"
        /usr/bin/hdiutil attach -nobrowse -readonly "$dmg_path" >"$attach_log"
        mount_point="$(/usr/bin/awk '/\/Volumes\// { sub(/^.*\t/, ""); print; exit }' "$attach_log")"

        if [ ! -d "$mount_point/VoiceOS.app" ]; then
          echo "VoiceOS.app was not found inside the mounted image." >&2
          exit 1
        fi

        /bin/rm -rf "$app_path"
        /usr/bin/ditto "$mount_point/VoiceOS.app" "$app_path"

        if [ -n "$release_marker" ]; then
          /bin/mkdir -p "$(/usr/bin/dirname "$release_marker_file")"
          printf '%s\n' "$release_marker" >"$release_marker_file"
        fi
      '';
  };
}
