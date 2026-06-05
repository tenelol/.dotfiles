{
  delib,
  host,
  lib,
  pkgs,
  profile,
  ...
}:
let
  azooKeyBundleID = "dev.ensan.inputmethod.azooKeyMac";
  abcInputSource = {
    InputSourceKind = "Keyboard Layout";
    "KeyboardLayout ID" = 252;
    "KeyboardLayout Name" = "ABC";
  };
  azooKeyInputSource = inputMode: {
    "Bundle ID" = azooKeyBundleID;
    "Input Mode" = inputMode;
    InputSourceKind = "Input Mode";
  };
  azooKeyKeyboardInputMethod = {
    "Bundle ID" = azooKeyBundleID;
    InputSourceKind = "Keyboard Input Method";
  };
  characterPaletteInputSource = {
    "Bundle ID" = "com.apple.CharacterPaletteIM";
    InputSourceKind = "Non Keyboard Input Method";
  };
  azooKeyJapaneseInputSource = azooKeyInputSource "dev.ensan.inputmethod.azooKeyMac.Japanese";
  azooKeyRomanInputSource = azooKeyInputSource "dev.ensan.inputmethod.azooKeyMac.Roman";
  azooKeyInputSources = [
    azooKeyJapaneseInputSource
    azooKeyRomanInputSource
  ];
  enabledInputSources = [
    abcInputSource
  ]
  ++ azooKeyInputSources
  ++ [
    azooKeyKeyboardInputMethod
    characterPaletteInputSource
  ];
  selectedInputSources = [
    azooKeyJapaneseInputSource
  ];
  enabledInputSourcesPlist = lib.generators.toPlist {
    escape = true;
  } enabledInputSources;
  selectedInputSourcesPlist = lib.generators.toPlist {
    escape = true;
  } selectedInputSources;
  selectAzooKeyInputSourceScript = pkgs.writeText "select-azookey-input-source.swift" ''
    import Carbon
    import Foundation

    let wantedInputSourceID = "dev.ensan.inputmethod.azooKeyMac.Japanese"
    let query = [kTISPropertyInputSourceID as String: wantedInputSourceID] as CFDictionary
    let inputSources = TISCreateInputSourceList(query, false).takeRetainedValue() as! [TISInputSource]

    guard let inputSource = inputSources.first else {
      exit(1)
    }

    let status = TISSelectInputSource(inputSource)
    if status != noErr {
      exit(status)
    }
  '';
  enabledSymbolicHotKey = parameters: {
    enabled = true;
    value = {
      inherit parameters;
      type = "standard";
    };
  };
  inputSourceShortcutHotKeys = {
    # 60/61 are the previous/next input source shortcuts.
    "60" = enabledSymbolicHotKey [
      32
      49
      262144
    ];
    "61" = enabledSymbolicHotKey [
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

        "kCFPreferencesAnyApplication" = {
          TSMLanguageIndicatorEnabled = false;
        };

        "com.apple.HIToolbox" = {
          AppleEnabledInputSources = enabledInputSources;
          AppleSelectedInputSources = selectedInputSources;
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

      # Rift requires "Displays have separate Spaces" to be enabled.
      # In macOS defaults, that means spans-displays must be false.
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
      remapCapsLockToControl = false;
    };

    system.activationScripts.ensureScreenshotDirectory.text = ''
      mkdir -p /Users/${profile.username}/Pictures/Screenshots
      chown ${profile.username} /Users/${profile.username}/Pictures/Screenshots
    '';

    system.activationScripts.postActivation.text = lib.mkAfter ''
      uid="$(id -u ${profile.username})"

      launchctl asuser "$uid" sudo --user=${profile.username} /usr/bin/defaults write \
        com.apple.HIToolbox AppleEnabledInputSources ${lib.escapeShellArg enabledInputSourcesPlist}
      launchctl asuser "$uid" sudo --user=${profile.username} /usr/bin/defaults write \
        com.apple.HIToolbox AppleSelectedInputSources ${lib.escapeShellArg selectedInputSourcesPlist}
      launchctl asuser "$uid" sudo --user=${profile.username} /usr/bin/swift \
        ${selectAzooKeyInputSourceScript}

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
}
