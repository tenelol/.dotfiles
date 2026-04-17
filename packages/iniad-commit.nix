{
  pkgs,
  lib,
}:
pkgs.stdenvNoCC.mkDerivation {
  pname = "iniad-commit";
  version = "0.2.0";

  src = pkgs.fetchFromGitHub {
    owner = "tenelol";
    repo = "iniad-commit";
    rev = "v0.2.0";
    hash = "sha256-4OzY3C8IjMTqhYDtkdPWpxGq0JINOZHJTUyvXPUOZdk=";
  };

  nativeBuildInputs = [
    pkgs.makeWrapper
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 git-iniad-commit-msg $out/libexec/git-iniad-commit-msg
    install -Dm755 git-auto-commit $out/bin/git-auto-commit
    patchShebangs $out/libexec/git-iniad-commit-msg
    patchShebangs $out/bin/git-auto-commit

    wrapProgram $out/bin/git-auto-commit \
      --set GIT_AUTO_COMMIT_PYTHON ${pkgs.python3}/bin/python3 \
      --set GIT_AUTO_COMMIT_SCRIPT $out/libexec/git-iniad-commit-msg \
      --prefix PATH : ${lib.makeBinPath [ pkgs.git ]}

    runHook postInstall
  '';

  meta = {
    description = "Git subcommand that generates commit messages with the INIAD OpenAI API";
    homepage = "https://github.com/tenelol/iniad-commit";
    license = lib.licenses.mit;
    mainProgram = "git-auto-commit";
    platforms = lib.platforms.all;
  };
}
