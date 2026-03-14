{ delib, profile, ... }:
delib.module {
  name = "git";

  home.always = {
    programs.git = {
      enable = true;
      settings = {
        user.name = profile.gitName;
        user.email = profile.gitEmail;
        core.editor = "nvim";
      };
    };
  };
}
