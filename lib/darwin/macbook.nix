{
  lib,
  pkgs,
  profile,
}:
let
  azookey = import ./azookey.nix {
    inherit lib pkgs profile;
  };
in
{
  systemPackages = [
    azookey.toggleInputSource
  ];

  defaults = {
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
        AppleEnabledInputSources = azookey.enabledInputSources;
        AppleSelectedInputSources = azookey.selectedInputSources;
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

  keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = false;
  };

  activationScripts = {
    ensureScreenshotDirectory.text = ''
      mkdir -p /Users/${profile.username}/Pictures/Screenshots
      chown ${profile.username} /Users/${profile.username}/Pictures/Screenshots
    '';

    postActivation.text = lib.mkAfter ''
      uid="$(id -u ${profile.username})"

      launchctl asuser "$uid" sudo --user=${profile.username} /usr/bin/defaults write \
        com.apple.HIToolbox AppleEnabledInputSources ${lib.escapeShellArg azookey.enabledInputSourcesPlist}
      launchctl asuser "$uid" sudo --user=${profile.username} /usr/bin/defaults write \
        com.apple.HIToolbox AppleSelectedInputSources ${lib.escapeShellArg azookey.selectedInputSourcesPlist}
      launchctl asuser "$uid" sudo --user=${profile.username} /usr/bin/swift \
        ${azookey.selectInputSourceScript}

      ${azookey.inputSourceShortcutCommands}
    '';

    reloadNativeBars.text = ''
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
