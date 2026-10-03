import { extensionPath } from "./extension-path.mjs";
// Run: node modules/pi-coding-agent/tests/ui-settings.test.mjs
import assert from "node:assert/strict";
import { copyFileSync, existsSync, mkdtempSync, rmSync } from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { stripVTControlCharacters } from "node:util";

const root = process.env.PI_PACKAGE_DIR || "/opt/homebrew/opt/pi-coding-agent/libexec/lib/node_modules/@earendil-works/pi-coding-agent";
const require = createRequire(join(root, "package.json"));
const { createJiti } = require("jiti");
const temporary = mkdtempSync(join(tmpdir(), "pi-ui-settings-"));
process.env.PI_CODING_AGENT_DIR = temporary;
const files = new URL("../files/", import.meta.url);
try {
  copyFileSync(new URL("pi-tool-display.json", files), join(temporary, "pi-tool-display.json"));
  const zentuiConfig = new URL("zentui.json", files);
  if (existsSync(zentuiConfig)) copyFileSync(zentuiConfig, join(temporary, "zentui.json"));
  const { loadExtensions } = await import(pathToFileURL(join(root, "dist/core/extensions/loader.js")));
  const { extensions, errors } = await loadExtensions([extensionPath("pi-tool-display/index.ts")], temporary);
  assert.deepEqual(errors, []);
  const theme = { fg: (_color, text) => text, bg: (_color, text) => text, bold: (text) => text };
  const result = { content: [{ type: "text", text: Array.from({ length: 8 }, (_, i) => `probe line ${i + 1}`).join("\n") }], details: {} };
  for (const name of ["read", "grep", "bash"]) {
    const tool = extensions[0].tools.get(name).definition;
    const render = (expanded) => stripVTControlCharacters(tool.renderResult(result, { expanded, isPartial: false }, theme).render(80).join("\n"));
    const compact = render(false);
    assert.match(compact, /probe line 1/, `${name} shows actual results without expanding`);
    assert.doesNotMatch(compact, /probe line 8/, `${name} keeps long output compact`);
    assert.match(render(true), /probe line 8/, `${name} retains expandable full output`);
  }
  const jiti = createJiti(import.meta.url, {
    moduleCache: false,
    alias: {
      "@earendil-works/pi-coding-agent": join(root, "dist/index.js"),
      "@earendil-works/pi-tui": require.resolve("@earendil-works/pi-tui"),
    },
  });
  const configStore = await jiti.import(extensionPath("pi-tool-display/src/config-store.ts"));
  assert.equal(configStore.getToolDisplayConfigPath(), join(temporary, "pi-tool-display.json"));
  const changedConfig = { ...configStore.loadToolDisplayConfig().config, previewLines: 7 };
  assert.equal(configStore.saveToolDisplayConfig(changedConfig).success, true,
    "Settings remain writable when the extension lives in the Nix store");
  assert.equal(configStore.loadToolDisplayConfig().config.previewLines, 7);
  const { loadConfig } = await jiti.import(extensionPath("pi-zentui/extensions/zentui/config.ts"));
  const { workingLine } = loadConfig().components;
  assert.equal(workingLine.enabled, true);
  assert.equal(workingLine.turnSummary, true);
  assert.equal(workingLine.messages.custom, false);
  assert.equal(workingLine.segments.tool, true);
  assert.equal(workingLine.segments.elapsed, true);
  const { renderTurnSummaryEntry } = await jiti.import(extensionPath("pi-zentui/extensions/zentui/interaction-summary.ts"));
  const summary = renderTurnSummaryEntry({ data: {
    version: 3, durationMs: 56000, thoughtDurationMs: 10000, input: 7100, output: 779, stylePrefix: "\x1b[36m",
  } }, {}, theme).render(80).map(stripVTControlCharacters);
  assert.equal(summary.length, 1);
  assert.match(summary[0], /Turn took 56s.*thought for 10s.*↑7.1k ↓779/);
  console.log("Pi UI: compact readable previews, expanded output, working status and turn summary enabled");
} finally {
  rmSync(temporary, { recursive: true, force: true });
}
