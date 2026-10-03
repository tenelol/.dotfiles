import { extensionPath } from "./extension-path.mjs";
// Run: node modules/pi-coding-agent/tests/codex-compact.test.mjs
import assert from 'node:assert/strict';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
const root = process.env.PI_PACKAGE_DIR || '/opt/homebrew/opt/pi-coding-agent/libexec/lib/node_modules/@earendil-works/pi-coding-agent';
const { loadExtensions } = await import(pathToFileURL(join(root, 'dist/core/extensions/loader.js')));
const entry = extensionPath('pi-codex-compact/dist/index.ts');
const result = await loadExtensions([entry], process.cwd());
assert.deepEqual(result.errors, []);
assert.equal(result.extensions.length, 1);
const extension = result.extensions[0];
for (const event of ['session_before_compact', 'context', 'before_provider_request']) {
  assert.equal(extension.handlers.get(event).length, 1);
}
const notices = [];
// Exercise the lazy menu import without any provider call or settings write.
await extension.commands.get('codex-compact').handler('', {
  mode: 'rpc', hasUI: true, ui: { notify: message => notices.push(message) },
});
assert.match(notices[0], /pi-codex-compact\.json/);
const compact = extension.handlers.get('session_before_compact')[0];
assert.equal(await compact({}, { model: { api: 'anthropic-messages' } }), undefined);
console.log('Codex compact loads, menu dependency resolves, and unsupported models keep native compaction');
