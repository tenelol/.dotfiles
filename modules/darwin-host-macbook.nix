{
  delib,
  host,
  lib,
  profile,
  ...
}:
let
  macSkkBundleID = "net.mtgto.inputmethod.macSKK";
  abcInputSource = {
    InputSourceKind = "Keyboard Layout";
    "KeyboardLayout ID" = 252;
    "KeyboardLayout Name" = "ABC";
  };
  macSkkInputSource = inputMode: {
    "Bundle ID" = macSkkBundleID;
    "Input Mode" = inputMode;
    InputSourceKind = "Input Mode";
  };
  macSkkKeyboardInputMethod = {
    "Bundle ID" = macSkkBundleID;
    InputSourceKind = "Keyboard Input Method";
  };
  characterPaletteInputSource = {
    "Bundle ID" = "com.apple.CharacterPaletteIM";
    InputSourceKind = "Non Keyboard Input Method";
  };
  macSkkAsciiInputSource = macSkkInputSource "net.mtgto.inputmethod.macSKK.ascii";
  macSkkHiraganaInputSource = macSkkInputSource "net.mtgto.inputmethod.macSKK.hiragana";
  macSkkInputSources = [
    macSkkAsciiInputSource
    macSkkHiraganaInputSource
  ];
  enabledInputSources = [
    abcInputSource
  ]
  ++ macSkkInputSources
  ++ [
    macSkkKeyboardInputMethod
    characterPaletteInputSource
  ];
  selectedInputSources = [
    macSkkHiraganaInputSource
  ];
  enabledInputSourcesPlist = lib.generators.toPlist {
    escape = true;
  } enabledInputSources;
  selectedInputSourcesPlist = lib.generators.toPlist {
    escape = true;
  } selectedInputSources;
  macSkkSkkservSettings = {
    enabled = true;
    address = "127.0.0.1";
    port = 1178;
    encoding = 3;
    saveToUserDict = false;
    enableCompletion = true;
  };
  macSkkSkkservSettingsJson = builtins.toJSON macSkkSkkservSettings;
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

      ${inputSourceShortcutCommands}

      macskk_container="/Users/${profile.username}/Library/Containers/${macSkkBundleID}/Data"
      macskk_dict_dir="$macskk_container/Documents/Dictionaries"
      macskk_prefs="$macskk_container/Library/Preferences/${macSkkBundleID}.plist"
      aquaskk_dir="/Users/${profile.username}/Library/Application Support/AquaSKK"

      mkdir -p "$macskk_dict_dir" "$(dirname "$macskk_prefs")"
      chown -R ${profile.username} "/Users/${profile.username}/Library/Containers/${macSkkBundleID}" 2>/dev/null || true

      if [ -f "$aquaskk_dir/SKK-JISYO.L" ] && [ ! -f "$macskk_dict_dir/SKK-JISYO.L" ]; then
        cp "$aquaskk_dir/SKK-JISYO.L" "$macskk_dict_dir/SKK-JISYO.L"
        chown ${profile.username} "$macskk_dict_dir/SKK-JISYO.L"
      fi

      if [ -f "$aquaskk_dir/skk-jisyo.utf8" ] && [ ! -f "$macskk_dict_dir/skk-jisyo.utf8" ]; then
        cp "$aquaskk_dir/skk-jisyo.utf8" "$macskk_dict_dir/skk-jisyo.utf8"
        chown ${profile.username} "$macskk_dict_dir/skk-jisyo.utf8"
      fi

      launchctl asuser "$uid" sudo --user=${profile.username} /usr/bin/plutil -create xml1 "$macskk_prefs" 2>/dev/null || true
      launchctl asuser "$uid" sudo --user=${profile.username} /usr/bin/plutil \
        -replace selectedInputSource -string com.apple.keylayout.ABC "$macskk_prefs"
      launchctl asuser "$uid" sudo --user=${profile.username} /usr/bin/plutil \
        -replace selectCandidateKeys -string 123456789 "$macskk_prefs"
      launchctl asuser "$uid" sudo --user=${profile.username} /usr/bin/defaults write \
        ${macSkkBundleID} selectCandidateKeys -string 123456789
      launchctl asuser "$uid" sudo --user=${profile.username} /usr/bin/plutil \
        -replace showInputModePanel -bool false "$macskk_prefs"
      launchctl asuser "$uid" sudo --user=${profile.username} /usr/bin/defaults write \
        ${macSkkBundleID} showInputModePanel -bool false
      launchctl asuser "$uid" sudo --user=${profile.username} /usr/bin/plutil \
        -replace dictionaries \
        -json '[{"filename":"SKK-JISYO.L","enabled":true,"encoding":3,"type":"traditional","saveToUserDict":true}]' \
        "$macskk_prefs"
      launchctl asuser "$uid" sudo --user=${profile.username} /usr/bin/plutil \
        -replace skkserv \
        -json ${lib.escapeShellArg macSkkSkkservSettingsJson} \
        "$macskk_prefs"
      launchctl asuser "$uid" sudo --user=${profile.username} /usr/bin/defaults import \
        ${macSkkBundleID} "$macskk_prefs"
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
