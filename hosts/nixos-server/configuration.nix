# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Hostname / Network
  networking.hostName = "nixos-server";
  networking.networkmanager.enable = false;
  networking.wireless.iwd.enable = true;
  networking.wireless.iwd.settings = {
    General = { EnableNetworkConfiguration = true; };
    Settings = { AutoConnect = true; };
  };

  # Locale / Timezone
  time.timeZone = "Asia/Tokyo";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ja_JP.UTF-8";
    LC_IDENTIFICATION = "ja_JP.UTF-8";
    LC_MEASUREMENT = "ja_JP.UTF-8";
    LC_MONETARY = "ja_JP.UTF-8";
    LC_NAME = "ja_JP.UTF-8";
    LC_NUMERIC = "ja_JP.UTF-8";
    LC_PAPER = "ja_JP.UTF-8";
    LC_TELEPHONE = "ja_JP.UTF-8";
    LC_TIME = "ja_JP.UTF-8";
  };

  # XKB
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # User
  users.users.tener = {
    isNormalUser = true;
    description = "tener";
    extraGroups = [ "video" "input" "seat" "audio" "network" "wheel" ];
    packages = with pkgs; [ ];              # ← ここで zsh を既定にする
  };

  # zsh をログインシェルとして許可
 # environment.shells = [ pkgs.zsh ];
#programs.zsh.enable = true;

  environment.variables.EDITOR = "nvim";
  security.sudo.extraConfig = ''Defaults env_keep += "EDITOR VISUAL"'';


  # Auto login (必要なら残す)
  services.getty.autologinUser = "tener";
  services.seatd.enable = true;

  # Unfree 許可
  nixpkgs.config.allowUnfree = true;

  # Packages
  environment.systemPackages = with pkgs; [
    neovim wget hyprland kitty git gcc gnumake pkg-config cmake ripgrep nodejs python3 iwd tofi hyprpaper go cloudflared
    gh tailscale
  ];

  # PipeWire / Audio
  services.pulseaudio.enable = false;  # 旧式停止
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Portals (Hyprland)
#  programs.hyprland.enable = true;
#  xdg.portal.enable = true;
#  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];

  # IME
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-skk
      qt6Packages.fcitx5-configtool
    ];
  };
  environment.variables = {
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE  = "fcitx";
    XMODIFIERS    = "@im=fcitx";
  };

  # Fonts
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      jetbrains-mono
      fira-code
      hack-font
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
    ];
  };

  # nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  #systemd Server
services.nginx = {
  enable = true;

  virtualHosts."local-portfolio" = {
    # ローカル用の適当な名前でOK
    listen = [
      { addr = "0.0.0.0"; port = 80; }
    ];

    locations."/" = {
      proxyPass = "http://127.0.0.1:8080";
    };
  };
};



# ファイアウォールで 8080 を開ける
networking.firewall.allowedTCPPorts = [ 80 8080 ];


  # State version
  system.stateVersion = "25.05";

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      mesa
      vulkan-loader
      vulkan-tools
      libva
    ];
  };
systemd.services.portfolio = {
  description = "Portfolio Server";
  after = [ "network.target" ];
  wantedBy = [ "multi-user.target" ];

  serviceConfig = {
    ExecStart = "/home/tener/projects/portfolio/result/bin/server";
    Restart = "always";
    WorkingDirectory = "/home/tener/projects/portfolio";
  };
};

services.cloudflared = {
  enable = true;

  tunnels."mywebfw" = {
    # トンネル作成時にもらった JSON
    credentialsFile = "/var/lib/cloudflared/mywebfw.json";

    # tenelol.dev に来たリクエストを localhost:8080 に流す
    ingress = {
      "tenelol.dev" = "http://localhost:8080";
    };

    # どのルールにもマッチしなかったとき
    default = "http_status:404";
  };
};

# suspend
services.logind.settings = {
  Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };
};

systemd.sleep.extraConfig = ''
  AllowSuspend=no
  AllowHibernation=no
  AllowHybridSleep=no
  AllowSuspendThenHibernate=no
'';


#tailscale
services.tailscale.enable = true;

#openssh
services.openssh = {
  enable = true;
  openFirewall = true;
  settings = {
    PasswordAuthentication = true;
    PermitRootLogin = "no";
    };
  };


}
