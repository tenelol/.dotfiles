{
  delib,
  host,
  lib,
  profile,
  ...
}:
let
  aquaSkkInputSource = {
    "Bundle ID" = "jp.sourceforge.inputmethod.aquaskk";
    "Input Mode" = "com.apple.inputmethod.Japanese";
    InputSourceKind = "Input Mode";
  };
  aquaSkkSelectedInputSources = [
    aquaSkkInputSource
  ];
  aquaSkkSelectedInputSourcesPlist = lib.generators.toPlist {
    escape = true;
  } aquaSkkSelectedInputSources;
  disabledSymbolicHotKey = parameters: {
    enabled = false;
    value = {
      inherit parameters;
      type = "standard";
    };
  };
  inputSourceShortcutHotKeys = {
    # 60/61 are the previous/next input source shortcuts.
    "60" = disabledSymbolicHotKey [
      32
      49
      262144
    ];
    "61" = disabledSymbolicHotKey [
      32
      49
      786432
    ];
  };
  inputSourceShortcutCommands = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      id: hotKey:
      "launchctl asuser \"$uid\" sudo --user=${profile.username} /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add ${id} ${
        lib.escapeShellArg (lib.generators.toPlist { escape = true; } hotKey)
      }"
    ) inputSourceShortcutHotKeys
  );
in
delib.module {
  name = "darwin.host.macbook";

  options = delib.singleEnableOption (host.name == "macbook");

  darwin.ifEnabled = {
    networking.computerName = "macbook";
    networking.hostName = "macbook";
    networking.localHostName = "macbook";

    system.defaults = {
      NSGlobalDomain = {
        AppleICUForce24HourTime = true;
        AppleKeyboardUIMode = 3;
        ApplePressAndHoldEnabled = false;
        AppleShowScrollBars = "Automatic";
        AppleSpacesSwitchOnActivate = false;
        InitialKeyRepeat = 15;
        KeyRepeat = 2;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticInlinePredictionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSDocumentSaveNewDocumentsToCloud = false;
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        PMPrintingExpandedStateForPrint = true;
        PMPrintingExpandedStateForPrint2 = true;
        _HIHideMenuBar = true;
      };

      CustomUserPreferences = {
        ".GlobalPreferences" = {
          AppleMenuBarVisibleInFullscreen = false;
        };

        "jp.sourceforge.inputmethod.aquaskk" = {
          candidate_window_labels = "ASDFJK";
          show_input_mode_icon = false;
        };

        "com.apple.HIToolbox" = {
          AppleEnabledInputSources = [
            {
              InputSourceKind = "Keyboard Layout";
              "KeyboardLayout ID" = 252;
              "KeyboardLayout Name" = "ABC";
            }
            aquaSkkInputSource
            {
              "Bundle ID" = "jp.sourceforge.inputmethod.aquaskk";
              InputSourceKind = "Keyboard Input Method";
            }
            {
              "Bundle ID" = "com.apple.CharacterPaletteIM";
              InputSourceKind = "Non Keyboard Input Method";
            }
            {
              "Bundle ID" = "com.apple.50onPaletteIM";
              InputSourceKind = "Non Keyboard Input Method";
            }
            {
              "Bundle ID" = "com.apple.inputmethod.ironwood";
              InputSourceKind = "Non Keyboard Input Method";
            }
          ];

          AppleSelectedInputSources = aquaSkkSelectedInputSources;
        };
      };

      dock = {
        autohide = true;
        autohide-delay = 1000.0;
        autohide-time-modifier = 0.0;
        launchanim = false;
        mineffect = "scale";
        mru-spaces = false;
        show-process-indicators = true;
        show-recents = false;
        showhidden = true;
        tilesize = 48;
      };

      finder = {
        AppleShowAllExtensions = true;
        FXDefaultSearchScope = "SCcf";
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "clmv";
        QuitMenuItem = true;
        ShowPathbar = true;
        ShowStatusBar = true;
        _FXShowPosixPathInTitle = true;
        _FXSortFoldersFirst = true;
        _FXSortFoldersFirstOnDesktop = true;
      };

      screencapture = {
        disable-shadow = true;
        include-date = true;
        location = "/Users/${profile.username}/Pictures/Screenshots";
        show-thumbnail = false;
        type = "png";
      };

      spaces.spans-displays = false;

      trackpad = {
        Clicking = true;
        # Rift observes macOS-generated three-finger horizontal gesture events
        # and maps them to virtual workspace switching.
        TrackpadThreeFingerDrag = false;
        TrackpadThreeFingerHorizSwipeGesture = 2;
      };
    };

    system.keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };

    system.activationScripts.ensureScreenshotDirectory.text = ''
      mkdir -p /Users/${profile.username}/Pictures/Screenshots
      chown ${profile.username} /Users/${profile.username}/Pictures/Screenshots
    '';

    system.activationScripts.postActivation.text = lib.mkAfter ''
      uid="$(id -u ${profile.username})"

      launchctl asuser "$uid" sudo --user=${profile.username} /usr/bin/defaults write \
        com.apple.HIToolbox AppleSelectedInputSources ${lib.escapeShellArg aquaSkkSelectedInputSourcesPlist}

      ${inputSourceShortcutCommands}
    '';

    system.activationScripts.reloadNativeBars.text = ''
      uid="$(id -u ${profile.username})"

      launchctl asuser "$uid" sudo --user=${profile.username} /usr/bin/osascript \
        -e 'tell application "System Events" to tell dock preferences to set autohide menu bar to false' \
        -e 'delay 0.2' \
        -e 'tell application "System Events" to tell dock preferences to set autohide menu bar to true' \
        >/dev/null 2>&1 || true

      killall Dock >/dev/null 2>&1 || true
      killall SystemUIServer >/dev/null 2>&1 || true
    '';
  };

  home.ifEnabled = {
    home.file."Library/Application Support/AquaSKK/keymap.conf" = {
      force = true;
      source = ../config/aquaskk/keymap.conf;
    };
  };
}
