// Run: node modules/pi-coding-agent/tests/settings-startup.test.mjs
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const root = process.env.PI_PACKAGE_DIR || "/opt/homebrew/opt/pi-coding-agent/libexec/lib/node_modules/@earendil-works/pi-coding-agent";
const { InteractiveMode } = await import(pathToFileURL(join(root, "dist/modes/interactive/interactive-mode.js")));
const settings = JSON.parse(readFileSync(new URL("../files/settings.json", import.meta.url), "utf8"));
const changelog = InteractiveMode.prototype.getChangelogForDisplay.call({
  session: { state: { messages: [] } },
  settingsManager: {
    getLastChangelogVersion: () => settings.lastChangelogVersion,
    setLastChangelogVersion: () => assert.fail("Update the declared changelog version before using read-only settings with this Pi version"),
  },
  reportInstallTelemetry: () => assert.fail("No install telemetry during this check"),
});
assert.equal(changelog, undefined);
console.log("Pi startup does not attempt to rewrite the declared read-only settings");
