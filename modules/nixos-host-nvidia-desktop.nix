{
  delib,
  host,
  pkgs,
  profile,
  ...
}:
delib.module {
  name = "nixos.host.nvidia-desktop";

  options = delib.singleEnableOption (host.name == "nvidia-desktop");

  nixos.ifEnabled = {
    networking.hostName = "nvidia-desktop";
    boot.kernelPackages = pkgs.linuxPackages_latest;

    users.users.${profile.username} = {
      openssh.authorizedKeys.keyFiles = [ profile.sshPublicKey ];
    };

    services.openssh = {
      enable = true;
      openFirewall = false;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

    services.ollama = {
      enable = true;
      package = pkgs.ollama-cuda;
      host = "127.0.0.1";
      port = 11434;
      openFirewall = false;
      loadModels = [
        "qwen3:8b"
        "qwen3:4b"
        "qwen2.5-coder:7b"
      ];
      environmentVariables = {
        OLLAMA_CONTEXT_LENGTH = "4096";
        OLLAMA_KEEP_ALIVE = "30m";
        OLLAMA_MAX_LOADED_MODELS = "1";
        OLLAMA_NO_CLOUD = "1";
        OLLAMA_NUM_PARALLEL = "1";
      };
    };

    security.sudo.extraRules = [
      {
        users = [ profile.username ];
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
