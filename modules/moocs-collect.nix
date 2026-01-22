{ delib, host, lib, pkgs, ... }:
let
  moocs-collect-cli = pkgs.rustPlatform.buildRustPackage {
    pname = "moocs-collect-cli";
    version = "1.0.1";

    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [
      pkgs.openssl
      pkgs.dbus
    ];

    cargoBuildFlags = [ "-p" "collect-cli" ];
    cargoCheckFlags = [ "-p" "collect-cli" ];

    src = pkgs.fetchFromGitHub {
      owner = "yu7400ki";
    repo = "moocs-collect";
    rev = "cli-v1.0.1";
    hash = "sha256-MVUrgyrSH6hMr6IVxsEVJyij5ec7PTGwWaqOPOs0sxM=";
  };

    cargoHash = "sha256-gcquTNdbfAQWpRdRlqzKBhPtaKCxhRnE+IO0984+HF0=";

    meta = with lib; {
      description = "CLI tool to download lecture slides from INIAD MOOCs";
      homepage = "https://github.com/yu7400ki/moocs-collect";
      license = licenses.mit;
      mainProgram = "collect-cli";
    };
  };
in
delib.module {
  name = "moocs-collect-cli";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    home.packages = [ moocs-collect-cli ];
  };
}
