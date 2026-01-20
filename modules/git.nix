{ delib, ... }:
delib.module {
  name = "git";

  home.always = {
    programs.git.settings = {
      enable = true;
      userName = "tenelol";
      userEmail = "tenelol@tenelol.dev";
      extraConfig.core.editor = "nvim";
    };
  };
}
