{
  delib,
  hostTraits,
  ...
}:
delib.module {
  name = "raycast";

  options = delib.singleEnableOption hostTraits.darwinDesktop;

  home.ifEnabled = {
    home.file = {
      ".config/raycast/scripts/dotfiles-rebuild-macbook.sh" = {
        source = ./files/scripts/dotfiles-rebuild-macbook.sh;
        executable = true;
      };

      ".config/raycast/scripts/open-ghostty.sh" = {
        source = ./files/scripts/open-ghostty.sh;
        executable = true;
      };
    };
  };
}
