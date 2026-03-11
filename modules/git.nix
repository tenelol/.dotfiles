{ delib, ... }:
delib.module {
  name = "git";

  home.always = {
    programs.git = {
      enable = true;
      settings = {
        user.name = "tenelol";
        user.email = "tenelol@tenelol.dev";
        core.editor = "nvim";
      };
    };
  };
}
