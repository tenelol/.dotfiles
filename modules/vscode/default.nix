{
  delib,
  host,
  lib,
  pkgs,
  ...
}:
let
  marketplaceExtensions = pkgs.vscode-utils.extensionsFromVscodeMarketplace [
    {
      name = "astro";
      publisher = "appcypher";
      version = "0.1.148";
      hash = "sha256-7xfE0aGM7Qkgmho6w3Bxp1Mgk6KfGf5MAMfjoJ5MBz0=";
    }
    {
      name = "live-sass";
      publisher = "glenn2223";
      version = "6.1.5";
      sha256 = "61cf63300895c7e8ef8ed1ad4c19cee9c5b7b0dafc5e6cbebecd610d2b6ebe50";
    }
    {
      name = "vscode-typescript-tslint-plugin";
      publisher = "ms-vscode";
      version = "1.3.4";
      hash = "sha256-wT5jwQPaCPwJqK424J2QLpRXu8/uXBZ9e5fpcHpKb30=";
    }
    {
      name = "sftp";
      publisher = "natizyskunk";
      version = "1.16.3";
      hash = "sha256-HifPiHIbgsfTldIeN9HaVKGk/ujaZbjHMiLAza/o6J4=";
    }
    {
      name = "chatgpt";
      publisher = "openai";
      version = "26.5602.40724";
      vsix = pkgs.fetchurl {
        name = "openai-chatgpt.vsix";
        url = "https://openai.gallerycdn.vsassets.io/extensions/openai/chatgpt/26.5602.40724/1780678443592/Microsoft.VisualStudio.Services.VSIXPackage";
        hash = "sha256-meGtMspO1bDHNJRPLmlrczdyZsZ+wf36ZLi17SGf0U8=";
      };
    }
    {
      name = "evilinspector";
      publisher = "saikou9901";
      version = "1.0.8";
      hash = "sha256-dO7ifAGelwo913fGWbPH8YAPgZhRCdMm55MDKTC54vM=";
    }
    {
      name = "background";
      publisher = "shalldie";
      version = "2.1.0";
      hash = "sha256-/gv4h9/izv2lnDxg80bZ5H3sM7YJtzX6nluCZtsSISQ=";
    }
    {
      name = "native-preview";
      publisher = "typescriptteam";
      version = "0.20260607.1";
      hash = "sha256-dpJv5uJY+dsr+givl0AGfWnuUW5JMCAc0XerVU9zZ7E=";
    }
    {
      name = "five-server";
      publisher = "yandeu";
      version = "0.4.0";
      hash = "sha256-oN4tZATw87M9XGmG2w0QlMPBE3Csv5jw1gZ+G1QGwqk=";
    }
  ];
  program = {
    enable = true;
    mutableExtensionsDir = false;

    profiles.default = {
      userSettings = {
        "files.autoSave" = "afterDelay";
        "update.mode" = "none";
      };

      extensions =
        (with pkgs.vscode-extensions; [
          astro-build.astro-vscode
          asvetliakov.vscode-neovim
          bradlc.vscode-tailwindcss
          christian-kohler.path-intellisense
          esbenp.prettier-vscode
          formulahendry.auto-rename-tag
          github.vscode-github-actions
          ms-azuretools.vscode-containers
          ms-azuretools.vscode-docker
          ms-ceintl.vscode-language-pack-ja
          ms-python.debugpy
          ms-python.python
          ms-toolsai.jupyter
          ms-toolsai.jupyter-renderers
          ms-toolsai.vscode-jupyter-cell-tags
          ms-toolsai.vscode-jupyter-slideshow
          naumovs.color-highlight
          oderwat.indent-rainbow
          prisma.prisma
          ritwickdey.liveserver
          vscode-icons-team.vscode-icons
        ])
        ++ marketplaceExtensions;
    };
  };
in
delib.module {
  name = "vscode";

  home.always = lib.mkIf (!host.isServer) {
    programs.vscode =
      program // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin { package = null; };
  };
}
