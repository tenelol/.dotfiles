{
  delib,
  hm,
  host,
  lib,
  pkgs,
  ...
}:
let
  isLinuxDesktop = !host.isServer && builtins.match ".*-linux" host.system != null;

  personaSource = pkgs.stdenvNoCC.mkDerivation {
    pname = "persona-quickshell-source";
    version = "0ae7d5468688f5eb4f0c3ca9a89bd0384459e284";

    src = pkgs.fetchFromGitHub {
      owner = "Yujonpradhananga";
      repo = "Persona-Quickshell";
      rev = "0ae7d5468688f5eb4f0c3ca9a89bd0384459e284";
      hash = "sha256-IgLCPp4F3YHwg3VcZQCBrrzpINyKVn5CwytkL+e74qU=";
    };

    nativeBuildInputs = [ pkgs.perl ];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out"
      cp -R . "$out/"
      chmod -R u+w "$out"

      # Quickshell 0.2.1 does not recognize this upstream pragma.
      perl -0pi -e 's#^//@ pragma QmlImportPath: "\."\n##m' "$out/shell.qml"

      # Upstream references these local font files but does not vendor them.
      mkdir -p "$out/Assets/fonts"
      ln -sf "${pkgs.montserrat}/share/fonts/ttf/Montserrat-Light.ttf" \
        "$out/Assets/fonts/Montserrat-Light.ttf"
      ln -sf "${pkgs.montserrat}/share/fonts/ttf/Montserrat-ExtraBold.ttf" \
        "$out/Assets/fonts/BebasNeue-Regular.ttf"

      # Options.qml references this FontLoader id outside of OptionsList.qml.
      perl -0pi -e 's/font\.family: bebasNeue\.name/font.family: "Montserrat ExtraBold"/g' \
        "$out/Layers/Options.qml"

      runHook postInstall
    '';
  };

  cavaMonitor = pkgs.stdenv.mkDerivation {
    pname = "qt6-cava-plugin";
    version = "0.1.0-23b108a";

    src = pkgs.fetchFromGitHub {
      owner = "Yujonpradhananga";
      repo = "Qt6-Cava-plugin";
      rev = "23b108a7919da59d4eaaced5f0bf4cbe21867093";
      hash = "sha256-itoyEEpT3ZeAjzjz8yASU9gXFQg3nF29lkiK7v45OxM=";
    };

    nativeBuildInputs = with pkgs; [
      cmake
      perl
      pkg-config
      qt6.wrapQtAppsHook
    ];

    postPatch = ''
      perl -0pi -e 's/(class CavaProcessor : public QObject \{.*?~CavaProcessor\(\);\n\n)    void setBars\(int bars\);/$1    Q_INVOKABLE void setBars(int bars);/s' cavamonitor.hpp
    '';

    buildInputs = with pkgs; [
      fftw
      pipewire
      qt6.qtbase
      qt6.qtdeclarative
    ];

    cmakeFlags = [ "-DCMAKE_INSTALL_PREFIX=${builtins.placeholder "out"}/lib/qt6/qml" ];
  };

  qmlModules = with pkgs.qt6; [
    qt5compat
    qtmultimedia
  ];
  qmlImportPath = lib.concatStringsSep ":" [
    (lib.makeSearchPath "lib/qt-6/qml" qmlModules)
    "${cavaMonitor}/lib/qt6/qml"
  ];
  qtPluginPath = lib.makeSearchPath "lib/qt-6/plugins" qmlModules;
  cavaLibraryPath = lib.makeLibraryPath [
    cavaMonitor
    pkgs.fftw
    pkgs.pipewire
    pkgs.qt6.qtbase
    pkgs.qt6.qtdeclarative
  ];

  personaQuickshell = pkgs.writeShellApplication {
    name = "persona-quickshell";

    runtimeInputs = with pkgs; [
      bash
      brightnessctl
      coreutils
      gnugrep
      hyprland
      networkmanager
      playerctl
      procps
      quickshell
      systemd
      wireplumber
    ];

    text = ''
      export NIXPKGS_QT6_QML_IMPORT_PATH="${qmlImportPath}:''${NIXPKGS_QT6_QML_IMPORT_PATH:-}"
      export QML2_IMPORT_PATH="${qmlImportPath}:''${QML2_IMPORT_PATH:-}"
      export QT_PLUGIN_PATH="${qtPluginPath}:''${QT_PLUGIN_PATH:-}"
      export LD_LIBRARY_PATH="${cavaMonitor}/lib/qt6/qml/CavaMonitor:${cavaLibraryPath}:''${LD_LIBRARY_PATH:-}"

      exec qs --config persona --no-duplicate "$@"
    '';
  };

  personaSession = pkgs.writeShellApplication {
    name = "persona-quickshell-session";

    runtimeInputs = [
      personaQuickshell
      pkgs.coreutils
      pkgs.procps
      pkgs.quickshell
      pkgs.systemd
    ];

    text = ''
      config_name="persona"

      discover_wayland() {
        runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}"

        if [ -n "''${WAYLAND_DISPLAY:-}" ] && [ -S "$runtime_dir/$WAYLAND_DISPLAY" ]; then
          export XDG_RUNTIME_DIR="$runtime_dir"
          return 0
        fi

        for candidate in "$runtime_dir"/wayland-*; do
          if [ -S "$candidate" ]; then
            export XDG_RUNTIME_DIR="$runtime_dir"
            export WAYLAND_DISPLAY="''${candidate##*/}"
            return 0
          fi
        done

        return 1
      }

      stop_waybar() {
        pkill -f '^waybar($|[[:space:]])' >/dev/null 2>&1 || true
      }

      stop_persona() {
        systemctl --user stop persona-quickshell.service >/dev/null 2>&1 || true
        qs --config "$config_name" kill >/dev/null 2>&1 || true
        pkill -f '(^|/)quickshell[[:space:]].*--config[[:space:]]+persona($|[[:space:]])' >/dev/null 2>&1 || true
      }

      start_persona() {
        systemd-run --user --collect --unit=persona-quickshell \
          --description="Persona Quickshell" \
          --setenv="XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" \
          --setenv="WAYLAND_DISPLAY=$WAYLAND_DISPLAY" \
          --setenv="XDG_SESSION_TYPE=''${XDG_SESSION_TYPE:-wayland}" \
          --setenv="XDG_CURRENT_DESKTOP=''${XDG_CURRENT_DESKTOP:-Hyprland}" \
          --setenv="DESKTOP_SESSION=''${DESKTOP_SESSION:-hyprland}" \
          --setenv="HYPRLAND_INSTANCE_SIGNATURE=''${HYPRLAND_INSTANCE_SIGNATURE:-}" \
          ${personaQuickshell}/bin/persona-quickshell >/dev/null 2>&1 \
          && return 0

        persona-quickshell --daemonize
      }

      case "''${1:-start}" in
        start)
          stop_waybar
          stop_persona
          discover_wayland || exit 0
          start_persona
          ;;
        restart)
          stop_waybar
          stop_persona
          discover_wayland || exit 0
          start_persona
          ;;
        stop)
          stop_persona
          ;;
        search|toggle-search)
          if ! qs --config "$config_name" ipc call searchapp toggle >/dev/null 2>&1; then
            stop_persona
            discover_wayland || exit 0
            start_persona
            sleep 0.2
            qs --config "$config_name" ipc call searchapp toggle >/dev/null 2>&1 || true
          fi
          ;;
        *)
          exec persona-quickshell "$@"
          ;;
      esac
    '';
  };
in
delib.module {
  name = "persona-quickshell";

  options = delib.singleEnableOption false;

  nixos.ifEnabled = lib.mkIf isLinuxDesktop {
    fonts.packages = with pkgs; [
      libertinus
      material-symbols
      montserrat
      nerd-fonts.jetbrains-mono
    ];
  };

  home.ifEnabled = lib.mkIf isLinuxDesktop {
    home.packages = [
      personaQuickshell
      personaSession
    ];

    xdg.configFile."quickshell/persona".source = personaSource;

    home.activation.stopWaybarForPersona = hm.dag.entryAfter [ "linkGeneration" ] ''
      $DRY_RUN_CMD ${pkgs.procps}/bin/pkill -f '^waybar($|[[:space:]])' >/dev/null 2>&1 || true
    '';

    home.activation.restartPersonaQuickshell = hm.dag.entryAfter [ "linkGeneration" ] ''
      $DRY_RUN_CMD ${personaSession}/bin/persona-quickshell-session restart >/dev/null 2>&1 || true
    '';
  };
}
