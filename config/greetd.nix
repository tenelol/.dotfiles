{ pkgs, ... }:
{
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        user = "greeter";
        command = "${pkgs.regreet}/bin/regreet --style /etc/greetd/regreet.css";
      };
    };
  };

  environment.etc."greetd/regreet.css".source = ./regreet/style.css;
}
