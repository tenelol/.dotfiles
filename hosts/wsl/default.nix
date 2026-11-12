{ delib, ... }:
delib.host {
  name = "wsl";
  type = "server";
  system = "x86_64-linux";

  # The Windows Tailscale client owns networking and DNS for WSL.
  myconfig.nixos.tailscale.enable = false;
}
