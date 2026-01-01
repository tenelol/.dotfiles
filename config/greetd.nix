{ pkgs, ... }:
{
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        user = "tener";
        command = "${pkgs.gtkgreet}/bin/gtkgreet -l --cmd ${pkgs.niri}/bin/niri --css /home/tener/.config/gtkgreet/style.css";
      };
    };
  };
}
