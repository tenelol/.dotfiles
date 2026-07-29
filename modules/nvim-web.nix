{
  delib,
  host,
  pkgs,
  ...
}:
delib.module {
  name = "nvim-web";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    programs.nixvim.extraPackages = with pkgs; [
      typescript-language-server
      eslint
      typescript
      tailwindcss-language-server
      astro-language-server
      prisma-language-server
      prettierd
      prettier
      dart-sass
    ];

    home.sessionVariables = {
      NVIM_WEB_WORKFLOW = "1";
    };
  };
}
