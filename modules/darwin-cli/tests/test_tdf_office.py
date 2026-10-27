"""Check tdf-office with fake LibreOffice and tdf commands."""

import os
from pathlib import Path
import subprocess
import tempfile


SCRIPT = Path(__file__).resolve().parents[1] / "files/tdf-office"

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    bin_dir = root / "bin"
    bin_dir.mkdir()
    log = root / "calls"
    (bin_dir / "soffice").write_text(
        "#!/bin/sh\n"
        'printf "soffice %s fontconfig=%s\\n" "$*" "$FONTCONFIG_FILE" >> "$CALLS"\n'
        'while [ "$1" != --outdir ]; do shift; done\n'
        'out=$2; name=$(basename "$3"); : > "$out/${name%.*}.pdf"\n'
    )
    (bin_dir / "tdf").write_text(
        "#!/bin/sh\n"
        'printf "tdf %s exists=%s\\n" "$*" "$(test -f "$1" && echo yes)" >> "$CALLS"\n'
    )
    for tool in bin_dir.iterdir():
        tool.chmod(0o700)
    env = {**os.environ, "PATH": f"{bin_dir}:/usr/bin:/bin", "CALLS": str(log), "TMPDIR": str(root),
           "TDF_OFFICE_FONTCONFIG": "/fixture/fonts.conf"}

    sheet = root / "成績 表.xlsm"
    sheet.write_text("")
    subprocess.run(["bash", str(SCRIPT), str(sheet), "-f"], env=env, check=True)
    calls = log.read_text().splitlines()
    assert calls[0].startswith("soffice -env:UserInstallation=file://"), calls
    assert "--headless --convert-to pdf --outdir" in calls[0], calls
    assert calls[0].endswith("fontconfig=/fixture/fonts.conf"), calls
    assert calls[1].endswith("/成績 表.pdf -f exists=yes"), calls
    assert not list(root.glob("tdf-office.*")), "converted PDF was not cleaned up"

    log.write_text("")
    paper = root / "paper.PDF"
    paper.write_text("")
    subprocess.run(["bash", str(SCRIPT), str(paper)], env=env, check=True)
    assert log.read_text().splitlines() == [f"tdf {paper} exists=yes"]

    missing = subprocess.run(["bash", str(SCRIPT), str(root / "none.xlsx")],
                             env=env, capture_output=True, text=True)
    assert missing.returncode == 1 and "no such file" in missing.stderr

print("PASS tdf-office")
