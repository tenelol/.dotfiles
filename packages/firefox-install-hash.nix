{
  stdenv,
  fetchurl,
  python3,
}:
let
  # Firefox retains this older CityHash implementation for installation IDs.
  cpp = fetchurl {
    url = "https://raw.githubusercontent.com/mozilla-firefox/firefox/d0f18859d99ecb16f4c5d641b35a5f3bdb7b4f36/other-licenses/nsis/Contrib/CityHash/cityhash/city.cpp";
    hash = "sha256-SZkXTjYAfaesFZiBR3vt4D9jm0IL+fi7OufeGyQMVQ4=";
  };
  header = fetchurl {
    url = "https://raw.githubusercontent.com/mozilla-firefox/firefox/d0f18859d99ecb16f4c5d641b35a5f3bdb7b4f36/other-licenses/nsis/Contrib/CityHash/cityhash/city.h";
    hash = "sha256-BtpPZyhvwXKlgCOfyPqVFkOKfXyZ6tsNsXbtVw9/7/4=";
  };
in
stdenv.mkDerivation {
  pname = "firefox-install-hash";
  version = "1";
  dontUnpack = true;
  buildPhase = ''
    cp ${cpp} city.cpp
    cp ${header} city.h
    cat > main.cpp <<'CPP'
    #include "city.h"
    #include <iostream>
    #include <iterator>
    #include <string>
    int main() {
      std::string data((std::istreambuf_iterator<char>(std::cin)), {});
      std::cout << std::uppercase << std::hex << CityHash64(data.data(), data.size()) << "\n";
    }
    CPP
    $CXX -std=c++17 -O2 main.cpp city.cpp -o firefox-install-hash
  '';
  doCheck = true;
  nativeCheckInputs = [ python3 ];
  checkPhase = ''
    python3 - <<'PYTEST'
    import subprocess
    examples = {
        "/Applications/Zen.app/Contents/MacOS": "6ED35B3CA1B5D3AF",
        "/nix/store/2a7dz3wdaqxz1rcjkkigylk95kjrjv5x-zen-beta-bin-unwrapped-1.19.6b/Applications/Zen Browser (Beta).app/Contents/MacOS": "8FFBC649031515CE",
    }
    for path, wanted in examples.items():
        actual = subprocess.check_output(["./firefox-install-hash"], input=path.encode("utf-16le")).decode().strip()
        assert actual == wanted, (actual, wanted)
    PYTEST
  '';
  installPhase = ''
    install -Dm755 firefox-install-hash "$out/bin/firefox-install-hash"
  '';
}
