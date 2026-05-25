{ delib, ... }:
delib.module {
  name = "dotfiles-doctor";

  home.always = {
    home.file = {
      ".local/bin/dotfiles" = {
        source = ../config/scripts/dotfiles;
        executable = true;
      };

      ".local/bin/dotfiles-doctor" = {
        source = ../config/scripts/dotfiles-doctor;
        executable = true;
      };
    };
  };
}
