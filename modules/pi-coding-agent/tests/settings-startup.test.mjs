// Run: node modules/pi-coding-agent/tests/settings-startup.test.mjs
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { piPackageRoot } from "./extension-path.mjs";

const root = piPackageRoot();
const { InteractiveMode } = await import(pathToFileURL(join(root, "dist/modes/interactive/interactive-mode.js")));
const { settings } = JSON.parse(execFileSync("nix-instantiate", ["--eval", "--strict", "--json", fileURLToPath(new URL("extensions.nix-test", import.meta.url))], { encoding: "utf8" }));
const changelog = InteractiveMode.prototype.getChangelogForDisplay.call({
  session: { state: { messages: [] } },
  settingsManager: {
    getLastChangelogVersion: () => settings.lastChangelogVersion,
    setLastChangelogVersion: () => assert.fail("Generated settings must acknowledge the packaged Pi version without a startup write"),
  },
  reportInstallTelemetry: () => assert.fail("No install telemetry during this check"),
});
assert.equal(changelog, undefined);
console.log("Pi startup does not attempt to rewrite the declared read-only settings");
