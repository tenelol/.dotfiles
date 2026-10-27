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
  # soffice comes from the LibreOffice Cask in brew-casks.
  tdfOffice = pkgs.writeShellApplication {
    name = "tdf-office";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.tdf
    ];
    text = ''
      export TDF_OFFICE_FONTCONFIG=${./files/tdf-office-fonts.conf}
      exec ${pkgs.bash}/bin/bash ${./files/tdf-office} "$@"
    '';
  };
in
delib.scopedModule {
  name = "darwin-cli";
  scope = hostTraits.darwinDesktop;

  options = delib.singleEnableOption hostTraits.darwinDesktop;

  home.ifEnabled.home.file.".local/bin/llvm-config".source =
    "${pkgs.llvmPackages_22.llvm.dev}/bin/llvm-config";

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
      R
      ripgrep
      rustc
      cargo
      rustfmt
      clippy
      sqlite
      supabase-cli
      swiftlint
      # Renders PDFs inside Ghostty through the Kitty graphics protocol.
      tdf
      tdfOffice
      tre-command
      typst
      wget
      xcodegen
      yazi
      zig
      rift
      sketchybar
      jankyborders
    ];
}
