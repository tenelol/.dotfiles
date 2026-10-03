{ lib, _7zz }:
cask:
if lib.versionOlder _7zz.version "26" then
  cask.overrideAttrs (old: {
    # brew-nix uses a 7zip 26 switch to permit framework symlink chains.
    # The pinned nixpkgs has 7zip 25, which predates that switch.
    unpackPhase = lib.replaceStrings [ "7zz x -snld20" ] [ "7zz x" ] old.unpackPhase;
  })
else
  cask
