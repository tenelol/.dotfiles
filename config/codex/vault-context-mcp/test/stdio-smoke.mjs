import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const server = new URL("../src/server.mjs", import.meta.url);
const temporaryVault = mkdtempSync(join(tmpdir(), "vault-context-smoke-"));
mkdirSync(join(temporaryVault, "10 Records"), { recursive: true });
const transport = new StdioClientTransport({
  command: process.execPath,
  args: [server.pathname],
  env: {
    ...process.env,
    VAULT_CONTEXT_ROOT: temporaryVault,
    VAULT_CONTEXT_INDEX: join(temporaryVault, ".vault-context", "index.sqlite"),
  },
  stderr: "pipe",
});
const client = new Client({ name: "vault-context-smoke", version: "1.0.0" });

try {
  await client.connect(transport);
  const listed = await client.listTools();
  assert.ok(listed.tools.length >= 20, `expected at least 20 tools, got ${listed.tools.length}`);
  assert.ok(listed.tools.every((tool) => tool.outputSchema), "every tool must expose an output schema");
  const benchmark = listed.tools.find((tool) => tool.name === "evaluate_retrieval_benchmark");
  const recorder = listed.tools.find((tool) => tool.name === "record_kpi_snapshot");
  assert.equal(benchmark.annotations.readOnlyHint, true);
  assert.equal(benchmark.annotations.destructiveHint, false);
  assert.equal(recorder.annotations.readOnlyHint, false);
  assert.equal(recorder.annotations.idempotentHint, true);
  assert.equal(recorder.annotations.destructiveHint, true);
  const response = await client.callTool({ name: "health_check", arguments: {} });
  assert.equal(response.isError, undefined);
  assert.ok(response.content.some((item) => item.type === "text"));
  console.log(JSON.stringify({ ok: true, tools: listed.tools.length }));
} finally {
  await client.close();
  rmSync(temporaryVault, { recursive: true, force: true });
}
