{
  delib,
  homeDir,
  hostTraits,
  lib,
  profile,
  ...
}:
delib.module {
  name = "darwin.host.macbook";

  options = delib.singleEnableOption hostTraits.macbook;

  darwin.ifEnabled = {
    system.defaults = {
      ".GlobalPreferences"."com.apple.mouse.scaling" = 5.0;

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
        static-only = true;
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
        location = "${homeDir}/Pictures/Screenshots";
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

    system.activationScripts = {
      postActivation.text = lib.mkAfter ''
        uid="$(id -u ${profile.username})"

        # screencapture.location points here.
        mkdir -p ${homeDir}/Pictures/Screenshots
        chown ${profile.username} ${homeDir}/Pictures/Screenshots

        # Prevent the screen saver from triggering an automatic lock. Display
        # sleep, lid-close sleep, and manual locking remain unchanged.
        launchctl asuser "$uid" sudo --user=${profile.username} /usr/bin/defaults -currentHost write \
          com.apple.screensaver idleTime -int 0
      '';
    };
  };
}
