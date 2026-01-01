{ pkgs, ... }:
{
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        user = "greeter";
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --cmd ${pkgs.niri}/bin/niri-session --time --remember --asterisks";
      };
    };
  };
}
