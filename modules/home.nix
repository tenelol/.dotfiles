{ delib, ... }:
delib.module {
  name = "home";

  home.always = { ... }: {
    imports = [
      ../home/home.nix
    ];
  };
}
