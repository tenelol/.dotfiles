import { extensionPath } from "./extension-path.mjs";
// Run: node modules/pi-coding-agent/tests/quality-gates.test.mjs
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const root = process.env.PI_PACKAGE_DIR || '/opt/homebrew/opt/pi-coding-agent/libexec/lib/node_modules/@earendil-works/pi-coding-agent';
const { createJiti } = createRequire(join(root,'package.json'))('jiti');
const temporary = mkdtempSync(join(tmpdir(),'pi-quality-gates-'));
const previousAgentDir = process.env.PI_CODING_AGENT_DIR;
process.env.PI_CODING_AGENT_DIR = join(temporary,'agent');
let runtime;
try {
  mkdirSync(process.env.PI_CODING_AGENT_DIR);
  copyFileSync(new URL('../files/settings.json',import.meta.url),join(process.env.PI_CODING_AGENT_DIR,'settings.json'));
  const cwd = join(temporary,'project');
  mkdirSync(cwd);
  const git = (...args) => execFileSync('git',args,{cwd,stdio:'pipe'});
  git('init','-q');
  writeFileSync(join(cwd,'fixture.txt'),'before\n');
  git('add','fixture.txt');
  git('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','-c','commit.gpgsign=false','commit','-qm','fixture');
  const jiti = createJiti(import.meta.url,{moduleCache:false});
  const source = extensionPath('pi-subagents/src/');
  const { resolveWatchdogConfigStrict } = await jiti.import(join(source,'watchdog/settings.ts'));
  const config = resolveWatchdogConfigStrict(cwd);
  assert.equal(config.enabled,true);
  assert.equal(config.main.enabled,true);
  assert.equal(config.main.model,'openai-codex/gpt-6-sol');
  assert.equal(config.main.thinking,'xhigh');
  assert.equal(config.cadence.everyNTools,null);
  assert.equal(config.children.enabled,false);
  assert.equal(config.clarification,false);
  assert.equal(config.agentEndTimeoutMs,120000);
  const { MainWatchdogRuntime } = await jiti.import(join(source,'watchdog/runtime.ts'));
  const reviews=[]; const warnings=[];
  runtime = new MainWatchdogRuntime({cwd,reviewChangesOnly:true,
    review: request => { reviews.push(request.delta); return {warnings:[{severity:'blocker',category:'test-gap',summary:'Fixture needs verification',evidence:'Fixture change has no verification result',recommendedAction:'Run the focused fixture test'}]}; },
    displayWarning: warning => warnings.push(warning),
  });
  const ctx={cwd};
  runtime.handleBeforeAgentStart({prompt:'Inspect this project'},ctx);
  runtime.enqueueDelta('Read fixture.txt');
  await runtime.handleAgentEnd({},ctx);
  assert.equal(reviews.length,0,'Read-only work must not trigger model review');
  runtime.handleBeforeAgentStart({prompt:'Fix fixture.txt'},ctx);
  writeFileSync(join(cwd,'fixture.txt'),'after\n');
  runtime.enqueueDelta('Updated fixture.txt');
  for(let i=0;i<20;i++) runtime.handleToolResult(ctx);
  assert.equal(reviews.length,0,'No per-tool cadence reviews');
  await runtime.handleAgentEnd({},ctx);
  assert.equal(reviews.length,1,'Changed repo is reviewed at completion');
  assert.equal(warnings.length,1,'Review findings reach the parent');
  await runtime.handleAgentEnd({},ctx);
  assert.equal(reviews.length,1,'Unchanged evidence is not reviewed repeatedly');

  const { normalizeGateAcceptance, resolveEffectiveAcceptance, validateAcceptanceInput, evaluateAcceptance } = await jiti.import(join(source,'runs/shared/acceptance.ts'));
  assert(validateAcceptanceInput({level:'verified'}).length>0,'Verified requires an actual command');
  assert.equal(normalizeGateAcceptance('node verify.cjs',{level:'checked'}).ok,false);
  writeFileSync(join(cwd,'verify.cjs'),"const fs=require('node:fs'); fs.writeFileSync('verification-ran','yes'); process.exit(fs.readFileSync('fixture.txt','utf8')==='after\\n'?0:7);\n");
  const policy = resolveEffectiveAcceptance({agentName:'worker',task:'Fix fixture.txt',explicit:normalizeGateAcceptance('node verify.cjs').acceptance});
  const report={
    criteriaSatisfied:policy.criteria.map(c=>({id:c.id,status:'satisfied',evidence:'Claimed by the fixture child'})),
    changedFiles:['fixture.txt'],testsAddedOrUpdated:['verify.cjs'],
    commandsRun:[{command:'node verify.cjs',result:'passed',summary:'Child claims success'}],
    validationOutput:['Child claims all checks passed'],residualRisks:[],noStagedFiles:true,
  };
  let ledger=await evaluateAcceptance({acceptance:policy,output:'All tests passed',report,cwd});
  assert.equal(ledger.evidenceStatus,'verified',JSON.stringify(ledger));
  assert.equal(readFileSync(join(cwd,'verification-ran'),'utf8'),'yes','Verification actually runs on the host');
  assert.equal(ledger.verifyRuns[0].exitCode,0);
  writeFileSync(join(cwd,'fixture.txt'),'broken\n');
  ledger=await evaluateAcceptance({acceptance:policy,output:'All tests passed',report,cwd});
  assert.equal(ledger.evidenceStatus,'rejected','A success claim cannot hide a failing verification');
  assert.equal(ledger.verifyRuns[0].exitCode,7);
  console.log('PASS: configured watchdog reviews edits only at completion; native verification executes and rejects false success claims');
} finally {
  runtime?.dispose();
  if(previousAgentDir===undefined) delete process.env.PI_CODING_AGENT_DIR; else process.env.PI_CODING_AGENT_DIR=previousAgentDir;
  rmSync(temporary,{recursive:true,force:true});
}
