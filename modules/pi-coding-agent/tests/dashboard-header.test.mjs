// Run: node modules/pi-coding-agent/tests/dashboard-header.test.mjs
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { stripVTControlCharacters } from "node:util";

process.env.PI_CODING_AGENT_DIR = fileURLToPath(new URL("../files", import.meta.url));
const root = process.env.PI_PACKAGE_DIR || "/opt/homebrew/opt/pi-coding-agent/libexec/lib/node_modules/@earendil-works/pi-coding-agent";
const { loadExtensions } = await import(pathToFileURL(join(root, "dist/core/extensions/loader.js")));
const path = fileURLToPath(new URL("../files/extensions/dashboard-header.ts", import.meta.url));
const { extensions, errors } = await loadExtensions([path], process.cwd());
assert.deepEqual(errors, []);
const start = extensions[0].handlers.get("session_start")[0];
const art = readFileSync(new URL("../files/art/dashboard-character.txt", import.meta.url), "utf8").trimEnd().split("\n");
const logo = ["██████╗ ██╗", "██╔══██╗██║", "██████╔╝██║", "██╔═══╝ ██║", "██║     ██║", "╚═╝     ╚═╝"];
let component;
await start({ reason: "startup" }, {
	mode: "tui",
	ui: { setHeader: (factory) => { component = factory({}, { fg: (_color, text) => `\x1b[34m${text}\x1b[0m` }); } },
});
assert.ok(component);
for (const width of [120, 80, 65, 40, 11, 1, 0, 160]) {
	const lines = component.render(width).map(stripVTControlCharacters);
	assert.equal(lines.length, art.length + logo.length + 1, "character immediately followed by PI logo, then bottom spacing");
	assert.ok(lines.every((line) => [...line].length <= width), `overflow at ${width} columns`);
	for (const [block, offset] of [[art, 0], [logo, art.length]]) {
		const blockWidth = Math.max(...block.map((line) => [...line].length));
		if (width < blockWidth) continue;
		const padding = Math.floor((width - blockWidth) / 2);
		assert.deepEqual(lines.slice(offset, offset + block.length), block.map((line) => " ".repeat(padding) + line));
	}
}
for (const mode of ["rpc", "json", "print"]) {
	await start({ reason: "startup" }, { mode, ui: { setHeader: () => assert.fail(`header in ${mode} mode`) } });
}
component.invalidate();
console.log("dashboard header: centered character + PI, resize, and non-TUI checks passed");
