#!/usr/bin/env python3
"""Reconcile signed macOS installers after a Nix Darwin activation."""

import hashlib
import json
import os
import plistlib
import pwd
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


def version_parts(value):
    return tuple(int(part) for part in re.findall(r"\d+", value))


def newer(installed, wanted):
    return version_parts(installed) > version_parts(wanted)


class Host:
    def run(self, *args, check=True):
        result = subprocess.run(args, text=True, capture_output=True, check=False)
        if check and result.returncode:
            raise RuntimeError(f"{args[0]} failed: {result.stderr.strip() or result.stdout.strip()}")
        return result

    def receipt(self, receipt_id):
        result = self.run("/usr/sbin/pkgutil", "--pkg-info", receipt_id, check=False)
        if result.returncode:
            return None
        match = re.search(r"^version: (.+)$", result.stdout, re.MULTILINE)
        return match.group(1).strip() if match else None

    def app(self, path):
        info = Path(path) / "Contents/Info.plist"
        if not info.is_file():
            return None
        with info.open("rb") as stream:
            plist = plistlib.load(stream)
        self.run("/usr/bin/codesign", "--verify", path)
        signature = self.run("/usr/bin/codesign", "-dv", "--verbose=2", path)
        match = re.search(r"^TeamIdentifier=(.+)$", signature.stderr, re.MULTILINE)
        metadata = Path(path).stat()
        return {
            "bundleId": plist.get("CFBundleIdentifier"),
            "version": plist.get("CFBundleShortVersionString") or plist.get("CFBundleVersion"),
            "teamId": match.group(1) if match else None,
            "symlink": Path(path).is_symlink(),
            "resolvedPath": str(Path(path).resolve()),
            "ownerUid": metadata.st_uid,
            "ownerWritable": bool(metadata.st_mode & 0o200),
        }

    def running(self, pattern):
        return self.run("/usr/bin/pgrep", "-f", pattern, check=False).returncode == 0

    def app_processes(self, app):
        prefixes = {str(Path(app)) + "/", str(Path(app).resolve()) + "/"}
        rows = self.run("/bin/ps", "-axww", "-o", "pid=,ppid=,comm=").stdout.splitlines()
        result = []
        for row in rows:
            fields = row.strip().split(None, 2)
            if len(fields) == 3 and any(fields[2].startswith(prefix) for prefix in prefixes):
                result.append((int(fields[0]), int(fields[1]), fields[2]))
        return result

    def stop_orphan_helpers(self, entry):
        allowed = set(entry["orphanHelpers"])
        deadline = time.monotonic() + 2
        while True:
            rows = self.app_processes(entry["app"])
            if any(parent != 1 or Path(command).name not in allowed for _, parent, command in rows):
                return  # The app or a real worker still runs; retain the blocking guard.
            if not rows:
                return
            for row in rows:
                current = self.app_processes(entry["app"])
                if any(parent != 1 or Path(command).name not in allowed for _, parent, command in current):
                    return
                if row in current:
                    self.run("/bin/kill", "-TERM", str(row[0]), check=False)
            if time.monotonic() >= deadline:
                raise RuntimeError(f"{entry['name']}: orphan helpers did not exit; no app replacement attempted")
            time.sleep(0.05)

    def verify_pkg(self, path, team_id):
        result = self.run("/usr/sbin/pkgutil", "--check-signature", path)
        if "Status: signed by a developer certificate issued by Apple" not in result.stdout:
            raise RuntimeError(f"unsigned installer: {path}")
        if f"({team_id})" not in result.stdout:
            raise RuntimeError(f"unexpected installer signer: {path}")

    def install_pkg(self, path, choices, state_dir):
        if not choices:
            self.run("/usr/sbin/installer", "-pkg", path, "-target", "/")
            return
        with tempfile.NamedTemporaryFile(mode="wb", suffix=".plist", dir=state_dir) as stream:
            plistlib.dump(choices, stream)
            stream.flush()
            self.run(
                "/usr/sbin/installer",
                "-pkg", path,
                "-target", "/",
                "-applyChoiceChangesXML", stream.name,
            )

    def stage_app(self, source, destination, expected):
        destination = Path(destination)
        if destination.is_symlink() and not expected.get("selfUpdating"):
            raise RuntimeError(f"refusing to replace symlink: {destination}")
        original = self.app(str(destination))
        original_inode = destination.lstat() if os.path.lexists(destination) else None
        stage = Path(tempfile.mkdtemp(prefix=".dotfiles-installer-", dir=destination.parent))
        incoming = stage / "incoming.app"
        backup = stage / "previous.app"
        try:
            self.run("/usr/bin/ditto", source, str(incoming))
            verify_identity(self.app(str(incoming)), expected, str(incoming))
            verify_version(self.app(str(incoming)), expected, str(incoming))
            if expected.get("owner"):
                account = pwd.getpwnam(expected["owner"])
                for directory, dirs, files in os.walk(incoming, followlinks=False):
                    for path in [Path(directory)] + [Path(directory) / name for name in dirs + files]:
                        os.chown(path, account.pw_uid, account.pw_gid, follow_symlinks=False)
                        if not path.is_symlink():
                            path.chmod(path.stat().st_mode | 0o200)
                verify_identity(self.app(str(incoming)), expected, str(incoming))
            current_inode = destination.lstat() if os.path.lexists(destination) else None
            if (
                (original_inode is None) != (current_inode is None)
                or (
                    original_inode
                    and (original_inode.st_dev, original_inode.st_ino)
                    != (current_inode.st_dev, current_inode.st_ino)
                )
                or self.app(str(destination)) != original
            ):
                raise RuntimeError(f"app changed while preparing replacement: {destination}")
            if destination.exists():
                os.rename(destination, backup)
            os.rename(incoming, destination)
        except Exception:
            if backup.exists() and not destination.exists():
                os.rename(backup, destination)
            shutil.rmtree(stage)
            raise
        return stage, backup

    def rollback_app(self, destination, stage, backup):
        if Path(destination).exists():
            shutil.rmtree(destination)
        if backup.exists():
            os.rename(backup, destination)
        shutil.rmtree(stage)

    def finish_app(self, stage):
        shutil.rmtree(stage)

    def marker(self, state_dir, name):
        path = Path(state_dir) / f"{name}.json"
        try:
            return json.loads(path.read_text()).get("version")
        except FileNotFoundError:
            return None

    def write_marker(self, state_dir, name, version):
        Path(state_dir).mkdir(mode=0o755, parents=True, exist_ok=True)
        path = Path(state_dir) / f"{name}.json"
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=state_dir, delete=False) as stream:
            json.dump({"version": version}, stream)
            stream.write("\n")
            temporary = stream.name
        os.chmod(temporary, 0o644)
        os.replace(temporary, path)

    def legacy_azookey(self, entry):
        path = Path(entry["legacyPackage"])
        if not path.is_file():
            return False
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
        return digest.hexdigest() == entry["legacySha256"]

    def mas_list(self, user, mas):
        console = self.run("/usr/bin/stat", "-f", "%Su", "/dev/console").stdout.strip()
        if console != user:
            raise RuntimeError(f"MAS check needs {user} at the macOS console; current console user: {console}")
        uid = self.run("/usr/bin/id", "-u", user).stdout.strip()
        if os.geteuid() == int(uid):
            result = self.run(mas, "list")
        else:
            result = self.run(
                "/bin/launchctl", "asuser", uid,
                "/usr/bin/sudo", "-u", user, mas, "list",
            )
        return {int(match.group(1)) for match in re.finditer(r"^\s*(\d+)\s+", result.stdout, re.MULTILINE)}


def verify_identity(actual, entry, path):
    if actual is None:
        raise RuntimeError(f"missing signed app: {path}")
    if actual["bundleId"] != entry["bundleId"] or actual["teamId"] != entry["teamId"]:
        raise RuntimeError(f"unexpected app identity at {path}")


def verify_version(actual, entry, path):
    wanted = entry.get("appVersion")
    prefix = entry.get("appVersionPrefix")
    version = actual["version"] if actual else None
    if not version or (wanted and version != wanted) or (prefix and not version.startswith(prefix)):
        raise RuntimeError(f"unexpected app version at {path}: {version!r}")


def receipts_match(host, entry):
    return all(host.receipt(key) == value for key, value in entry.get("receipts", {}).items()) and all(
        host.receipt(key) is not None for key in entry.get("requiredReceipts", [])
    )


def supporting_artifacts_exist(host, entry):
    return all(host.receipt(key) is not None for key in entry.get("receipts", {})) and all(
        host.receipt(key) is not None for key in entry.get("requiredReceipts", [])
    ) and all(Path(path).exists() for path in entry.get("requiredPaths", []))


def app_meets_minimum(actual, entry):
    if actual is None or not actual["version"]:
        return False
    prefix = entry.get("appVersionPrefix")
    if prefix:
        wanted = version_parts(prefix)
        return version_parts(actual["version"])[:len(wanted)] >= wanted
    return version_parts(actual["version"]) >= version_parts(entry.get("appVersion") or entry["version"])


def receipts_meet_minimum(host, entry):
    return all(
        (installed := host.receipt(receipt_id)) is not None
        and version_parts(installed) >= version_parts(wanted)
        for receipt_id, wanted in entry.get("receipts", {}).items()
    )


def entry_status(host, entry, state_dir):
    name = entry["name"]
    actual = host.app(entry["app"])
    if actual is None and os.path.lexists(entry["app"]):
        raise RuntimeError(f"{name}: existing path is not a valid signed app: {entry['app']}")
    if actual is not None:
        verify_identity(actual, entry, entry["app"])
        owner_mismatch = entry.get("owner") and actual.get("ownerUid") is not None and (
            actual["ownerUid"] != pwd.getpwnam(entry["owner"]).pw_uid or not actual["ownerWritable"]
        )
        if entry.get("selfUpdating") and (actual.get("symlink") or owner_mismatch) and app_meets_minimum(actual, entry):
            return "needs-copy", None
    marker = host.marker(state_dir, name)
    if marker and newer(marker, entry["version"]):
        if entry.get("strictVersion"):
            raise RuntimeError(f"{name}: newer managed version conflicts with pinned compatibility version")
        if actual and supporting_artifacts_exist(host, entry):
            if name == "azookey":
                if receipts_match(host, entry):
                    verify_version(actual, entry, entry["app"])
                    return "newer", marker
            elif app_meets_minimum(actual, entry) and receipts_meet_minimum(host, entry):
                return "newer", marker
    if actual and name != "azookey" and actual["version"]:
        if newer(actual["version"], entry["version"]):
            if entry.get("strictVersion"):
                raise RuntimeError(f"{name}: newer installed version conflicts with pinned compatibility version")
            if not supporting_artifacts_exist(host, entry):
                raise RuntimeError(f"{name}: newer app exists but required receipts or system files are missing")
            if not receipts_meet_minimum(host, entry):
                raise RuntimeError(f"{name}: newer app has older installer receipts")
            return "newer", actual["version"]
    if actual and name != "azookey":
        for receipt_id, wanted in entry.get("receipts", {}).items():
            installed = host.receipt(receipt_id)
            if installed and newer(installed, wanted):
                if entry.get("strictVersion"):
                    raise RuntimeError(f"{name}: newer installed receipt conflicts with pinned compatibility version")
                if not supporting_artifacts_exist(host, entry):
                    raise RuntimeError(f"{name}: newer receipt exists but required files are missing")
                if not app_meets_minimum(actual, entry):
                    raise RuntimeError(f"{name}: newer receipt has an older app version")
                if not receipts_meet_minimum(host, entry):
                    raise RuntimeError(f"{name}: installer receipts disagree on version")
                return "newer", installed
    paths_ok = all(Path(path).exists() for path in entry.get("requiredPaths", []))
    app_ok = False
    if actual:
        try:
            verify_version(actual, entry, entry["app"])
            app_ok = True
        except RuntimeError:
            pass
    installed = app_ok and paths_ok and receipts_match(host, entry)
    if name == "azookey":
        installed = installed and (marker == entry["version"] or host.legacy_azookey(entry))
    if installed:
        return "installed", marker
    return "needs-install", None


def installation_entry(host, entry, status):
    if status != "needs-copy":
        return entry
    actual = host.app(entry["app"])
    verify_identity(actual, entry, entry["app"])
    if not app_meets_minimum(actual, entry):
        raise RuntimeError(f"app changed before copying: {entry['app']}")
    return entry | {
        "source": actual["resolvedPath"],
        "version": actual["version"],
        "appVersion": actual["version"],
        "appVersionPrefix": None,
    }


def preflight_entry(host, entry, state_dir):
    status, _ = entry_status(host, entry, state_dir)
    if status not in {"needs-install", "needs-copy"}:
        return status

    if entry.get("orphanHelpers"):
        host.stop_orphan_helpers(entry)
        processes = host.app_processes(entry["app"])
        if processes:
            allowed = set(entry["orphanHelpers"])
            blockers = [row for row in processes if row[1] != 1 or Path(row[2]).name not in allowed]
            names = ", ".join(f"{Path(command).name} (PID {pid})" for pid, _, command in (blockers or processes)[:8])
            raise RuntimeError(f"{entry['name']}: close the running app/workers before updating: {names}")
    else:
        for pattern in entry.get("running", []):
            if host.running(pattern):
                raise RuntimeError(f"{entry['name']}: close the running app/process matching {pattern!r} before updating")

    for package in entry.get("packages", []):
        host.verify_pkg(package, entry["teamId"])
    wanted = installation_entry(host, entry, status)
    source = wanted.get("source") or wanted.get("appSource")
    if source:
        source_app = host.app(source)
        verify_identity(source_app, entry, source)
        verify_version(source_app, wanted, source)
    return status


def reconcile_entry(host, entry, state_dir, status):
    name = entry["name"]
    if status == "newer":
        print(f"{name}: newer installed version preserved")
        return
    if status == "installed":
        if host.marker(state_dir, name) != entry["version"]:
            host.write_marker(state_dir, name, entry["version"])
        print(f"{name}: already installed")
        return

    for package in entry.get("packages", []):
        host.install_pkg(package, entry.get("choices", []), state_dir)

    staged = None
    try:
        wanted = installation_entry(host, entry, status)
        source = wanted.get("source") or wanted.get("appSource")
        if source:
            current = host.app(entry["app"])
            try:
                if status == "needs-copy":
                    raise RuntimeError("copy required")
                verify_version(current, wanted, entry["app"])
            except RuntimeError:
                staged = host.stage_app(source, entry["app"], wanted)
        actual = host.app(entry["app"])
        verify_identity(actual, entry, entry["app"])
        verify_version(actual, wanted, entry["app"])
        if not receipts_match(host, entry):
            raise RuntimeError(f"{name}: installer did not register expected receipts")
        if not all(Path(path).exists() for path in entry.get("requiredPaths", [])):
            raise RuntimeError(f"{name}: installer did not create expected system files")
        host.write_marker(state_dir, name, wanted["version"])
        print(f"{name}: installed {wanted['version']}")
    except Exception:
        if staged:
            host.rollback_app(entry["app"], *staged)
        raise
    else:
        if staged:
            host.finish_app(staged[0])


def reconcile_mas(host, manifest, mas):
    apps = manifest["masApps"]
    installed = host.mas_list(manifest["consoleUser"], mas)
    missing = [(name, app_id) for name, app_id in apps.items() if app_id not in installed]
    if missing:
        details = ", ".join(f"{name} ({app_id})" for name, app_id in missing)
        raise RuntimeError(
            f"MAS apps missing: {details}. Sign in to the Mac App Store as "
            f"{manifest['consoleUser']} at the console, install already-owned apps with "
            f"'{mas} install ID', then repeat activation. No purchase is attempted."
        )
    print(f"MAS: all {len(apps)} declared apps already installed")


def plan_reconciliation(host, manifest, mas):
    result = {"packages": [], "masApps": []}
    for entry in manifest["packages"]:
        item = {"name": entry["name"], "declaredVersion": entry["version"]}
        try:
            item["status"], _ = entry_status(host, entry, manifest["stateDir"])
        except RuntimeError as error:
            item.update(status="error", error=str(error))
        result["packages"].append(item)
    try:
        installed = host.mas_list(manifest["consoleUser"], mas)
    except RuntimeError as error:
        installed = None
        result["masError"] = str(error)
    for name, app_id in manifest["masApps"].items():
        result["masApps"].append({
            "name": name,
            "id": app_id,
            "installed": app_id in installed if installed is not None else None,
        })
    return result


def main():
    arguments = sys.argv[1:]
    plan_only = bool(arguments and arguments[0] == "--plan")
    before_nix_apps = bool(arguments and arguments[0] == "--before-nix-apps")
    if plan_only or before_nix_apps:
        arguments = arguments[1:]
    if len(arguments) != 2:
        raise SystemExit("usage: reconcile.py [--plan|--before-nix-apps] MANIFEST MAS_BINARY")
    manifest = json.loads(Path(arguments[0]).read_text())
    host = Host()
    if plan_only:
        print(json.dumps(plan_reconciliation(host, manifest, arguments[1]), indent=2))
        return
    if os.geteuid() != 0:
        raise RuntimeError("darwin installers activation requires root")
    early_entries = [entry for entry in manifest["packages"]
                     if entry.get("migrateBeforeNixApps") and Path(entry["app"]).is_symlink()]
    if before_nix_apps and not early_entries:
        return
    state_dir = manifest["stateDir"]
    Path(state_dir).mkdir(mode=0o755, parents=True, exist_ok=True)
    reconcile_mas(host, manifest, arguments[1])
    statuses = [preflight_entry(host, entry, state_dir) for entry in manifest["packages"]]
    for entry, status in zip(manifest["packages"], statuses):
        if before_nix_apps and entry not in early_entries:
            continue
        reconcile_entry(host, entry, state_dir, status)


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as error:
        print(f"darwin-installers: {error}", file=sys.stderr)
        raise SystemExit(1) from error
