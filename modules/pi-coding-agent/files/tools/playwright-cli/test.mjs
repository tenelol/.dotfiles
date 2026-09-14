import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';
import { mkdtemp, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
const root = process.env.PI_PACKAGE_DIR || '/opt/homebrew/opt/pi-coding-agent/libexec/lib/node_modules/@earendil-works/pi-coding-agent';
const { loadExtensions } = await import(pathToFileURL(path.join(root,'dist/core/extensions/loader.js')));
const loaded = await loadExtensions([fileURLToPath(new URL('./index.ts',import.meta.url))],process.cwd());
assert.deepEqual(loaded.errors,[]);
const tool = loaded.extensions.find(e=>e.path.includes('/playwright-cli/')).tools.get('playwright_cli').definition;
const cwd = await mkdtemp(path.join(tmpdir(),'pi-playwright-test-'));
const id = randomUUID();
const ctx = { cwd, sessionManager: { getSessionId:()=>id } };
const call = (command,args=[])=>tool.execute('test',{command,args,timeout:60},undefined,undefined,ctx);
await assert.rejects(call('close-all'),/only this session/);
await assert.rejects(call('snapshot',['-s=another']),/overrides/);
const server = createServer((_req,res)=>{
 res.setHeader('Content-Type','text/html; charset=utf-8');
 res.end('<title>Playwright tool check</title><label>Name<input id="name"></label><button id="ok" onclick="document.querySelector(\'#status\').textContent=\'saved\'">Save</button><p id="status"></p>');
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
try {
 const open=await call('open',[`http://127.0.0.1:${server.address().port}`]);
 assert(!open.isError,JSON.stringify(open));
 const text='日本語 "quotes" ; $(not-a-shell-command)';
 const fill=await call('fill',['#name',text]); assert(!fill.isError,JSON.stringify(fill));
 const value=await call('eval',['() => document.querySelector("#name").value']);
 assert(!value.isError,JSON.stringify(value));
 assert(value.content[0].text.includes('not-a-shell-command'));
 assert.equal(value.details.session,open.details.session);
 const click=await call('click',['#ok']); assert(!click.isError,JSON.stringify(click));
 const snap=await call('snapshot'); assert(!snap.isError,JSON.stringify(snap));
 const screenshot=await call('screenshot',[`--filename=${cwd}/smoke.png`]); assert(!screenshot.isError,JSON.stringify(screenshot));
 assert.equal((await readFile(path.join(cwd,'smoke.png'))).subarray(1,4).toString(),'PNG');
 const failure=await call('click',['e999999']); assert.equal(failure.isError,true);
 console.log('PASS: tool loading, argument guards, isolated browser session, local page, CJK/quotes, click, snapshot, screenshot, CLI error propagation');
 console.log('Artifacts:',cwd);
} finally {
 const closed=await call('close');
 server.close();
 assert(!closed.isError,JSON.stringify(closed));
}
process.exit(0);
