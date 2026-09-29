// Run: node modules/pi-coding-agent/tests/computer-use.test.mjs
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
const dir = await mkdtemp(join(tmpdir(), 'pi-computer-use-test-'));
const priorPath = process.env.PATH;
const priorFixture = process.env.PEEKABOO_TEST_DIR;
try {
  await writeFile(join(dir, 'peekaboo'), `#!${process.execPath}
const fs = require('node:fs');
const a = process.argv.slice(2);
const flag = name => a.find(x=>x.startsWith('--'+name+'='))?.slice(name.length+3);
fs.appendFileSync(process.env.PEEKABOO_TEST_DIR+'/calls.jsonl', JSON.stringify(a)+'\\n');
let result;
if(a[0]==='window') result={success:true,data:{windows:[{window_id:42,window_title:'Fixture'}]}};
else if(a[0]==='see') {
 fs.writeFileSync(flag('path'),Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC','base64'));
 result={success:true,target_receipt:{window_id:42,pid:123},data:{snapshot_id:'fixture-snapshot',snapshot_reusable:true,mutation_targeting_available:true,window_title:'Fixture',ui_elements:[{id:'elem_1',role:'button',label:'Save',is_actionable:true},{id:'elem_2',role:'textField',label:'Name',is_value_settable:true}]}};
} else {
 const state=fs.readFileSync(process.env.PEEKABOO_TEST_DIR+'/state','utf8');
 if(state==='malformed') {console.log('bad JSON');process.exit(1);}
 result={success:state!=='indeterminate',outcome:{state,mutation_dispatched:true,effect:state==='confirmed_change'?'confirmed':'unverifiable'}};
}
console.log(JSON.stringify(result));
`, { mode: 0o700 });
  await writeFile(join(dir, 'state'), 'dispatched_unverified');
  process.env.PATH = `${dir}:${priorPath}`;
  process.env.PEEKABOO_TEST_DIR = dir;
  const root = process.env.PI_PACKAGE_DIR || '/opt/homebrew/opt/pi-coding-agent/libexec/lib/node_modules/@earendil-works/pi-coding-agent';
  const { loadExtensions } = await import(pathToFileURL(join(root,'dist/core/extensions/loader.js')));
  const loaded = await loadExtensions([fileURLToPath(new URL('../files/tools/computer-use/index.ts',import.meta.url))],dir);
  assert.deepEqual(loaded.errors,[]);
  const tool = loaded.extensions[0].tools.get('computer_use').definition;
  assert.equal(tool.executionMode,'sequential');
  const ctx = {cwd:dir,sessionManager:{getSessionId:()=> 'session-a'}};
  const call = (params, context=ctx) => tool.execute('test',params,undefined,undefined,context);
  const observe = () => call({action:'observe',window_id:42});
  assert.equal((await call({action:'windows',app:'Fixture'})).isError,false);
  let seen=await observe();
  assert(seen.content.some(c=>c.type==='image'),JSON.stringify(seen));
  assert(seen.details.observation);
  const before=await readFile(join(dir,'calls.jsonl'),'utf8');
  await assert.rejects(call({action:'click',observation:seen.details.observation,element_id:'elem_999'}),/element/i);
  await assert.rejects(call({action:'click',observation:seen.details.observation,element_id:'elem_1',window_id:99}),/observation/i);
  await assert.rejects(call({action:'click',observation:seen.details.observation,element_id:'elem_1'}, {...ctx,sessionManager:{getSessionId:()=> 'session-b'}}),/observ/i);
  assert.equal(await readFile(join(dir,'calls.jsonl'),'utf8'),before,'Invalid references never dispatch');
  let action=await call({action:'click',observation:seen.details.observation,element_id:'elem_1'});
  assert.equal(action.details.state,'dispatched_unverified');
  assert.match(action.content[0].text,/未確認/);
  await assert.rejects(call({action:'click',observation:seen.details.observation,element_id:'elem_1'}),/observ/i);
  seen=await observe();
  const old=seen.details.observation;
  seen=await observe();
  await assert.rejects(call({action:'click',observation:old,element_id:'elem_1'}),/observ/i);
  await writeFile(join(dir,'state'),'confirmed_change');
  const literal='--foreground ; $(not-a-command) 日本語';
  action=await call({action:'set_value',observation:seen.details.observation,element_id:'elem_2',text:literal});
  assert.equal(action.details.state,'confirmed_change');
  let calls=(await readFile(join(dir,'calls.jsonl'),'utf8')).trim().split('\n').map(JSON.parse);
  const set=calls.at(-1);
  assert(set.includes('--value='+literal),'Text stays one literal argument');
  assert(set.includes('--snapshot=fixture-snapshot'));
  assert(!set.some(a=>a.startsWith('--window-id')),'set-value rejects snapshot plus window selectors');
  assert(calls.every(a=>a.includes('--no-remote') && a.includes('--json')));
  seen=await observe();
  await writeFile(join(dir,'state'),'indeterminate');
  action=await call({action:'click',observation:seen.details.observation,element_id:'elem_1'});
  assert.equal(action.details.state,'indeterminate');
  await assert.rejects(call({action:'click',observation:seen.details.observation,element_id:'elem_1'}),/observ/i);
  seen=await observe();
  await writeFile(join(dir,'state'),'malformed');
  action=await call({action:'click',observation:seen.details.observation,element_id:'elem_1'});
  assert.equal(action.details.state,'indeterminate');
  assert(action.isError);
  await assert.rejects(call({action:'click',observation:seen.details.observation,element_id:'elem_1'}),/observ/i);
  console.log('PASS: Pi loading, image delivery, scoped one-use observations, argument safety, confirmed/unverified/unknown results');
} finally {
  process.env.PATH = priorPath;
  if(priorFixture===undefined) delete process.env.PEEKABOO_TEST_DIR; else process.env.PEEKABOO_TEST_DIR=priorFixture;
  await rm(dir,{recursive:true,force:true});
}
