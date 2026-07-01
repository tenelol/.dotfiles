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

      # Persona's upstream wallpaper drives full-screen shader animation at the
      # monitor refresh rate. Keep the motion, but cap the update cadence so it
      # does not pin the GPU on high-refresh multi-monitor setups.
      perl -0pi -e 's/(    clip: false\n)/$1    property bool active: true\n/' \
        "$out/Widgets/CavaVisualizer.qml"
      perl -0pi -e 's/(    property bool active: true\n)/$1    property int fps: 24\n    property bool paintPending: false\n/' \
        "$out/Widgets/CavaVisualizer.qml"
      perl -0pi -e 's/(        active): true/$1: root.active/' \
        "$out/Widgets/CavaVisualizer.qml"
      perl -0pi -e 's/text: cava\.values\.length > 0 \? cava\.values\[0\]\.toFixed\(3\) : "no data"/text: ""/' \
        "$out/Widgets/CavaVisualizer.qml"
      perl -0pi -e 's/(        color: "white"\n)/$1        visible: false\n/' \
        "$out/Widgets/CavaVisualizer.qml"
      perl -0pi -e 's#(    Canvas \{\n        id: canvas\n)#    Timer {\n        id: paintTimer\n        interval: Math.max(16, Math.round(1000 / root.fps))\n        repeat: false\n        onTriggered: {\n            root.paintPending = false;\n            canvas.requestPaint();\n        }\n    }\n\n$1#s' \
        "$out/Widgets/CavaVisualizer.qml"
      perl -0pi -e 's#function onValuesChanged\(\) \{\n                canvas\.requestPaint\(\);\n            \}#function onValuesChanged() {\n                if (!root.active || root.paintPending)\n                    return;\n                root.paintPending = true;\n                paintTimer.restart();\n            }#' \
        "$out/Widgets/CavaVisualizer.qml"
      perl -0pi -e 's#(    property real mouseOffsetY: 0\.0\n)#$1    readonly property real requestedWallpaperFps: parseInt(Quickshell.env("PERSONA_WALLPAPER_FPS") || "30")\n    readonly property int wallpaperFps: isNaN(requestedWallpaperFps) ? 30 : Math.max(1, Math.min(60, requestedWallpaperFps))\n    readonly property int frameInterval: Math.max(16, Math.round(1000 / wallpaperFps))\n    readonly property bool audioVisualizer: String(Quickshell.env("PERSONA_AUDIO_VISUALIZER") || "1") !== "0"\n    readonly property real requestedCavaFps: parseInt(Quickshell.env("PERSONA_CAVA_FPS") || "24")\n    readonly property int cavaFps: isNaN(requestedCavaFps) ? 24 : Math.max(1, Math.min(60, requestedCavaFps))\n#' \
        "$out/Widgets/WallpaperEngine.qml"
      perl -0pi -e 's#        NumberAnimation on time \{\n            from: 0\n            to: 10\n            duration: 800000\n            loops: Animation\.Infinite\n            running: true\n        \}#        Timer {\n            interval: root.frameInterval\n            repeat: true\n            running: true\n            onTriggered: s0_bg_clouds.time = (s0_bg_clouds.time + interval * 10 / 800000) % 10\n        }#' \
        "$out/Widgets/WallpaperEngine.qml"
      perl -0pi -e 's#        NumberAnimation on time \{\n            from: 0\n            to: 1000\n            duration: 500000\n            loops: Animation\.Infinite\n            running: true\n        \}#        Timer {\n            interval: root.frameInterval\n            repeat: true\n            running: true\n            onTriggered: s0_bg_stars.time = (s0_bg_stars.time + interval * 1000 / 500000) % 1000\n        }#' \
        "$out/Widgets/WallpaperEngine.qml"
      perl -0pi -e 's#            NumberAnimation on time \{\n                from: 0\n                to: 10000\n                duration: 10000000\n                loops: Animation\.Infinite\n                running: true\n            \}#            Timer {\n                interval: root.frameInterval\n                repeat: true\n                running: true\n                onTriggered: s1_bars_motion.time = (s1_bars_motion.time + interval * 10000 / 10000000) % 10000\n            }#' \
        "$out/Widgets/WallpaperEngine.qml"
      perl -0pi -e 's/(            height: 555\n)/$1            visible: root.audioVisualizer\n            active: root.audioVisualizer\n            fps: root.cavaFps\n/' \
        "$out/Widgets/WallpaperEngine.qml"

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
      export PERSONA_WALLPAPER_FPS="''${PERSONA_WALLPAPER_FPS:-30}"
      export PERSONA_AUDIO_VISUALIZER="''${PERSONA_AUDIO_VISUALIZER:-1}"
      export PERSONA_CAVA_FPS="''${PERSONA_CAVA_FPS:-24}"

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
          --setenv="PERSONA_WALLPAPER_FPS=''${PERSONA_WALLPAPER_FPS:-30}" \
          --setenv="PERSONA_AUDIO_VISUALIZER=''${PERSONA_AUDIO_VISUALIZER:-1}" \
          --setenv="PERSONA_CAVA_FPS=''${PERSONA_CAVA_FPS:-24}" \
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
