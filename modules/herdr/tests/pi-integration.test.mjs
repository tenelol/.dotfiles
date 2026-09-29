// Run: HERDR_SOURCE=<locked Herdr source directory> node modules/herdr/tests/pi-integration.test.mjs
import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { mkdtempSync, rmSync } from "node:fs";
import net from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createInterface } from "node:readline";
import { fileURLToPath, pathToFileURL } from "node:url";

const source = process.env.HERDR_SOURCE;
assert.ok(source, "Set HERDR_SOURCE to the source pinned by flake.lock");
const piRoot = process.env.PI_PACKAGE_DIR || "/opt/homebrew/opt/pi-coding-agent/libexec/lib/node_modules/@earendil-works/pi-coding-agent";
const { loadExtensions } = await import(pathToFileURL(join(piRoot, "dist/core/extensions/loader.js")));
const { loadSkillsFromDir } = await import(pathToFileURL(join(piRoot, "dist/core/skills.js")));
const { createEventBus } = await import(pathToFileURL(join(piRoot, "dist/core/event-bus.js")));
const temporary = mkdtempSync(join(tmpdir(), "herdr-pi-"));
const events = new EventEmitter();
const requests = [];
const server = net.createServer((socket) => {
  createInterface({ input: socket }).on("line", (line) => {
    const request = JSON.parse(line);
    requests.push(request);
    socket.write("{\"result\":{}}\n");
    events.emit("request", request);
  });
});
process.env.HERDR_ENV = "1";
process.env.HERDR_SOCKET_PATH = join(temporary, "s");
process.env.HERDR_PANE_ID = "fixture-pane";
try {
  await new Promise((resolve) => server.listen(process.env.HERDR_SOCKET_PATH, resolve));
  const bus = createEventBus();
  const blockedEvents = [];
  bus.on("herdr:blocked", (event) => blockedEvents.push(event));
  const loaded = await loadExtensions([
    join(source, "src/integration/assets/pi/herdr-agent-state.ts"),
    fileURLToPath(new URL("../../pi-coding-agent/files/hooks/herdr-ui.ts", import.meta.url)),
  ], temporary, bus);
  assert.deepEqual(loaded.errors, []);
  const hook = loaded.extensions[0];
  const call = (name, event, ctx) => hook.handlers.get(name)[0](event, ctx);
  let idle = true;
  const ctx = { mode: "tui", isIdle: () => idle, sessionManager: {
    getSessionFile: () => join(temporary, "session.jsonl"), getSessionId: () => "fixture-session",
  } };
  await call("session_start", { reason: "startup" }, { ...ctx, mode: "rpc" });
  await call("agent_start", {}, ctx);
  assert.equal(requests.length, 0, "Headless children never publish to the parent pane");
  const transition = async (state, action) => {
    const observed = new Promise((resolve, reject) => {
      const timer = setTimeout(() => { events.off("request", onRequest); reject(new Error(`Missing ${state} state`)); }, 2000);
      const onRequest = (request) => {
        if (request.method !== "pane.report_agent" || request.params.state !== state) return;
        clearTimeout(timer);
        events.off("request", onRequest);
        resolve();
      };
      events.on("request", onRequest);
    });
    await action();
    await observed;
  };
  await transition("idle", () => call("session_start", { reason: "startup" }, ctx));
  idle = false;
  await transition("working", () => call("agent_start", {}, ctx));
  const uiCall = (name, context) => loaded.extensions[1].handlers.get(name)[0]({}, context);
  await uiCall("ui_prompt_start", { ...ctx, mode: "rpc" });
  assert.equal(blockedEvents.length, 0, "Headless UI events cannot block the parent pane");
  await transition("blocked", () => uiCall("ui_prompt_start", ctx));
  await transition("working", () => uiCall("ui_prompt_end", ctx));
  assert.equal(hook.handlers.has("agent_end"), false, "Only settled runs become idle");
  idle = true;
  await transition("idle", () => call("agent_settled", {}, ctx));
  assert.ok(requests.some((request) => request.method === "pane.report_agent_session"));
  for (const request of requests) {
    assert.equal(request.params.pane_id, "fixture-pane");
    assert.equal(request.params.source, "herdr:pi");
    assert.equal(request.params.agent_session_path, join(temporary, "session.jsonl"));
  }
  const skills = loadSkillsFromDir({ dir: join(source, "skills/herdr"), source: "path" });
  assert.deepEqual(skills.diagnostics, []);
  assert.equal(skills.skills[0].name, "herdr");
  console.log("Pinned Herdr hook: Pi 0.85 lifecycle, root-pane gating, session metadata and official skill passed");
} finally {
  await new Promise((resolve) => server.close(resolve));
  rmSync(temporary, { recursive: true, force: true });
}
