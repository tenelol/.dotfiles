// Run: node modules/pi-coding-agent/tests/upstream-extensions.test.mjs
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { extensionPath } from './extension-path.mjs';
const root = process.env.PI_PACKAGE_DIR || '/opt/homebrew/opt/pi-coding-agent/libexec/lib/node_modules/@earendil-works/pi-coding-agent';
const sources = JSON.parse(readFileSync(new URL('../../../packages/pi-extensions/sources.json', import.meta.url)));
const temporary = mkdtempSync(join(tmpdir(), 'pi-upstream-extensions-'));
process.env.PI_CODING_AGENT_DIR = temporary;
try {
  const { loadExtensions } = await import(pathToFileURL(join(root, 'dist/core/extensions/loader.js')));
  const paths = [];
  for (const [name, source] of Object.entries(sources)) {
    const dir = extensionPath(name);
    const pkg = JSON.parse(readFileSync(join(dir, 'package.json')));
    assert.equal(pkg.name, source.name);
    assert.equal(pkg.version, source.version);
    for (const entry of pkg.pi.extensions) paths.push(join(dir, entry));
  }
  const result = await loadExtensions(paths, temporary);
  assert.deepEqual(result.errors, []);
  assert.equal(result.extensions.length, Object.keys(sources).length);
  const prompts = JSON.parse(readFileSync(new URL('../files/prompt-catalog.json', import.meta.url)));
  for (const prompt of prompts) assert.ok(existsSync(extensionPath(`pi-subagents/prompts/${prompt}`)));
  console.log(`${result.extensions.length} pinned/patched extensions load with their dependencies; subagent prompts remain available`);
} finally {
  rmSync(temporary, { recursive: true, force: true });
}
