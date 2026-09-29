// Run: node modules/pi-coding-agent/tests/skill-catalog.test.mjs
import assert from "node:assert/strict";
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = process.env.PI_PACKAGE_DIR || "/opt/homebrew/opt/pi-coding-agent/libexec/lib/node_modules/@earendil-works/pi-coding-agent";
const { DefaultResourceLoader } = await import(pathToFileURL(join(root, "dist/core/resource-loader.js")));
const { AgentSession } = await import(pathToFileURL(join(root, "dist/core/agent-session.js")));
const { formatSkillsForPrompt } = await import(pathToFileURL(join(root, "dist/core/skills.js")));
const files = new URL("../files/", import.meta.url);
const catalog = JSON.parse(readFileSync(new URL("skill-catalog.json", files), "utf8"));
const temporary = mkdtempSync(join(tmpdir(), "pi-skill-catalog-"));
const agentDir = join(temporary, "agent");
const project = join(temporary, ".dotfiles");
try {
  mkdirSync(join(agentDir, "skills"), { recursive: true });
  mkdirSync(join(project, ".pi"), { recursive: true });
  mkdirSync(join(project, ".agents/skills/unreviewed"), { recursive: true });
  writeFileSync(join(project, ".agents/skills/unreviewed/SKILL.md"), "---\nname: unreviewed\ndescription: A foreign-harness fixture.\n---\nCall the Skill tool.\n");
  copyFileSync(new URL("settings.json", files), join(agentDir, "settings.json"));
  copyFileSync(new URL("dotfiles-project-settings.json", files), join(project, ".pi/settings.json"));
  for (const name of catalog.shared) {
    symlinkSync(fileURLToPath(new URL(`../../../.agents/skills/${name}`, import.meta.url)), join(agentDir, "skills", name));
  }
  for (const [name, relative] of Object.entries(catalog.extensions)) {
    const target = relative.startsWith("extensions/playwright-cli/")
      ? relative.replace("extensions/playwright-cli/", "tools/playwright-cli/") : relative;
    symlinkSync(fileURLToPath(new URL(target, files)), join(agentDir, "skills", name));
  }
  if (process.env.HERDR_SOURCE) symlinkSync(join(process.env.HERDR_SOURCE, "skills/herdr"), join(agentDir, "skills/herdr"));
  const ports = new URL("skills/", files);
  if (existsSync(ports)) {
    for (const name of readdirSync(ports)) symlinkSync(fileURLToPath(new URL(name, ports)), join(agentDir, "skills", name));
  }
  const loader = new DefaultResourceLoader({ cwd: project, agentDir, noExtensions: true });
  await loader.reload();
  const { skills, diagnostics } = loader.getSkills();
  assert.equal(diagnostics.length, 0, JSON.stringify(diagnostics));
  assert.ok(skills.every((skill) => skill.filePath.startsWith(join(agentDir, "skills"))), "Unselected shared and dotfiles project skills are not exposed");
  const names = skills.map((skill) => skill.name);
  for (const name of [...catalog.shared, "grill-me", "diagnosing-bugs", "computer-use", "pi-subagents", "council-mode", "playwright-cli", "ponytail"]) assert.ok(names.includes(name), `${name} is available`);
  if (process.env.HERDR_SOURCE) assert.ok(names.includes("herdr"));
  for (const name of ["unreviewed", "subagent-model-router", "grill-with-docs", "wayfinder", "e-tax"]) assert.ok(!names.includes(name), `${name} stays out of the Pi catalog`);
  assert.equal(skills.find((skill) => skill.name === "grill-me").disableModelInvocation, true);
  assert.doesNotMatch(formatSkillsForPrompt(skills), /<name>grill-me<\/name>/, "The explicit-only interview alias stays out of implicit skill selection");
  const expanded = AgentSession.prototype._expandSkillCommand.call({ resourceLoader: loader }, "/skill:grill-me Review this plan");
  assert.match(expanded, /Then wait for the user's answers before the next round/);
  assert.doesNotMatch(expanded, /Skill tool|\/skill:grill-me/);
  for (const name of [...catalog.shared, "grill-me", "diagnosing-bugs"]) {
    const skill = skills.find((entry) => entry.name === name);
    assert.doesNotMatch(readFileSync(skill.filePath, "utf8"), /Skill tool|AskUserQuestion|TodoWrite|subagent_type/, `${name} has no foreign tool requirement`);
  }
  const domain = skills.find((skill) => skill.name === "domain-modeling");
  assert.ok(existsSync(join(domain.baseDir, "CONTEXT-FORMAT.md")), "Shared references remain available");
  const pve = skills.find((skill) => skill.name === "proxmox-pve");
  const pvePrompt = AgentSession.prototype._expandSkillCommand.call({ resourceLoader: loader }, "/skill:proxmox-pve Inspect node status");
  assert.match(pvePrompt, /# Proxmox VE Operations/);
  for (const helper of ["pve-api.sh", "pve-node-ssh.sh", "pve-lxc-exec.sh", "load-config.sh"]) assert.ok(existsSync(join(pve.baseDir, "scripts", helper)), `Proxmox helper ${helper} is available`);
  console.log(`Pi curated catalog: ${skills.length} skills; native grill-me expansion, exclusions and shared references passed`);
} finally {
  rmSync(temporary, { recursive: true, force: true });
}
