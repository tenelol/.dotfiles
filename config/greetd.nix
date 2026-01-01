{ pkgs, ... }:
{
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        user = "greeter";
        command = "${pkgs.gtkgreet}/bin/gtkgreet -l --cmd ${pkgs.niri}/bin/niri-session --css /etc/greetd/gtkgreet.css";
      };
    };
  };

  environment.etc."greetd/gtkgreet.css".source = ./gtkgreet/style.css;
}
