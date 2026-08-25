{ delib, ... }:
delib.module {
  name = "dotfiles-doctor";

  home.always = {
    home.file = {
      ".local/bin/dotfiles" = {
        source = ./dotfiles-doctor/files/dotfiles;
        executable = true;
      };

      ".local/bin/dotfiles-doctor" = {
        source = ./dotfiles-doctor/files/dotfiles-doctor;
        executable = true;
      };
    };
  };
}
