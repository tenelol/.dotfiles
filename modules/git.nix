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
          condition = "gitdir:~/iniad/";
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
