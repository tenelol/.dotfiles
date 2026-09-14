{ delib, ... }:
delib.module {
  name = "dotfiles-doctor";

  home.always = {
    home.file = {
      ".local/bin/dotfiles" = {
        source = ./files/dotfiles;
        executable = true;
      };

      ".local/bin/dotfiles-doctor" = {
        source = ./files/dotfiles-doctor;
        executable = true;
      };
    };
  };
}
