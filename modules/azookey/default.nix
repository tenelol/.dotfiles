{
  delib,
  host,
  lib,
  pkgs,
  profile,
  ...
}:
let
  isMacbook = host.name == "macbook" && builtins.match ".*-darwin" host.system != null;
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
  selectInputSourceScript = pkgs.writeText "select-azookey-input-source.swift" ''
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
  toggleInputSourceSource = pkgs.writeText "azookey-toggle-ime.c" ''
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
  toggleInputSourceTool = pkgs.stdenv.mkDerivation {
    pname = "azookey-toggle-ime-tool";
    version = "1.0.0";
    dontUnpack = true;

    buildPhase = ''
      runHook preBuild
      $CC -framework Carbon -framework CoreFoundation ${toggleInputSourceSource} -o azookey-toggle-ime-tool
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 azookey-toggle-ime-tool $out/bin/azookey-toggle-ime-tool
      runHook postInstall
    '';
  };
  toggleInputSource = pkgs.writeShellScriptBin "azookey-toggle-ime" ''
    uid="$(id -u ${profile.username})"

    if [ "$(id -u)" = "$uid" ]; then
      exec ${toggleInputSourceTool}/bin/azookey-toggle-ime-tool
    fi

    exec /bin/launchctl asuser "$uid" /usr/bin/sudo --user=${profile.username} \
      ${toggleInputSourceTool}/bin/azookey-toggle-ime-tool
  '';
  enabledSymbolicHotKey = parameters: {
    enabled = true;
    value = {
      inherit parameters;
      type = "standard";
    };
  };
  inputSourceShortcutHotKeys = {
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
  name = "darwin.azookey";

  options = delib.singleEnableOption isMacbook;

  darwin.ifEnabled = {
    environment.systemPackages = [ toggleInputSource ];

    system.defaults.CustomUserPreferences."com.apple.HIToolbox" = {
      AppleEnabledInputSources = enabledInputSources;
      AppleSelectedInputSources = selectedInputSources;
    };

    system.activationScripts.postActivation.text = lib.mkAfter ''
      uid="$(id -u ${profile.username})"

      launchctl asuser "$uid" sudo --user=${profile.username} /usr/bin/defaults write \
        com.apple.HIToolbox AppleEnabledInputSources ${lib.escapeShellArg enabledInputSourcesPlist}
      launchctl asuser "$uid" sudo --user=${profile.username} /usr/bin/defaults write \
        com.apple.HIToolbox AppleSelectedInputSources ${lib.escapeShellArg selectedInputSourcesPlist}
      launchctl asuser "$uid" sudo --user=${profile.username} /usr/bin/swift \
        ${selectInputSourceScript}

      ${inputSourceShortcutCommands}
    '';
  };
}
