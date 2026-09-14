// Run: node modules/pi-coding-agent/tests/skill-discovery.test.mjs
import assert from "node:assert/strict";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const piRoot = process.env.PI_PACKAGE_DIR || "/opt/homebrew/opt/pi-coding-agent/libexec/lib/node_modules/@earendil-works/pi-coding-agent";
const { DefaultResourceLoader } = await import(pathToFileURL(join(piRoot, "dist/core/resource-loader.js")));
const temporary = mkdtempSync(join(tmpdir(), "pi-skill-discovery-"));
const project = join(temporary, "project");
const agentDir = join(temporary, "agent");
const name = "fixture-shared-skill";
const projectSkill = join(project, ".agents/skills", name, "SKILL.md");
const userSkill = join(agentDir, "skills", name, "SKILL.md");
const readSkills = async (cwd) => {
  const loader = new DefaultResourceLoader({ cwd, agentDir, noExtensions: true });
  await loader.reload();
  return loader.getSkills();
};
try {
  for (const file of [projectSkill, userSkill]) {
    mkdirSync(join(file, ".."), { recursive: true });
    writeFileSync(file, `---\nname: ${name}\ndescription: Test shared skill discovery.\n---\n`);
  }
  const before = await readSkills(project);
  assert.ok(before.diagnostics.some(d => d.collision?.name === name));
  mkdirSync(join(project, ".pi"));
  const policy = new URL("../files/dotfiles-project-settings.json", import.meta.url);
  writeFileSync(join(project, ".pi/settings.json"), existsSync(policy) ? readFileSync(policy) : "{}");
  const after = await readSkills(project);
  assert.equal(after.skills.find(s => s.name === name)?.filePath, userSkill);
  assert.ok(!after.diagnostics.some(d => d.collision?.name === name));
  const elsewhere = await readSkills(temporary);
  assert.equal(elsewhere.skills.find(s => s.name === name)?.filePath, userSkill);
  console.log("Project duplicate excluded; the shared skill remains available here and elsewhere");
} finally {
  rmSync(temporary, { recursive: true, force: true });
}
