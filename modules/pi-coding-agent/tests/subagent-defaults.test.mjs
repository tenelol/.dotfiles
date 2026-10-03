import { extensionPath } from "./extension-path.mjs";
// Run: node modules/pi-coding-agent/tests/subagent-defaults.test.mjs
import assert from "node:assert/strict";
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, rmSync, symlinkSync } from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = process.env.PI_PACKAGE_DIR || "/opt/homebrew/opt/pi-coding-agent/libexec/lib/node_modules/@earendil-works/pi-coding-agent";
const require = createRequire(join(root, "package.json"));
const { createJiti } = require("jiti");
const temporary = mkdtempSync(join(tmpdir(), "pi-subagent-defaults-"));
process.env.PI_CODING_AGENT_DIR = join(temporary, "agent");
try {
  mkdirSync(process.env.PI_CODING_AGENT_DIR);
  const project = join(temporary, "project");
  mkdirSync(project);
  copyFileSync(new URL("../files/settings.json", import.meta.url), join(process.env.PI_CODING_AGENT_DIR, "settings.json"));
  const browserDefinition = new URL("../files/agents/browser.md", import.meta.url);
  if (existsSync(browserDefinition)) {
    mkdirSync(join(process.env.PI_CODING_AGENT_DIR, "agents"));
    copyFileSync(browserDefinition, join(process.env.PI_CODING_AGENT_DIR, "agents/browser.md"));
  }
  mkdirSync(join(process.env.PI_CODING_AGENT_DIR, "extensions"));
  symlinkSync(fileURLToPath(new URL("../files/tools/playwright-cli", import.meta.url)), join(process.env.PI_CODING_AGENT_DIR, "extensions/playwright-cli"));
  const jiti = createJiti(import.meta.url, { moduleCache: false });
  const { discoverAgents } = await jiti.import(extensionPath("pi-subagents/src/agents/agents.ts"));
  const { agents } = discoverAgents(project, "user", "openai-codex");
  for (const name of ["scout", "researcher", "worker", "reviewer", "oracle", "evidence-auditor", "delegate"]) {
    const agent = agents.find((entry) => entry.name === name);
    assert.ok(agent, `${name} is discovered`);
    assert.equal(agent.model, "openai-codex/gpt-6-sol", `${name} has its own model default`);
    assert.equal(agent.thinking, "xhigh", `${name} overrides bundled thinking defaults`);
  }
  const browser = agents.find((entry) => entry.name === "browser");
  assert.ok(browser, "The browser role is available to native delegation");
  assert.equal(browser.model, "openai-codex/gpt-6-sol");
  assert.equal(browser.thinking, "xhigh");
  assert.deepEqual(browser.tools, ["read", "playwright_cli"]);
  const { loadExtensions } = await import(pathToFileURL(join(root, "dist/core/extensions/loader.js")));
  const { extensions, errors } = await loadExtensions(browser.extensions, project);
  assert.deepEqual(errors, []);
  assert.ok(extensions[0].tools.has("playwright_cli"), "Browser tool provider loads through the agent's declared path");
  console.log("Pi subagent defaults and the browser role's restricted tool/provider wiring passed");
} finally {
  rmSync(temporary, { recursive: true, force: true });
}
