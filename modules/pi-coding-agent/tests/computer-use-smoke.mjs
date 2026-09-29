// Opt-in macOS GUI test: node modules/pi-coding-agent/tests/computer-use-smoke.mjs
// Playwright owns the disposable window and reads results; only Peekaboo changes controls.
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { setTimeout } from "node:timers/promises";
import { fileURLToPath, pathToFileURL } from "node:url";
import { chromium } from "../files/tools/playwright-cli/node_modules/playwright/index.mjs";

assert.equal(process.platform, "darwin");
const root = process.env.PI_PACKAGE_DIR || "/opt/homebrew/opt/pi-coding-agent/libexec/lib/node_modules/@earendil-works/pi-coding-agent";
const { loadExtensions } = await import(pathToFileURL(join(root, "dist/core/extensions/loader.js")));
const loaded = await loadExtensions([fileURLToPath(new URL("../files/tools/computer-use/index.ts", import.meta.url))], process.cwd());
assert.deepEqual(loaded.errors, []);
const tool = loaded.extensions[0].tools.get("computer_use").definition;
const artifacts = await mkdtemp(join(tmpdir(), "pi-computer-use-smoke-"));
const title = `Pi computer use ${randomUUID()}`;
const session = randomUUID();
const ctx = { cwd: artifacts, sessionManager: { getSessionId: () => session } };
async function call(params) {
  const result = await tool.execute("smoke", params, undefined, undefined, ctx);
  const needsReadback = ["click", "set_value"].includes(params.action) && ["indeterminate", "dispatched_unverified"].includes(result.details.state);
  assert(!result.isError || needsReadback, result.content[0].text);
  if (params.action === "observe") assert(result.content.some(item => item.type === "image"));
  console.log(`${params.action}: ${result.details.state}`);
  return result.details.data;
}
const browser = await chromium.launch({
  channel: "chrome", headless: false,
  args: ["--force-renderer-accessibility"], // Keep the disposable page's AX tree available in the background.
});
try {
  const page = await browser.newPage({ viewport: { width: 800, height: 600 } });
  await page.setContent(`<title>${title}</title>
    <style>body{font:24px system-ui;padding:40px}input,button{font:24px system-ui;margin:20px}</style>
    <h1>Pi computer use test</h1><label>Test value<input id="value"></label>
    <button id="verify">Verify native click</button><p id="count">0</p>
    <script>window.clickLog=[];document.querySelector('#verify').onclick=e=>{
      clickLog.push({trusted:e.isTrusted,value:document.querySelector('#value').value});
      document.querySelector('#count').textContent=clickLog.length;
    }</script>`);
  let target;
  for (let attempt = 0; attempt < 5 && !target; attempt++) {
    const inventory = await call({ action: "windows", app: "Google Chrome" });
    target = inventory.windows.find(window => window.window_title === title);
    if (!target) await setTimeout(300);
  }
  assert(target, "Disposable test window must be identifiable");
  const windowID = target.window_id;
  async function observe() {
    for (let attempt = 0; ; attempt++) {
      try {
        return await call({ action: "observe", window_id: windowID });
      } catch (error) {
        // Read-only retry while Rift settles a newly opened window; never retry a mutation.
        if (attempt >= 2 || !/SNAPSHOT_STALE|target changed during capture/.test(error.message)) throw error;
        await setTimeout(300);
      }
    }
  }
  async function control(role, label) {
    // Chromium may expose its page AX tree after the first observation.
    for (let attempt = 0; attempt < 3; attempt++) {
      const observation = await observe();
      const element = observation.elements.find(entry => entry.role === role && entry.label === label);
      if (element) return { observation, element };
      await setTimeout(300);
    }
    assert.fail(`Current exact-window UI map lacks ${label}`);
  }
  const field = await control("textField", "Test value");
  assert.deepEqual(await page.evaluate(() => window.clickLog), []);
  assert(field.element.is_value_settable);
  const value = `Pi-${randomUUID()}`;
  await call({ action: "set_value", observation: field.observation.observation, element_id: field.element.id, text: value });
  assert.equal(await page.inputValue("#value"), value);
  for (let count = 1; count <= 3; count++) {
    const button = await control("button", "Verify native click");
    assert.equal(await page.evaluate(() => window.clickLog.length), count - 1);
    await call({ action: "click", observation: button.observation.observation, element_id: button.element.id });
    const clicks = await page.evaluate(() => window.clickLog);
    assert.deepEqual(clicks, Array.from({ length: count }, () => ({ trusted: true, value })));
    console.log(`Verified click ${count}, matching typed value, trusted event`);
  }
  await observe();
  console.log("PASS: Pi computer_use tool, inline screenshots, text input and three verified clicks");
} finally {
  await browser.close();
  console.log("Artifacts:", artifacts);
}
