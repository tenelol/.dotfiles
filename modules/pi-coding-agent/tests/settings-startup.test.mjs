// Run: node modules/pi-coding-agent/tests/settings-startup.test.mjs
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { realpathSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = process.env.PI_PACKAGE_DIR || join(dirname(dirname(realpathSync(execFileSync("which", ["pi"], { encoding: "utf8" }).trim()))), "lib/node_modules/pi-monorepo");
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
