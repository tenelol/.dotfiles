import importlib.util
import io
import json
import shutil
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


SOURCE = Path(__file__).resolve().parents[1] / "files/reconcile.py"
SPEC = importlib.util.spec_from_file_location("darwin_reconcile", SOURCE)
RECONCILE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RECONCILE)


class FakeHost:
    def __init__(self):
        self.apps = {}
        self.receipts = {}
        self.markers = {}
        self.running_patterns = set()
        self.installs = []
        self.verified = []
        self.legacy = False
        self.mas_ids = set()
        self.mas_calls = []

    def app(self, path):
        return self.apps.get(path)

    def receipt(self, receipt_id):
        return self.receipts.get(receipt_id)

    def marker(self, _state_dir, name):
        return self.markers.get(name)

    def write_marker(self, _state_dir, name, version):
        self.markers[name] = version

    def running(self, pattern):
        return pattern in self.running_patterns

    def app_processes(self, app):
        return [(123, 10, app + "/Contents/MacOS/test")] if self.running_patterns else []

    def verify_pkg(self, path, team_id):
        self.verified.append((path, team_id))

    def install_pkg(self, path, choices, _state_dir):
        self.installs.append((path, choices))

    def legacy_azookey(self, _entry):
        return self.legacy

    def mas_list(self, user, mas):
        self.mas_calls.append((user, mas))
        return self.mas_ids

    def stage_app(self, source, destination, _entry):
        self.apps[destination] = self.apps[source] | {"symlink": False, "resolvedPath": destination}
        return Path("/tmp/fake-stage"), Path("/tmp/fake-backup")

    def rollback_app(self, *_args):
        raise AssertionError("unexpected rollback")

    def finish_app(self, _stage):
        pass


def entry(**changes):
    item = {
        "name": "karabiner-elements",
        "version": "16.0.0",
        "app": "/Applications/Karabiner-Elements.app",
        "appVersion": "16.0.0",
        "bundleId": "org.pqrs.Karabiner-Elements.Settings",
        "teamId": "G43BCU2T37",
        "receipts": {
            "org.pqrs.Karabiner-Elements": "16.0.0",
            "org.pqrs.Karabiner-DriverKit-VirtualHIDDevice": "6.14.0",
        },
        "packages": ["/nix/store/karabiner/Karabiner-Elements.pkg"],
        "running": ["karabiner_grabber"],
        "strictVersion": True,
    }
    item.update(changes)
    return item


class ReconcileTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.host = FakeHost()
        self.item = entry()
        self.host.apps[self.item["app"]] = {
            "bundleId": self.item["bundleId"],
            "teamId": self.item["teamId"],
            "version": self.item["appVersion"],
        }
        self.host.receipts.update(self.item["receipts"])

    def test_matching_driver_and_app_adopt_without_installer(self):
        status = RECONCILE.preflight_entry(self.host, self.item, self.temp.name)
        RECONCILE.reconcile_entry(self.host, self.item, self.temp.name, status)
        self.assertEqual(status, "installed")
        self.assertEqual(self.host.installs, [])
        self.assertEqual(self.host.markers["karabiner-elements"], "16.0.0")

    def test_missing_driver_receipt_requires_original_signed_pkg(self):
        del self.host.receipts["org.pqrs.Karabiner-DriverKit-VirtualHIDDevice"]
        status = RECONCILE.preflight_entry(self.host, self.item, self.temp.name)
        self.assertEqual(status, "needs-install")
        self.assertEqual(
            self.host.verified,
            [("/nix/store/karabiner/Karabiner-Elements.pkg", "G43BCU2T37")],
        )

    def test_newer_karabiner_blocks_downgrade(self):
        self.host.apps[self.item["app"]]["version"] = "16.3.0"
        with self.assertRaisesRegex(RuntimeError, "pinned compatibility"):
            RECONCILE.preflight_entry(self.host, self.item, self.temp.name)
        self.assertEqual(self.host.installs, [])

    def test_marker_cannot_hide_missing_receipt(self):
        self.host.markers[self.item["name"]] = "16.1.0"
        del self.host.receipts["org.pqrs.Karabiner-Elements"]
        with self.assertRaisesRegex(RuntimeError, "pinned compatibility"):
            RECONCILE.preflight_entry(self.host, self.item, self.temp.name)

    def test_running_app_blocks_before_install(self):
        self.host.apps[self.item["app"]]["version"] = "15.9.0"
        self.host.running_patterns.add("karabiner_grabber")
        with self.assertRaisesRegex(RuntimeError, "close the running"):
            RECONCILE.preflight_entry(self.host, self.item, self.temp.name)
        self.assertEqual(self.host.installs, [])

    def test_azookey_legacy_adoption_requires_real_package(self):
        item = entry(
            name="azookey",
            version="0.1.4",
            app="/Library/Input Methods/azooKeyMac.app",
            appVersion="1.0",
            bundleId="dev.ensan.inputmethod.azooKeyMac",
            teamId="9S3UXHYP65",
            receipts={"dev.ensan.inputmethod.azooKeyMac": "0"},
            strictVersion=False,
        )
        self.host.apps[item["app"]] = {
            "bundleId": item["bundleId"], "teamId": item["teamId"], "version": "1.0"
        }
        self.host.receipts.update(item["receipts"])
        self.host.legacy = True
        status = RECONCILE.preflight_entry(self.host, item, self.temp.name)
        self.assertEqual(status, "installed")
        self.host.legacy = False
        status = RECONCILE.preflight_entry(self.host, item, self.temp.name)
        self.assertEqual(status, "needs-install")

    def test_office_newer_receipt_prevents_downgrade(self):
        item = entry(
            name="microsoft-word",
            version="16.113.26092714",
            app="/Applications/Microsoft Word.app",
            appVersion=None,
            appVersionPrefix="16.113.",
            bundleId="com.microsoft.Word",
            teamId="UBF8T346G9",
            receipts={"com.microsoft.package.Microsoft_Word.app": "16.113.26092714"},
            strictVersion=False,
        )
        self.host.apps[item["app"]] = {
            "bundleId": item["bundleId"], "teamId": item["teamId"], "version": "16.113.4"
        }
        self.host.receipts.update({"com.microsoft.package.Microsoft_Word.app": "16.114.1"})
        self.assertEqual(
            RECONCILE.preflight_entry(self.host, item, self.temp.name), "newer"
        )

    def test_stale_newer_marker_does_not_hide_old_office_app_or_receipt(self):
        item = entry(
            name="microsoft-word",
            version="16.113.26092714",
            app="/Applications/Microsoft Word.app",
            appVersion=None,
            appVersionPrefix="16.113.",
            bundleId="com.microsoft.Word",
            teamId="UBF8T346G9",
            receipts={"com.microsoft.package.Microsoft_Word.app": "16.113.26092714"},
            strictVersion=False,
        )
        self.host.markers[item["name"]] = "16.115.0"
        self.host.apps[item["app"]] = {
            "bundleId": item["bundleId"], "teamId": item["teamId"], "version": "16.112.4"
        }
        self.host.receipts["com.microsoft.package.Microsoft_Word.app"] = "16.112.26090911"
        self.assertEqual(RECONCILE.entry_status(self.host, item, self.temp.name)[0], "needs-install")
        self.host.apps[item["app"]]["version"] = "16.113.4"
        self.assertEqual(RECONCILE.entry_status(self.host, item, self.temp.name)[0], "needs-install")

    def test_newer_office_receipt_cannot_hide_older_app(self):
        item = entry(
            name="microsoft-word",
            version="16.113.26092714",
            app="/Applications/Microsoft Word.app",
            appVersion=None,
            appVersionPrefix="16.113.",
            bundleId="com.microsoft.Word",
            teamId="UBF8T346G9",
            receipts={"com.microsoft.package.Microsoft_Word.app": "16.113.26092714"},
            strictVersion=False,
        )
        self.host.apps[item["app"]] = {
            "bundleId": item["bundleId"], "teamId": item["teamId"], "version": "16.112.4"
        }
        self.host.receipts["com.microsoft.package.Microsoft_Word.app"] = "16.114.1"
        with self.assertRaisesRegex(RuntimeError, "newer receipt has an older app"):
            RECONCILE.entry_status(self.host, item, self.temp.name)

    def test_office_update_uses_signed_pkg_and_disables_autoupdate_choice(self):
        choices = [{"choiceIdentifier": "com.microsoft.autoupdate", "choiceAttribute": "selected", "attributeSetting": 0}]
        item = entry(
            name="microsoft-word",
            version="16.113.26092714",
            app="/Applications/Microsoft Word.app",
            appVersion=None,
            appVersionPrefix="16.113.",
            bundleId="com.microsoft.Word",
            teamId="UBF8T346G9",
            receipts={"com.microsoft.package.Microsoft_Word.app": "16.113.26092714"},
            requiredReceipts=["com.microsoft.pkg.licensing"],
            packages=["/nix/store/Microsoft_Word_Installer.pkg"],
            choices=choices,
            strictVersion=False,
        )
        self.host.apps[item["app"]] = {
            "bundleId": item["bundleId"], "teamId": item["teamId"], "version": "16.112.4"
        }
        self.host.receipts["com.microsoft.package.Microsoft_Word.app"] = "16.112.26090911"
        self.host.receipts["com.microsoft.pkg.licensing"] = "16.112.26090911"

        class UpdatingHost(FakeHost):
            def install_pkg(self, path, selected_choices, state_dir):
                super().install_pkg(path, selected_choices, state_dir)
                self.apps[item["app"]] = {
                    "bundleId": item["bundleId"], "teamId": item["teamId"], "version": "16.113.4"
                }
                self.receipts["com.microsoft.package.Microsoft_Word.app"] = item["version"]

        updater = UpdatingHost()
        updater.apps = self.host.apps
        updater.receipts = self.host.receipts
        status = RECONCILE.preflight_entry(updater, item, self.temp.name)
        RECONCILE.reconcile_entry(updater, item, self.temp.name, status)
        self.assertEqual(status, "needs-install")
        self.assertEqual(updater.verified, [(item["packages"][0], "UBF8T346G9")])
        self.assertEqual(updater.installs, [(item["packages"][0], choices)])
        self.assertEqual(updater.markers["microsoft-word"], item["version"])

    def test_steam_newer_bootstrap_is_preserved(self):
        item = entry(
            name="steam",
            version="6.0",
            app="/Applications/Steam.app",
            appVersion="6.0",
            bundleId="com.valvesoftware.steam",
            teamId="MXGJJ98X76",
            receipts={},
            strictVersion=False,
            source="/nix/store/steam/Steam.app",
        )
        self.host.apps[item["app"]] = {
            "bundleId": item["bundleId"], "teamId": item["teamId"], "version": "6.1"
        }
        status = RECONCILE.preflight_entry(self.host, item, self.temp.name)
        RECONCILE.reconcile_entry(self.host, item, self.temp.name, status)
        self.assertEqual(status, "newer")
        self.assertEqual(self.host.installs, [])

    def test_mas_declared_set_skips_existing_and_rejects_missing(self):
        manifest = {"consoleUser": "test-user", "masApps": {"Pages": 409201541, "LINE": 539883307}}
        self.host.mas_ids = {409201541, 539883307}
        RECONCILE.reconcile_mas(self.host, manifest, "/nix/store/mas/bin/mas")
        self.assertEqual(self.host.mas_calls, [("test-user", "/nix/store/mas/bin/mas")])
        self.host.mas_ids.remove(539883307)
        with self.assertRaisesRegex(RuntimeError, "No purchase is attempted"):
            RECONCILE.reconcile_mas(self.host, manifest, "/nix/store/mas/bin/mas")

    def test_plan_cli_is_read_only_and_needs_no_root(self):
        state_dir = Path(self.temp.name) / "not-created"
        manifest_path = Path(self.temp.name) / "manifest.json"
        manifest = {
            "stateDir": str(state_dir),
            "consoleUser": "test-user",
            "packages": [self.item],
            "masApps": {"Pages": 409201541, "LINE": 539883307},
        }
        manifest_path.write_text(json.dumps(manifest))
        self.host.mas_ids = {409201541}
        output = io.StringIO()
        with (
            patch.object(RECONCILE, "Host", return_value=self.host),
            patch.object(RECONCILE.os, "geteuid", return_value=1000),
            patch.object(RECONCILE.sys, "argv", ["reconcile.py", "--plan", str(manifest_path), "/nix/store/mas/bin/mas"]),
            redirect_stdout(output),
        ):
            RECONCILE.main()
        result = json.loads(output.getvalue())
        self.assertEqual(result["packages"], [{"name": "karabiner-elements", "declaredVersion": "16.0.0", "status": "installed"}])
        self.assertEqual(result["masApps"], [
            {"name": "Pages", "id": 409201541, "installed": True},
            {"name": "LINE", "id": 539883307, "installed": False},
        ])
        self.assertFalse(state_dir.exists())
        self.assertEqual(self.host.markers, {})
        self.assertEqual(self.host.installs, [])
        self.assertEqual(self.host.verified, [])

    def test_mas_list_as_console_user_does_not_invoke_sudo(self):
        calls = []

        class ReadOnlyHost(RECONCILE.Host):
            def run(self, *args, check=True):
                calls.append(args)
                if args[0] == "/usr/bin/stat":
                    return SimpleNamespace(stdout="test-user\n")
                if args[0] == "/usr/bin/id":
                    return SimpleNamespace(stdout="501\n")
                return SimpleNamespace(stdout="409201541 Pages (14.4)\n")

        with patch.object(RECONCILE.os, "geteuid", return_value=501):
            installed = ReadOnlyHost().mas_list("test-user", "/nix/store/mas/bin/mas")
        self.assertEqual(installed, {409201541})
        self.assertEqual(calls[-1], ("/nix/store/mas/bin/mas", "list"))

    def test_app_replacement_can_roll_back_previous_copy(self):
        root = Path(self.temp.name)
        source = root / "source.app"
        destination = root / "Docker.app"
        source.mkdir()
        destination.mkdir()
        (source / "version").write_text("new")
        (destination / "version").write_text("old")

        class DiskHost(RECONCILE.Host):
            def run(self, *args, check=True):
                self_test.assertEqual(args[0], "/usr/bin/ditto")
                shutil.copytree(args[1], args[2])

            def app(self, path):
                if not Path(path).is_dir():
                    return None
                return {"bundleId": "com.docker.docker", "teamId": "9BNSXJN65R", "version": "4.93.0"}

        self_test = self
        host = DiskHost()
        expected = {"bundleId": "com.docker.docker", "teamId": "9BNSXJN65R", "appVersion": "4.93.0"}
        stage, backup = host.stage_app(str(source), str(destination), expected)
        self.assertEqual((destination / "version").read_text(), "new")
        self.assertEqual((backup / "version").read_text(), "old")
        host.rollback_app(str(destination), stage, backup)
        self.assertEqual((destination / "version").read_text(), "old")
        self.assertFalse(stage.exists())

    def test_self_updating_app_keeps_a_newer_regular_copy(self):
        item = entry(name="dia", version="1.51.0", appVersion="1.51.0",
                     receipts={}, packages=[], strictVersion=False, selfUpdating=True)
        self.host.apps[item["app"]]["version"] = "1.51.1"
        self.assertEqual(RECONCILE.preflight_entry(self.host, item, self.temp.name), "newer")
        self.assertEqual(self.host.installs, [])

    def test_mau_short_app_version_preserves_newer_installer_build(self):
        item = entry(name="microsoft-auto-update", version="4.85.26091737", appVersion="4.85",
                     receipts={"com.microsoft.package.Microsoft_AutoUpdate.app": "4.85.26091737"},
                     strictVersion=False)
        self.host.apps[item["app"]]["version"] = "4.85"
        self.host.receipts.update(item["receipts"])
        self.assertEqual(RECONCILE.entry_status(self.host, item, self.temp.name)[0], "installed")
        self.host.receipts["com.microsoft.package.Microsoft_AutoUpdate.app"] = "4.85.26099999"
        self.assertEqual(RECONCILE.entry_status(self.host, item, self.temp.name)[0], "newer")

    def test_root_owned_classic_is_copied_for_user_updates(self):
        import pwd
        import os
        item = entry(name="chatgpt-classic", version="1.2026.184", appVersion="1.2026.184",
                     app="/Applications/ChatGPT Classic.app", bundleId="com.openai.chat",
                     teamId="2DC432GLL2", receipts={}, packages=[], strictVersion=False,
                     selfUpdating=True, owner=pwd.getpwuid(os.getuid()).pw_name)
        self.host.apps[item["app"]] = {
            "bundleId": item["bundleId"], "teamId": item["teamId"], "version": item["version"],
            "ownerUid": 0, "ownerWritable": True, "resolvedPath": item["app"], "symlink": False,
        }
        self.assertEqual(RECONCILE.entry_status(self.host, item, self.temp.name)[0], "needs-copy")
        wanted = RECONCILE.installation_entry(self.host, item, "needs-copy")
        self.assertEqual(wanted["source"], item["app"])
        self.host.apps[item["app"]]["ownerUid"] = os.getuid()
        self.assertEqual(RECONCILE.entry_status(self.host, item, self.temp.name)[0], "installed")

    def test_newer_nix_link_is_copied_without_downgrading(self):
        item = entry(name="dia", version="1.51.0", appVersion="1.51.0",
                     receipts={}, packages=[], strictVersion=False, selfUpdating=True,
                     source="/nix/store/old/Dia.app")
        source = "/nix/store/new/Dia.app"
        self.host.apps[item["app"]].update(version="1.51.1", symlink=True, resolvedPath=source)
        self.host.apps[source] = self.host.apps[item["app"]] | {"symlink": False}
        status = RECONCILE.preflight_entry(self.host, item, self.temp.name)
        self.assertEqual(status, "needs-copy")
        RECONCILE.reconcile_entry(self.host, item, self.temp.name, status)
        self.assertEqual(self.host.apps[item["app"]]["version"], "1.51.1")
        self.assertFalse(self.host.apps[item["app"]]["symlink"])
        self.assertEqual(RECONCILE.preflight_entry(self.host, item, self.temp.name), "newer")

    def test_running_nix_link_blocks_replacement(self):
        item = entry(selfUpdating=True, source="/nix/store/app.app")
        self.host.apps[item["app"]].update(symlink=True, resolvedPath=item["source"])
        self.host.running_patterns.add("karabiner_grabber")
        with self.assertRaisesRegex(RuntimeError, "close the running"):
            RECONCILE.preflight_entry(self.host, item, self.temp.name)

    def test_early_nix_apps_migration_preflights_all_and_only_copies_legacy_links(self):
        app = Path(self.temp.name) / "boringNotch.app"
        app.symlink_to("/Applications/Nix Apps/boringNotch.app")
        early = {"name": "boringnotch", "app": str(app), "migrateBeforeNixApps": True}
        later = {"name": "cursor", "app": "/Applications/Cursor.app"}
        manifest = {"packages": [early, later], "stateDir": self.temp.name}
        path = Path(self.temp.name) / "manifest.json"
        path.write_text(json.dumps(manifest))
        with patch.object(RECONCILE.sys, "argv", ["reconcile.py", "--before-nix-apps", str(path), "mas"]), \
             patch.object(RECONCILE.os, "geteuid", return_value=0), \
             patch.object(RECONCILE, "reconcile_mas"), \
             patch.object(RECONCILE, "preflight_entry", side_effect=["needs-copy", "needs-copy"]) as preflight, \
             patch.object(RECONCILE, "reconcile_entry") as install:
            RECONCILE.main()
            self.assertEqual(preflight.call_count, 2)
            self.assertEqual(install.call_count, 1)
            self.assertEqual(install.call_args.args[1], early)

    def test_blocked_later_app_prevents_early_nix_apps_copy(self):
        app = Path(self.temp.name) / "boringNotch.app"
        app.symlink_to("/Applications/Nix Apps/boringNotch.app")
        path = Path(self.temp.name) / "manifest.json"
        path.write_text(json.dumps({"packages": [
            {"name": "boringnotch", "app": str(app), "migrateBeforeNixApps": True},
            {"name": "cursor", "app": "/Applications/Cursor.app"},
        ], "stateDir": self.temp.name}))
        with patch.object(RECONCILE.sys, "argv", ["reconcile.py", "--before-nix-apps", str(path), "mas"]), \
             patch.object(RECONCILE.os, "geteuid", return_value=0), \
             patch.object(RECONCILE, "reconcile_mas"), \
             patch.object(RECONCILE, "preflight_entry", side_effect=["needs-copy", RuntimeError("close Cursor")]), \
             patch.object(RECONCILE, "reconcile_entry") as install:
            with self.assertRaisesRegex(RuntimeError, "close Cursor"):
                RECONCILE.main()
            install.assert_not_called()

    def test_quit_chatgpt_orphan_helpers_are_cleaned_before_preflight(self):
        item = entry(
            name="chatgpt", app="/Applications/ChatGPT.app", version="26.930.41038",
            appVersion="26.930.41038", bundleId="com.openai.codex", teamId="2DC432GLL2",
            receipts={}, packages=[], strictVersion=False, selfUpdating=True,
            source="/nix/store/chatgpt/Applications/ChatGPT.app",
            running=["/ChatGPT\\.app/"],
            orphanHelpers=["browser_crashpad_handler", "bare-modifier-monitor"],
        )

        class ProcessHost(FakeHost, RECONCILE.Host):
            app_processes = RECONCILE.Host.app_processes
            running = RECONCILE.Host.running

            def __init__(self):
                super().__init__()
                self.rows = [
                    (9255, 1, "/Applications/ChatGPT.app/Contents/Frameworks/Codex Framework.framework/Versions/151.0.7922.174/Helpers/browser_crashpad_handler"),
                    (9309, 1, "/Applications/ChatGPT.app/Contents/Resources/native/bare-modifier-monitor"),
                ]
                self.terminated = []

            def run(self, *args, check=True):
                if args[0] == "/usr/bin/pgrep":
                    return SimpleNamespace(returncode=0 if self.rows else 1, stdout="", stderr="")
                if args[0] == "/bin/ps":
                    return SimpleNamespace(returncode=0, stdout="\n".join(
                        f"{pid} {parent} {command}" for pid, parent, command in self.rows
                    ), stderr="")
                if args[0] == "/bin/kill":
                    pid = int(args[-1]);self.terminated.append(pid)
                    self.rows = [row for row in self.rows if row[0] != pid]
                    return SimpleNamespace(returncode=0, stdout="", stderr="")
                raise AssertionError(args)

        host = ProcessHost()
        host.apps[item["app"]] = {
            "bundleId": item["bundleId"], "teamId": item["teamId"], "version": "26.930.31730",
        }
        host.apps[item["source"]] = host.apps[item["app"]] | {"version": item["version"]}
        self.assertEqual(RECONCILE.preflight_entry(host, item, self.temp.name), "needs-install")
        self.assertEqual(host.terminated, [9255, 9309])
        host.terminated.clear()
        helper = (9255, 1, "/Applications/ChatGPT.app/Contents/Frameworks/Codex Framework.framework/Versions/151.0.7922.174/Helpers/browser_crashpad_handler")
        for worker in [
            (35492, 1, "/Applications/ChatGPT.app/Contents/MacOS/ChatGPT"),
            (35531, 1, "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"),
        ]:
            host.rows = [helper, worker]
            with self.assertRaisesRegex(RuntimeError, "close the running app/workers"):
                RECONCILE.preflight_entry(host, item, self.temp.name)
            self.assertEqual(host.terminated, [])

    def test_symlink_copy_is_writable_and_preserves_source_and_rollback(self):
        root = Path(self.temp.name)
        source = root / "source.app"
        source.mkdir()
        (source / "version").write_text("1.51.1")
        (source / "version").chmod(0o444)
        outside = root / "user-data"
        outside.write_text("unchanged")
        outside.chmod(0o444)
        (source / "link").symlink_to(outside)
        destination = root / "Dia.app"
        destination.symlink_to(source)

        class DiskHost(RECONCILE.Host):
            def run(self, *args, check=True):
                shutil.copytree(args[1], args[2], symlinks=True)

            def app(self, path):
                p = Path(path)
                if not p.is_dir():
                    return None
                return {"bundleId": "company.thebrowser.dia", "teamId": "S6N382Y83G",
                        "version": (p / "version").read_text(), "symlink": p.is_symlink(),
                        "resolvedPath": str(p.resolve())}

        import pwd
        import os
        expected = {"bundleId": "company.thebrowser.dia", "teamId": "S6N382Y83G",
                    "appVersion": "1.51.1", "selfUpdating": True,
                    "owner": pwd.getpwuid(os.getuid()).pw_name}
        host = DiskHost()
        stage, backup = host.stage_app(str(source), str(destination), expected)
        self.assertFalse(destination.is_symlink())
        self.assertTrue((destination / "version").stat().st_mode & 0o200)
        self.assertFalse((source / "version").stat().st_mode & 0o200)
        self.assertFalse(outside.stat().st_mode & 0o200)
        self.assertEqual(outside.read_text(), "unchanged")
        host.rollback_app(str(destination), stage, backup)
        self.assertTrue(destination.is_symlink())
        self.assertEqual(destination.resolve(), source.resolve())

    def test_marker_written_and_read_atomically(self):
        host = RECONCILE.Host()
        host.write_marker(self.temp.name, "azookey", "0.1.4")
        self.assertEqual(host.marker(self.temp.name, "azookey"), "0.1.4")
        self.assertEqual(list(Path(self.temp.name).iterdir()), [Path(self.temp.name) / "azookey.json"])


if __name__ == "__main__":
    unittest.main()
