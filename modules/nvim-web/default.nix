{
  delib,
  host,
  lib,
  pkgs,
  ...
}:
delib.module {
  name = "nvim-web";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    # Keep base tools first even if denix's file discovery order changes.
    programs.nixvim.extraPackages = lib.mkAfter (
      with pkgs;
      [
        typescript-language-server
        eslint
        typescript
        tailwindcss-language-server
        astro-language-server
        prisma-language-server
        dart-sass
      ]
      ++ lib.optionals (!stdenv.hostPlatform.isDarwin) [
        prettierd
        prettier
      ]
    );

    home.sessionVariables = {
      NVIM_WEB_WORKFLOW = "1";
    };
  };
}
