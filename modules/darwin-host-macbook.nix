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
  toggleAzooKeyInputSourceSource = pkgs.writeText "azookey-toggle-ime.c" ''
    #include <Carbon/Carbon.h>
    #include <CoreFoundation/CoreFoundation.h>

    static int select_input_source(CFStringRef source_id) {
      const void *keys[] = { kTISPropertyInputSourceID };
      const void *values[] = { source_id };
      CFDictionaryRef query = CFDictionaryCreate(
        kCFAllocatorDefault,
        keys,
        values,
        1,
        &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks
      );
      CFArrayRef sources = TISCreateInputSourceList(query, false);
      CFRelease(query);

      if (!sources || CFArrayGetCount(sources) == 0) {
        if (sources) {
          CFRelease(sources);
        }
        return 1;
      }

      TISInputSourceRef source = (TISInputSourceRef)CFArrayGetValueAtIndex(sources, 0);
      OSStatus status = TISSelectInputSource(source);
      CFRelease(sources);
      return status == noErr ? 0 : (int)status;
    }

    int main(void) {
      CFStringRef japanese = CFSTR("dev.ensan.inputmethod.azooKeyMac.Japanese");
      CFStringRef english = CFSTR("com.apple.keylayout.ABC");
      TISInputSourceRef current = TISCopyCurrentKeyboardInputSource();
      CFStringRef current_id = NULL;

      if (current) {
        current_id = TISGetInputSourceProperty(current, kTISPropertyInputSourceID);
      }

      int status = CFStringCompare(current_id ? current_id : CFSTR(""), japanese, 0) == kCFCompareEqualTo
        ? select_input_source(english)
        : select_input_source(japanese);

      if (current) {
        CFRelease(current);
      }
      return status;
    }
  '';
  toggleAzooKeyInputSourceTool = pkgs.stdenv.mkDerivation {
    pname = "azookey-toggle-ime-tool";
    version = "1.0.0";
    dontUnpack = true;

    buildPhase = ''
      runHook preBuild
      $CC -framework Carbon -framework CoreFoundation ${toggleAzooKeyInputSourceSource} -o azookey-toggle-ime-tool
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 azookey-toggle-ime-tool $out/bin/azookey-toggle-ime-tool
      runHook postInstall
    '';
  };
  toggleAzooKeyInputSource = pkgs.writeShellScriptBin "azookey-toggle-ime" ''
    uid="$(id -u ${profile.username})"

    if [ "$(id -u)" = "$uid" ]; then
      exec ${toggleAzooKeyInputSourceTool}/bin/azookey-toggle-ime-tool
    fi

    exec /bin/launchctl asuser "$uid" /usr/bin/sudo --user=${profile.username} \
      ${toggleAzooKeyInputSourceTool}/bin/azookey-toggle-ime-tool
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

    environment.systemPackages = [
      toggleAzooKeyInputSource
    ];

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
