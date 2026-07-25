import assert from "node:assert/strict";
import {
  chmodSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { spawn, spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";
import { evaluateRetrievalBenchmark, loadGoldenSuite } from "../src/benchmark.mjs";
import { reindex, search } from "../src/core.mjs";
import {
  getLatestKpiSnapshot,
  getWeeklyKpiReport,
  listKpiHistory,
  recordKpiSnapshot,
} from "../src/observability.mjs";
import { serializeMarkdown } from "../src/schema.mjs";

function sqlite(path, sql, { json = false } = {}) {
  const args = json ? ["-json", path, sql] : [path];
  const result = spawnSync("sqlite3", args, {
    input: json ? undefined : sql,
    encoding: "utf8",
  });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim() ? (json ? JSON.parse(result.stdout) : result.stdout) : (json ? [] : "");
}

function note(properties, body) {
  return serializeMarkdown({
    schema: "vault-note/v2",
    lifecycle: "active",
    status: "current",
    priority: "P1",
    pinned: false,
    canonical: true,
    needs_curation: false,
    created: "2026-07-23",
    updated: "2026-07-23",
    source_kind: "repository",
    confidence: "high",
    ...properties,
  }, body);
}

function fixture() {
  const vaultRoot = mkdtempSync(join(tmpdir(), "vault-observability-test-"));
  const config = {
    vaultRoot,
    vaultName: "test",
    indexPath: join(vaultRoot, ".vault-context", "index.sqlite"),
    observabilityPath: join(vaultRoot, ".vault-context", "observability.sqlite"),
  };
  const alphaPath = "10 Records/decision/11111111-1111-4111-8111-111111111111.md";
  const betaPath = "10 Records/note/22222222-2222-4222-8222-222222222222.md";
  mkdirSync(dirname(join(vaultRoot, alphaPath)), { recursive: true });
  mkdirSync(dirname(join(vaultRoot, betaPath)), { recursive: true });
  mkdirSync(join(vaultRoot, "90 System", "Policies"), { recursive: true });
  writeFileSync(join(vaultRoot, alphaPath), note({
    id: "11111111-1111-4111-8111-111111111111",
    title: "検索インデックスの設計",
    kind: "decision",
    status: "accepted",
    summary: "Markdownを正本として日本語検索を提供する。",
    scope_keys: ["project:test"],
    search_terms: ["検索インデックス", "ベクトル検索"],
  }, "# 検索インデックスの設計\n\n日本語の検索インデックスは再生成できる。"), "utf8");
  writeFileSync(join(vaultRoot, betaPath), note({
    id: "22222222-2222-4222-8222-222222222222",
    title: "関連する運用ノート",
    kind: "note",
    summary: "同じproject scopeを使う運用情報。",
    scope_keys: ["project:test"],
    tags: ["operations"],
  }, "# 関連する運用ノート\n\n運用情報。"), "utf8");
  const suite = {
    schema: "vault-retrieval-golden/v1",
    suite_id: "test-primary",
    defaults: { minimum_semantic_coverage: 1, minimum_case_count: 3 },
    gates: {
      "context.relevant_hit_at_3": 1,
      "context.mrr": 1,
      "hybrid.hit_at_5": 1,
      "all.negative_pass_rate": 1,
      "all.forbidden_hits": 0,
    },
    cases: [
      {
        id: "search-index-positive",
        tier: "gate",
        tracks: ["lexical", "chunks", "hybrid", "context"],
        input: { query: "検索インデックス" },
        expect: {
          relevant: [{ path: alphaPath, grade: 3 }],
          required_any: [alphaPath],
          forbidden: [],
        },
      },
      {
        id: "unknown-negative",
        tier: "gate",
        tracks: ["lexical"],
        input: { query: "qzxv-no-known-vault-record-987" },
        expect: { relevant: [], max_results: 0 },
      },
      {
        id: "scope-neighbor",
        tier: "gate",
        tracks: ["scope"],
        input: { seed_path: alphaPath },
        expect: {
          relevant: [{ path: betaPath, grade: 2 }],
          required_any: [betaPath],
          forbidden: [alphaPath],
        },
      },
    ],
  };
  const policy = {
    schema: "vault-kpi-policy/v1",
    policy_id: "test-policy",
    benchmark_suite: "90 System/Policies/retrieval-golden-queries.json",
    retention: { snapshots_days: 400, case_details_days: 120 },
    thresholds: {
      retrieval: {
        context_hit_at_3_pass: 1,
        context_hit_at_3_warn: 0.8,
        context_mrr_pass: 1,
        context_mrr_warn: 0.8,
        hybrid_hit_at_5_pass: 1,
        hybrid_hit_at_5_warn: 0.8,
        negative_pass_rate: 1,
      },
      semantic: { pass: 1, warn: 0.95 },
      graph: { scope_connected_pass: 0.95, scope_connected_warn: 0.9 },
      inbox: { oldest_pending_fail_hours: 24 },
    },
  };
  writeFileSync(
    join(vaultRoot, "90 System", "Policies", "retrieval-golden-queries.json"),
    `${JSON.stringify(suite, null, 2)}\n`,
    "utf8",
  );
  writeFileSync(
    join(vaultRoot, "90 System", "Policies", "vault-kpi-policy.json"),
    `${JSON.stringify(policy, null, 2)}\n`,
    "utf8",
  );
  reindex(config);
  return {
    config,
    alphaPath,
    betaPath,
    query: suite.cases[0].input.query,
    cleanup: () => rmSync(vaultRoot, { recursive: true, force: true }),
  };
}

function insertFixedEmbeddings(config, alphaPath) {
  const rows = sqlite(
    config.indexPath,
    "SELECT path,chunk_id,embedding_source_sha256 FROM chunks ORDER BY path,chunk_id;",
    { json: true },
  );
  const statements = ["BEGIN;"];
  for (const row of rows) {
    const vector = Buffer.alloc(8);
    vector.writeFloatLE(row.path === alphaPath ? 1 : 0, 0);
    vector.writeFloatLE(row.path === alphaPath ? 0 : 1, 4);
    statements.push(`INSERT OR REPLACE INTO chunk_embeddings(path,chunk_id,model,dimensions,vector,source_hash,updated_at)
VALUES ('${row.path}','${row.chunk_id}','qwen3-embedding:0.6b',2,X'${vector.toString("hex")}','${row.embedding_source_sha256}','2026-07-26T00:00:00+09:00');`);
  }
  statements.push("COMMIT;");
  sqlite(config.indexPath, statements.join("\n"));
}

const fixedEmbedder = async (inputs) => inputs.map(() => [1, 0]);

function runProcess(command, args, options) {
  return new Promise((resolvePromise) => {
    const child = spawn(command, args, options);
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => { stdout += chunk; });
    child.stderr.on("data", (chunk) => { stderr += chunk; });
    child.on("close", (status) => resolvePromise({ status, stdout, stderr }));
  });
}

test("Golden Query benchmark covers context, hybrid, negative, and scope without leaking query text", async () => {
  const { config, alphaPath, query, cleanup } = fixture();
  try {
    insertFixedEmbeddings(config, alphaPath);
    const result = await evaluateRetrievalBenchmark({ embedder: fixedEmbedder }, config);
    assert.equal(result.status, "pass", JSON.stringify(result, null, 2));
    assert.equal(result.aggregates.context.hit_rate_at_k, 1);
    assert.equal(result.aggregates.hybrid.hit_rate_at_k, 1);
    assert.equal(result.aggregates.lexical.negative_pass_rate, 1);
    assert.equal(result.aggregates.scope.hit_rate_at_k, 1);
    assert.doesNotMatch(JSON.stringify(result), new RegExp(query));
    assert.match(result.cases[0].query_sha256, /^[a-f0-9]{64}$/);
  } finally {
    cleanup();
  }
});

test("hybrid benchmark is degraded instead of passing an incomplete semantic index", async () => {
  const { config, cleanup } = fixture();
  try {
    const result = await evaluateRetrievalBenchmark({ embedder: fixedEmbedder }, config);
    assert.equal(result.status, "degraded");
    assert.equal(result.aggregates.hybrid.degraded, 1);
    assert.equal(result.cases.find((row) => row.track === "hybrid").passed, false);
  } finally {
    cleanup();
  }
});

test("suite validation rejects secret-like queries and unsafe expectations before evaluation", () => {
  const { config, alphaPath, cleanup } = fixture();
  try {
    const suitePath = join(config.vaultRoot, "90 System", "Policies", "retrieval-golden-queries.json");
    const suite = JSON.parse(readFileSync(suitePath, "utf8"));
    suite.cases[0].input.query = "password=FAKE_TEST_VALUE_1234567890";
    writeFileSync(suitePath, `${JSON.stringify(suite, null, 2)}\n`, "utf8");
    assert.throws(() => loadGoldenSuite({}, config), /looks sensitive/);
    suite.cases[0].input.query = "safe query";
    suite.cases[0].expect.required_any = ["../outside.md"];
    writeFileSync(suitePath, `${JSON.stringify(suite, null, 2)}\n`, "utf8");
    assert.throws(() => loadGoldenSuite({}, config), /unsafe Vault path/);
    suite.cases[0].expect.required_any = [alphaPath];
    suite.cases[0].expect.forbidden = ["10 Records/note/99999999-9999-4999-8999-999999999999.md"];
    writeFileSync(suitePath, `${JSON.stringify(suite, null, 2)}\n`, "utf8");
    assert.throws(() => loadGoldenSuite({}, config), /not found/i);
    suite.cases[0].expect.forbidden = [];
    suite.gates["context.relevant_hit_at_4"] = suite.gates["context.relevant_hit_at_3"];
    delete suite.gates["context.relevant_hit_at_3"];
    writeFileSync(suitePath, `${JSON.stringify(suite, null, 2)}\n`, "utf8");
    assert.throws(() => loadGoldenSuite({}, config), /does not match the configured context case k/);
  } finally {
    cleanup();
  }
});

test("equal retrieval scores use stable path tie-breakers across reindex", () => {
  const { config, cleanup } = fixture();
  try {
    const paths = [
      "10 Records/note/33333333-3333-4333-8333-333333333333.md",
      "10 Records/note/44444444-4444-4444-8444-444444444444.md",
    ];
    for (const [index, path] of paths.entries()) {
      writeFileSync(join(config.vaultRoot, path), note({
        id: index ? "44444444-4444-4444-8444-444444444444" : "33333333-3333-4333-8333-333333333333",
        title: "Identical tie marker",
        kind: "note",
        summary: "deterministic ranking tie marker",
        scope_keys: [`project:tie-${index}`],
      }, "# Identical tie marker\n\ndeterministic ranking tie marker"), "utf8");
    }
    reindex(config);
    const first = search("deterministic ranking tie marker", { limit: 2 }, config).results.map((row) => row.path);
    reindex(config);
    const second = search("deterministic ranking tie marker", { limit: 2 }, config).results.map((row) => row.path);
    assert.deepEqual(first, [...paths].sort());
    assert.deepEqual(second, first);
  } finally {
    cleanup();
  }
});

test("KPI snapshots are idempotent, survive reindex, and store no query or note prose", async () => {
  const { config, alphaPath, query, cleanup } = fixture();
  try {
    insertFixedEmbeddings(config, alphaPath);
    const first = await recordKpiSnapshot({ date: "2026-07-26", source: "manual", embedder: fixedEmbedder }, config);
    const second = await recordKpiSnapshot({ date: "2026-07-26", source: "manual", embedder: fixedEmbedder }, config);
    assert.equal(first.snapshot_id, second.snapshot_id);
    assert.equal(first.inserted, true);
    assert.equal(second.inserted, false);
    assert.equal(listKpiHistory({}, config).total, 1);
    reindex(config);
    assert.equal(getLatestKpiSnapshot({}, config).snapshot.snapshot_id, first.snapshot_id);
    const databaseBytes = readFileSync(config.observabilityPath);
    assert.equal(databaseBytes.includes(Buffer.from(query)), false);
    assert.equal(databaseBytes.includes(Buffer.from("Markdownを正本として日本語検索を提供する。")), false);
  } finally {
    cleanup();
  }
});

test("read-only KPI queries work against a read-only observability database", async () => {
  const { config, alphaPath, cleanup } = fixture();
  try {
    insertFixedEmbeddings(config, alphaPath);
    await recordKpiSnapshot({ date: "2026-07-26", source: "manual", embedder: fixedEmbedder }, config);
    chmodSync(config.observabilityPath, 0o444);
    assert.equal(getLatestKpiSnapshot({}, config).found, true);
    assert.equal(listKpiHistory({}, config).total, 1);
    assert.equal(getWeeklyKpiReport({ date: "2026-07-26" }, config).period.days_present, 1);
  } finally {
    if (existsSync(config.observabilityPath)) chmodSync(config.observabilityPath, 0o644);
    cleanup();
  }
});

test("a fully executed failing benchmark is stored as complete, not partial", async () => {
  const { config, alphaPath, cleanup } = fixture();
  try {
    insertFixedEmbeddings(config, alphaPath);
    const suitePath = join(config.vaultRoot, "90 System", "Policies", "retrieval-golden-queries.json");
    const suite = JSON.parse(readFileSync(suitePath, "utf8"));
    suite.cases.find((row) => row.id === "unknown-negative").input.query = "検索インデックス";
    writeFileSync(suitePath, `${JSON.stringify(suite, null, 2)}\n`, "utf8");
    const result = await recordKpiSnapshot({ date: "2026-07-26", source: "manual", embedder: fixedEmbedder }, config);
    assert.equal(result.overall_status, "fail");
    assert.equal(result.benchmark_status, "complete");
  } finally {
    cleanup();
  }
});

test("changed same-day state creates a new snapshot and failed transaction leaves no partial rows", async () => {
  const { config, alphaPath, betaPath, cleanup } = fixture();
  try {
    insertFixedEmbeddings(config, alphaPath);
    const first = await recordKpiSnapshot({ date: "2026-07-26", source: "manual", embedder: fixedEmbedder }, config);
    const beta = join(config.vaultRoot, betaPath);
    writeFileSync(beta, readFileSync(beta, "utf8").replace("updated: 2026-07-23", "updated: 2026-07-24"), "utf8");
    reindex(config);
    insertFixedEmbeddings(config, alphaPath);
    const second = await recordKpiSnapshot({ date: "2026-07-26", source: "manual", embedder: fixedEmbedder }, config);
    assert.notEqual(second.snapshot_id, first.snapshot_id);
    assert.equal(listKpiHistory({}, config).total, 2);
    await assert.rejects(
      recordKpiSnapshot({
        date: "2026-07-26",
        source: "weekly",
        embedder: fixedEmbedder,
        injectFailure: true,
      }, config),
      /forced_failure|no such table/,
    );
    assert.equal(listKpiHistory({}, config).total, 2);
  } finally {
    cleanup();
  }
});

test("a future-dated snapshot cannot trigger retention deletion", async () => {
  const { config, alphaPath, cleanup } = fixture();
  try {
    insertFixedEmbeddings(config, alphaPath);
    await recordKpiSnapshot({ date: "2026-07-26", source: "manual", embedder: fixedEmbedder }, config);
    await assert.rejects(
      recordKpiSnapshot({ date: "9999-12-31", source: "manual", embedder: fixedEmbedder }, config),
      /must not be in the future/,
    );
    assert.equal(listKpiHistory({}, config).total, 1);
  } finally {
    cleanup();
  }
});

test("observability path escapes, symlink parents, and newer schemas fail closed", () => {
  const { config, cleanup } = fixture();
  const outside = mkdtempSync(join(tmpdir(), "vault-observability-outside-"));
  try {
    const sentinel = join(outside, "sentinel");
    writeFileSync(sentinel, "unchanged", "utf8");
    assert.throws(
      () => getLatestKpiSnapshot({}, { ...config, observabilityPath: join(outside, "observability.sqlite") }),
      /inside the configured vault/,
    );
    assert.equal(readFileSync(sentinel, "utf8"), "unchanged");
    const link = join(config.vaultRoot, ".vault-context-link");
    symlinkSync(outside, link, "dir");
    assert.throws(
      () => getLatestKpiSnapshot({}, { ...config, observabilityPath: join(link, "observability.sqlite") }),
      /symlink/,
    );
    mkdirSync(dirname(config.observabilityPath), { recursive: true });
    sqlite(config.observabilityPath, "PRAGMA user_version=2;");
    assert.throws(() => getLatestKpiSnapshot({}, config), /newer/);
  } finally {
    cleanup();
    rmSync(outside, { recursive: true, force: true });
  }
});

test("weekly KPI report exposes warm-up gaps and bounded machine-readable metrics", async () => {
  const { config, alphaPath, cleanup } = fixture();
  try {
    insertFixedEmbeddings(config, alphaPath);
    await recordKpiSnapshot({ date: "2026-07-26", source: "manual", embedder: fixedEmbedder }, config);
    const report = getWeeklyKpiReport({ date: "2026-07-26", days: 7, compareDays: 7 }, config);
    assert.equal(report.period.days_present, 1);
    assert.equal(report.overall_status, "unknown");
    assert.equal(report.missing_dates.length, 6);
    assert.deepEqual(report.warnings, ["insufficient_history", "comparison_history_incomplete"]);
    assert.ok(report.metrics.some((row) => row.metric_id === "retrieval.context.hit_rate_at_k"));
  } finally {
    cleanup();
  }
});

test("weekly KPI report keeps transient same-day breaches and classifies them against a complete comparison", async () => {
  const { config, alphaPath, cleanup } = fixture();
  try {
    insertFixedEmbeddings(config, alphaPath);
    const seed = await recordKpiSnapshot({ date: "2026-07-12", source: "manual", embedder: fixedEmbedder }, config);
    const statements = ["BEGIN;"];
    for (let day = 13; day <= 25; day += 1) {
      const date = `2026-07-${String(day).padStart(2, "0")}`;
      const id = `snapshot-${date}`;
      statements.push(`INSERT INTO snapshots
SELECT '${id}','${date}','${date}T06:30:00+09:00',source,time_zone,index_fingerprint,index_format_revision,indexed_at_ms,note_count,
policy_id,policy_sha256,benchmark_set_id,benchmark_set_sha256,benchmark_status,overall_status,summary_json
FROM snapshots WHERE snapshot_id='${seed.snapshot_id}';`);
      statements.push(`INSERT INTO metrics SELECT '${id}',metric_id,value,unit FROM metrics WHERE snapshot_id='${seed.snapshot_id}';`);
      statements.push(`INSERT INTO slo_evaluations SELECT '${id}',slo_id,status,severity,actual,target_json,reason_code
FROM slo_evaluations WHERE snapshot_id='${seed.snapshot_id}';`);
    }
    statements.push("COMMIT;");
    sqlite(config.observabilityPath, statements.join("\n"));
    sqlite(config.observabilityPath, `INSERT INTO snapshots
SELECT 'snapshot-transient','2026-07-20','2026-07-20T06:00:00+09:00',source,time_zone,index_fingerprint,index_format_revision,indexed_at_ms,note_count,
policy_id,policy_sha256,benchmark_set_id,benchmark_set_sha256,benchmark_status,'warn',summary_json
FROM snapshots WHERE snapshot_id='snapshot-2026-07-20';
INSERT INTO metrics SELECT 'snapshot-transient',metric_id,value,unit FROM metrics WHERE snapshot_id='snapshot-2026-07-20';
INSERT INTO slo_evaluations SELECT 'snapshot-transient',slo_id,status,severity,actual,target_json,reason_code
FROM slo_evaluations WHERE snapshot_id='snapshot-2026-07-20';
UPDATE slo_evaluations SET status='warn',actual=1,reason_code='broken_link'
WHERE snapshot_id='snapshot-transient' AND slo_id='integrity.links';`);
    const report = getWeeklyKpiReport({ date: "2026-07-25", days: 7, compareDays: 7 }, config);
    assert.equal(report.comparison.days_present, 7);
    assert.equal(report.slo_breaches.length, 0);
    assert.deepEqual(report.new_slo_breaches.map((row) => row.slo_id), ["integrity.links"]);
    assert.equal(report.new_slo_breaches[0].first_seen, "2026-07-20");
  } finally {
    cleanup();
  }
});

test("concurrent snapshot writers serialize without duplicates or SQLITE_BUSY", async () => {
  const { config, cleanup } = fixture();
  const cli = new URL("../src/cli.mjs", import.meta.url);
  const env = {
    ...process.env,
    VAULT_CONTEXT_ROOT: config.vaultRoot,
    VAULT_CONTEXT_INDEX: config.indexPath,
    VAULT_CONTEXT_OBSERVABILITY: config.observabilityPath,
  };
  try {
    const results = await Promise.all(Array.from({ length: 4 }, () => runProcess(
      process.execPath,
      [
        cli.pathname,
        "kpi",
        "snapshot",
        "--date",
        "2026-07-26",
        "--no-benchmark",
        "--json",
      ],
      { env, stdio: ["ignore", "pipe", "pipe"] },
    )));
    for (const result of results) assert.equal(result.status, 0, result.stderr);
    assert.equal(listKpiHistory({}, config).total, 1);
  } finally {
    cleanup();
  }
});

test("CLI strict mode exits 2 for an SLO failure and 0 for warning-only dry runs", () => {
  const { config, cleanup } = fixture();
  const cli = new URL("../src/cli.mjs", import.meta.url);
  const env = {
    ...process.env,
    VAULT_CONTEXT_ROOT: config.vaultRoot,
    VAULT_CONTEXT_INDEX: config.indexPath,
    VAULT_CONTEXT_OBSERVABILITY: config.observabilityPath,
  };
  try {
    const degraded = spawnSync(process.execPath, [
      cli.pathname,
      "benchmark",
      "--strict",
      "--json",
    ], { env, encoding: "utf8" });
    assert.equal(degraded.status, 0, degraded.stderr);
    assert.equal(JSON.parse(degraded.stdout).status, "degraded");
    const warning = spawnSync(process.execPath, [
      cli.pathname,
      "kpi",
      "snapshot",
      "--date",
      "2026-07-26",
      "--no-write",
      "--no-benchmark",
      "--strict",
      "--json",
    ], { env, encoding: "utf8" });
    assert.equal(warning.status, 0, warning.stderr);
    const invalidPath = join(config.vaultRoot, "10 Records", "note", "invalid.md");
    writeFileSync(invalidPath, "# Invalid record\n", "utf8");
    reindex(config);
    const failed = spawnSync(process.execPath, [
      cli.pathname,
      "kpi",
      "snapshot",
      "--date",
      "2026-07-26",
      "--no-write",
      "--no-benchmark",
      "--strict",
      "--json",
    ], { env, encoding: "utf8" });
    assert.equal(failed.status, 2, failed.stderr);
    assert.equal(JSON.parse(failed.stdout).overall_status, "fail");
  } finally {
    cleanup();
  }
});
