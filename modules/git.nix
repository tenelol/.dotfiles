{
  delib,
  lib,
  pkgs,
  profile,
  ...
}:
delib.module {
  name = "git";

  home.always = {
    programs.git = {
      enable = true;
      includes = [
        {
          path = "~/.config/git/config.local";
        }
        {
          condition = "gitdir:~/Documents/SW-exercise1/";
          path = "~/.config/git/school";
        }
      ];
      settings = {
        user.name = profile.gitName;
        user.email = profile.gitEmail;
        core.editor = "nvim";
        init.defaultBranch = "main";
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
        credential.helper = "osxkeychain";
      };
    };
  };
}
