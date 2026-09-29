// Run: node modules/pi-coding-agent/tests/notify.test.mjs
import assert from "node:assert/strict";
import { join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = process.env.PI_PACKAGE_DIR || "/opt/homebrew/opt/pi-coding-agent/libexec/lib/node_modules/@earendil-works/pi-coding-agent";
const { loadExtensions } = await import(pathToFileURL(join(root, "dist/core/extensions/loader.js")));
const { extensions, errors } = await loadExtensions([fileURLToPath(new URL("../files/hooks/notify.ts", import.meta.url))], process.cwd());
assert.deepEqual(errors, []);
const handlers = extensions[0].handlers;
assert.equal(handlers.has("agent_end"), false, "Do not notify before retries or queued continuations settle");
const settled = handlers.get("agent_settled")[0];
const output = [];
const originalWrite = process.stdout.write;
const originalHerdrEnv = process.env.HERDR_ENV;
try {
  process.stdout.write = (text) => { output.push(text); return true; };
  for (const mode of ["rpc", "json", "print"]) await settled({}, { mode });
  assert.deepEqual(output, [], "Headless child agents must not notify the terminal");
  process.env.HERDR_ENV = "1";
  await settled({}, { mode: "tui" });
  assert.deepEqual(output, [], "Herdr owns notifications inside its panes");
  delete process.env.HERDR_ENV;
  await settled({}, { mode: "tui" });
} finally {
  process.stdout.write = originalWrite;
  if (originalHerdrEnv === undefined) delete process.env.HERDR_ENV;
  else process.env.HERDR_ENV = originalHerdrEnv;
}
assert.deepEqual(output, ["\x1b]777;notify;Pi;処理が終了し、入力待ちになりました。\x07"]);
console.log("Pi notification: only settled interactive runs emit one Ghostty notification");
