{
  delib,
  hostTraits,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  herdrPackage = inputs.herdr-bin.packages.${system}.default;
  rift = pkgs.callPackage ../../packages/rift.nix { };
  peekaboo = pkgs.callPackage ../../packages/peekaboo.nix { };
  # Match the installed MySQL major version without touching its Homebrew datadir.
  mysql97 = pkgs.callPackage ../../packages/mysql97.nix { };
  pkgConfigAlias = pkgs.runCommand "pkg-config-from-pkgconf" { } ''
    mkdir -p "$out/bin"
    ln -s ${pkgs.pkgconf}/bin/pkgconf "$out/bin/pkg-config"
  '';
in
delib.scopedModule {
  name = "darwin-cli";
  scope = hostTraits.darwinDesktop;

  options = delib.singleEnableOption hostTraits.darwinDesktop;

  home.ifEnabled.home.packages =
    assert herdrPackage.version == (lib.importTOML "${inputs.herdr}/Cargo.toml").package.version;
    with pkgs;
    [
      awscli2
      bat
      cloudflared
      wrangler
      cmake
      coreutils
      cowsay
      dotnet-sdk_10
      eza
      fd
      findutils
      gawk
      # Homebrew's gdrive is glotlabs v3; pkgs.gdrive is the unrelated v2 CLI.
      gdrive3
      gh
      gnused
      gnutar
      go
      gomi
      gnugrep
      herdrPackage
      # The wrapper includes cb, djvu, pdf-mupdf, and ps plugins.
      zathura
      ideviceinstaller
      ios-deploy
      lazygit
      llvmPackages_22.llvm
      llvmPackages_22.clang
      lolcat
      gnumake
      mas
      mysql97
      nodejs_26
      peekaboo
      pi-coding-agent
      pkgconf
      # Homebrew's pkgconf formula also exposes pkg-config.
      pkgConfigAlias
      platformio
      pnpm
      powershell
      prettier
      prettierd
      python314
      qrencode
      ripgrep
      rustc
      cargo
      rustfmt
      clippy
      sqlite
      supabase-cli
      swiftlint
      tre-command
      wget
      xcodegen
      yazi
      zig
      rift
      sketchybar
      jankyborders
    ];
}
