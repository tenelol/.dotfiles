{
  delib,
  lib,
  pkgs,
  profile,
  ...
}:
let
  iniadGitName = "1F10250179";
  iniadGitEmail = "s1F102501798@iniad.org";
in
delib.module {
  name = "git";

  home.always = {
    programs.git = {
      enable = true;
      includes = [
        {
          condition = "gitdir:~/iniad/";
          path = "~/.config/git/iniad";
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

    xdg.configFile."git/iniad".text = ''
      [user]
        name = ${iniadGitName}
        email = ${iniadGitEmail}
    '';
  };
}
