import {
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  realpathSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join, relative, resolve, sep } from "node:path";
import { evaluateRetrievalBenchmark } from "./benchmark.mjs";
import { health, loadConfig, quality } from "./core.mjs";
import { sha256, timestampInZone, todayInZone } from "./schema.mjs";

const POLICY_SCHEMA = "vault-kpi-policy/v1";
const OBSERVABILITY_SCHEMA_VERSION = 1;
const DEFAULT_POLICY = {
  retention: { snapshots_days: 400, case_details_days: 120 },
  thresholds: {
    retrieval: {
      context_hit_at_3_pass: 0.9,
      context_hit_at_3_warn: 0.8,
      context_mrr_pass: 0.8,
      context_mrr_warn: 0.7,
      hybrid_hit_at_5_pass: 0.9,
      hybrid_hit_at_5_warn: 0.8,
      negative_pass_rate: 1,
    },
    semantic: { pass: 1, warn: 0.95 },
    graph: { scope_connected_pass: 0.95, scope_connected_warn: 0.9 },
    inbox: { oldest_pending_fail_hours: 24 },
  },
};

function validIsoDate(value, label = "date") {
  const date = String(value || "");
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) throw new Error(`${label} must be a valid YYYY-MM-DD date`);
  const parsed = new Date(`${date}T12:00:00Z`);
  if (!Number.isFinite(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== date) {
    throw new Error(`${label} must be a valid YYYY-MM-DD date`);
  }
  return date;
}

function addDays(date, amount) {
  const parsed = new Date(`${validIsoDate(date)}T12:00:00Z`);
  parsed.setUTCDate(parsed.getUTCDate() + amount);
  return parsed.toISOString().slice(0, 10);
}

function datesBetween(start, end) {
  const rows = [];
  for (let date = start; date <= end; date = addDays(date, 1)) rows.push(date);
  return rows;
}

function isoWeek(dateString) {
  const date = new Date(`${validIsoDate(dateString)}T12:00:00Z`);
  const day = date.getUTCDay() || 7;
  date.setUTCDate(date.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
  const week = Math.ceil((((date - yearStart) / 86400000) + 1) / 7);
  return { year: date.getUTCFullYear(), label: `${date.getUTCFullYear()}-W${String(week).padStart(2, "0")}` };
}

function isPlainObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function finiteThreshold(value, label) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0 || parsed > 1) throw new Error(`${label} must be from 0 to 1`);
  return parsed;
}

function positiveInteger(value, label, max) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1 || parsed > max) {
    throw new Error(`${label} must be an integer from 1 to ${max}`);
  }
  return parsed;
}

function stableValue(value) {
  if (Array.isArray(value)) return value.map(stableValue);
  if (!isPlainObject(value)) return value;
  return Object.fromEntries(Object.keys(value).sort().map((key) => [key, stableValue(value[key])]));
}

function stableStringify(value) {
  return JSON.stringify(stableValue(value));
}

function sqlString(value) {
  if (value === null || value === undefined) return "NULL";
  return `'${String(value).replaceAll("'", "''")}'`;
}

function runSqlite(path, sql, { json = false } = {}) {
  const args = ["-batch", "-bail"];
  if (json) args.push("-json");
  args.push(path);
  if (json) args.push(sql);
  const result = spawnSync("sqlite3", args, {
    input: json ? undefined : sql,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
    timeout: 30_000,
  });
  if (result.error) throw new Error(`observability sqlite failed: ${result.error.message}`);
  if (result.status !== 0) throw new Error((result.stderr || "observability sqlite failed").trim());
  return result.stdout || "";
}

function sqliteRows(path, sql) {
  const output = runSqlite(path, sql, { json: true }).trim();
  return output ? JSON.parse(output) : [];
}

function assertSafeDerivedPath(config, target, label) {
  const root = resolve(config.vaultRoot);
  if (!existsSync(root) || !lstatSync(root).isDirectory()) throw new Error("Configured Vault root does not exist");
  const rootReal = realpathSync(root);
  const path = resolve(target);
  const rel = relative(root, path);
  if (!rel || rel === ".." || rel.startsWith(`..${sep}`)) {
    throw new Error(`${label} must stay inside the configured vault`);
  }
  let cursor = root;
  const parts = rel.split(sep);
  for (let index = 0; index < parts.length; index += 1) {
    cursor = join(cursor, parts[index]);
    if (!existsSync(cursor)) break;
    const metadata = lstatSync(cursor);
    if (metadata.isSymbolicLink()) throw new Error(`${label} path must not contain a symlink`);
    if (index < parts.length - 1 && !metadata.isDirectory()) throw new Error(`${label} ancestor must be a directory`);
    if (index === parts.length - 1 && !metadata.isFile()) throw new Error(`${label} must be a regular file`);
    const real = realpathSync(cursor);
    const realRel = relative(rootReal, real);
    if (realRel === ".." || realRel.startsWith(`..${sep}`)) throw new Error(`${label} escapes the configured vault`);
  }
  return path;
}

function readVaultJson(config, input, defaultRelative, label) {
  const path = assertSafeDerivedPath(config, resolve(config.vaultRoot, input || defaultRelative), label);
  if (!existsSync(path)) throw new Error(`${label} does not exist`);
  const source = readFileSync(path, "utf8");
  let value;
  try {
    value = JSON.parse(source);
  } catch {
    throw new Error(`${label} is not valid JSON`);
  }
  return { path, source, value };
}

function normalizePolicy(raw, source, config) {
  if (!isPlainObject(raw) || raw.schema !== POLICY_SCHEMA) {
    throw new Error(`KPI policy schema must be ${POLICY_SCHEMA}`);
  }
  const policyId = String(raw.policy_id || "").trim();
  if (!/^[a-z0-9][a-z0-9._-]{2,79}$/.test(policyId)) throw new Error("KPI policy_id is invalid");
  const benchmarkSuite = String(raw.benchmark_suite || "").trim();
  if (!benchmarkSuite || benchmarkSuite.startsWith("/") || benchmarkSuite.split(/[\\/]/).includes("..")) {
    throw new Error("KPI benchmark_suite must be a Vault-relative path");
  }
  const retentionRaw = { ...DEFAULT_POLICY.retention, ...(raw.retention || {}) };
  const thresholdsRaw = {
    retrieval: { ...DEFAULT_POLICY.thresholds.retrieval, ...(raw.thresholds?.retrieval || {}) },
    semantic: { ...DEFAULT_POLICY.thresholds.semantic, ...(raw.thresholds?.semantic || {}) },
    graph: { ...DEFAULT_POLICY.thresholds.graph, ...(raw.thresholds?.graph || {}) },
    inbox: { ...DEFAULT_POLICY.thresholds.inbox, ...(raw.thresholds?.inbox || {}) },
  };
  const retention = {
    snapshots_days: positiveInteger(retentionRaw.snapshots_days, "retention.snapshots_days", 3650),
    case_details_days: positiveInteger(retentionRaw.case_details_days, "retention.case_details_days", 3650),
  };
  if (retention.case_details_days > retention.snapshots_days) {
    throw new Error("case detail retention must not exceed snapshot retention");
  }
  const retrieval = {};
  for (const [key, value] of Object.entries(thresholdsRaw.retrieval)) {
    retrieval[key] = finiteThreshold(value, `thresholds.retrieval.${key}`);
  }
  for (const pair of [
    ["context_hit_at_3_pass", "context_hit_at_3_warn"],
    ["context_mrr_pass", "context_mrr_warn"],
    ["hybrid_hit_at_5_pass", "hybrid_hit_at_5_warn"],
  ]) {
    if (retrieval[pair[0]] < retrieval[pair[1]]) throw new Error(`${pair[0]} must be >= ${pair[1]}`);
  }
  const semantic = {
    pass: finiteThreshold(thresholdsRaw.semantic.pass, "thresholds.semantic.pass"),
    warn: finiteThreshold(thresholdsRaw.semantic.warn, "thresholds.semantic.warn"),
  };
  const graph = {
    scope_connected_pass: finiteThreshold(thresholdsRaw.graph.scope_connected_pass, "thresholds.graph.scope_connected_pass"),
    scope_connected_warn: finiteThreshold(thresholdsRaw.graph.scope_connected_warn, "thresholds.graph.scope_connected_warn"),
  };
  if (semantic.pass < semantic.warn || graph.scope_connected_pass < graph.scope_connected_warn) {
    throw new Error("KPI pass thresholds must be >= warn thresholds");
  }
  const inbox = {
    oldest_pending_fail_hours: positiveInteger(
      thresholdsRaw.inbox.oldest_pending_fail_hours,
      "thresholds.inbox.oldest_pending_fail_hours",
      24 * 365,
    ),
  };
  const suitePath = assertSafeDerivedPath(config, resolve(config.vaultRoot, benchmarkSuite), "Golden query suite");
  if (!existsSync(suitePath) || !lstatSync(suitePath).isFile()) throw new Error("Configured Golden query suite does not exist");
  return {
    schema: POLICY_SCHEMA,
    policy_id: policyId,
    policy_sha256: sha256(source),
    benchmark_suite: relative(config.vaultRoot, suitePath).split(sep).join("/"),
    retention,
    thresholds: { retrieval, semantic, graph, inbox },
  };
}

export function loadKpiPolicy({ policyPath } = {}, config = loadConfig()) {
  const { source, value } = readVaultJson(
    config,
    policyPath || process.env.VAULT_CONTEXT_KPI_POLICY,
    "90 System/Policies/vault-kpi-policy.json",
    "KPI policy",
  );
  return normalizePolicy(value, source, config);
}

function acquireDirectoryLock(lockPath, timeoutMs = 5000) {
  mkdirSync(dirname(lockPath), { recursive: true });
  const started = Date.now();
  while (true) {
    try {
      mkdirSync(lockPath);
      writeFileSync(join(lockPath, "owner"), `${process.pid}\n`, "utf8");
      return () => rmSync(lockPath, { recursive: true, force: true });
    } catch (error) {
      if (error.code !== "EEXIST") throw error;
      let age = 0;
      try {
        age = Date.now() - statSync(lockPath).mtimeMs;
      } catch (statError) {
        if (statError.code === "ENOENT") continue;
        throw statError;
      }
      if (age > 120_000) {
        rmSync(lockPath, { recursive: true, force: true });
        continue;
      }
      if (Date.now() - started >= timeoutMs) throw new Error("Timed out waiting for the observability lock");
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 50);
    }
  }
}

function initializeObservability(config) {
  const path = assertSafeDerivedPath(
    config,
    config.observabilityPath || join(config.vaultRoot, ".vault-context", "observability.sqlite"),
    "Observability database",
  );
  mkdirSync(dirname(path), { recursive: true });
  assertSafeDerivedPath(config, path, "Observability database");
  let userVersion = 0;
  if (existsSync(path)) {
    const rows = sqliteRows(path, "PRAGMA user_version;");
    userVersion = Number(rows[0]?.user_version || 0);
    if (userVersion === 0) {
      const tables = sqliteRows(path, "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';");
      if (tables.length) throw new Error("Unknown observability database schema");
    }
  }
  if (userVersion > OBSERVABILITY_SCHEMA_VERSION) throw new Error("Observability database schema is newer than this runtime");
  runSqlite(path, `
PRAGMA journal_mode=WAL;
PRAGMA synchronous=FULL;
PRAGMA foreign_keys=ON;
PRAGMA busy_timeout=5000;
BEGIN IMMEDIATE;
CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS snapshots (
  snapshot_id TEXT PRIMARY KEY,
  observed_date TEXT NOT NULL,
  observed_at TEXT NOT NULL,
  source TEXT NOT NULL,
  time_zone TEXT NOT NULL,
  index_fingerprint TEXT NOT NULL,
  index_format_revision TEXT NOT NULL,
  indexed_at_ms INTEGER NOT NULL,
  note_count INTEGER NOT NULL,
  policy_id TEXT NOT NULL,
  policy_sha256 TEXT NOT NULL,
  benchmark_set_id TEXT,
  benchmark_set_sha256 TEXT,
  benchmark_status TEXT NOT NULL CHECK (benchmark_status IN ('complete','partial','unavailable','disabled')),
  overall_status TEXT NOT NULL CHECK (overall_status IN ('pass','warn','fail','unknown')),
  summary_json TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS metrics (
  snapshot_id TEXT NOT NULL REFERENCES snapshots(snapshot_id) ON DELETE CASCADE,
  metric_id TEXT NOT NULL,
  value REAL NOT NULL,
  unit TEXT NOT NULL,
  PRIMARY KEY (snapshot_id, metric_id)
);
CREATE TABLE IF NOT EXISTS slo_evaluations (
  snapshot_id TEXT NOT NULL REFERENCES snapshots(snapshot_id) ON DELETE CASCADE,
  slo_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pass','warn','fail','unknown')),
  severity TEXT NOT NULL CHECK (severity IN ('P0','P1','P2','info')),
  actual REAL,
  target_json TEXT NOT NULL,
  reason_code TEXT NOT NULL,
  PRIMARY KEY (snapshot_id, slo_id)
);
CREATE TABLE IF NOT EXISTS benchmark_case_results (
  snapshot_id TEXT NOT NULL REFERENCES snapshots(snapshot_id) ON DELETE CASCADE,
  case_id TEXT NOT NULL,
  retrieval_mode TEXT NOT NULL,
  query_sha256 TEXT NOT NULL,
  expected_paths_json TEXT NOT NULL,
  result_paths_json TEXT NOT NULL,
  k INTEGER NOT NULL,
  hit_rank INTEGER,
  reciprocal_rank REAL NOT NULL,
  passed INTEGER NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('complete','degraded','unavailable')),
  latency_ms REAL NOT NULL,
  PRIMARY KEY (snapshot_id, case_id, retrieval_mode)
);
CREATE INDEX IF NOT EXISTS idx_snapshots_date ON snapshots(observed_date DESC, observed_at DESC);
CREATE INDEX IF NOT EXISTS idx_snapshots_status ON snapshots(overall_status, observed_date);
INSERT OR REPLACE INTO meta(key,value) VALUES ('schema_version','1');
INSERT OR IGNORE INTO meta(key,value) VALUES ('created_at',${sqlString(timestampInZone())});
PRAGMA user_version=${OBSERVABILITY_SCHEMA_VERSION};
COMMIT;
`);
  return path;
}

function validateExistingObservability(config) {
  const path = assertSafeDerivedPath(
    config,
    config.observabilityPath || join(config.vaultRoot, ".vault-context", "observability.sqlite"),
    "Observability database",
  );
  if (!existsSync(path)) return null;
  const rows = sqliteRows(path, "PRAGMA user_version;");
  const userVersion = Number(rows[0]?.user_version || 0);
  if (userVersion === 0) throw new Error("Unknown observability database schema");
  if (userVersion > OBSERVABILITY_SCHEMA_VERSION) {
    throw new Error("Observability database schema is newer than this runtime");
  }
  if (userVersion !== OBSERVABILITY_SCHEMA_VERSION) {
    throw new Error("Observability database schema requires migration");
  }
  const meta = sqliteRows(path, "SELECT value FROM meta WHERE key='schema_version' LIMIT 1;");
  if (Number(meta[0]?.value || 0) !== OBSERVABILITY_SCHEMA_VERSION) {
    throw new Error("Observability database schema metadata is invalid");
  }
  return path;
}

function indexMetadata(config) {
  const path = assertSafeDerivedPath(config, config.indexPath, "Vault index");
  if (!existsSync(path)) throw new Error("Vault index does not exist");
  const rows = sqliteRows(path, "SELECT key,value FROM index_meta;");
  return Object.fromEntries(rows.map((row) => [row.key, row.value]));
}

function indexScalar(config, sql) {
  const path = assertSafeDerivedPath(config, config.indexPath, "Vault index");
  const rows = sqliteRows(path, sql);
  return rows[0] || {};
}

function oldestPendingHours(config, observedAt) {
  const row = indexScalar(config, `SELECT MIN(n.captured_at) AS oldest
FROM notes n
WHERE n.kind='raw'
  AND NOT EXISTS (
    SELECT 1 FROM edges e JOIN notes r ON r.path=e.source_path
    WHERE e.target_path=n.path AND r.kind='receipt'
  );`);
  if (!row.oldest) return 0;
  const oldest = new Date(row.oldest).getTime();
  const observed = new Date(observedAt).getTime();
  if (!Number.isFinite(oldest) || !Number.isFinite(observed)) return 0;
  return Number((Math.max(0, observed - oldest) / 3_600_000).toFixed(3));
}

function synthesisMetrics(config, date) {
  const dailyPath = join(config.vaultRoot, "20 Synthesis", "daily", date.slice(0, 4), `${date}.md`);
  const week = isoWeek(date);
  const weeklyPath = `20 Synthesis/weekly/${week.year}/${week.label}.md`;
  const weeklyRow = indexScalar(
    config,
    `SELECT COUNT(*) AS count,SUM(CASE WHEN status='synthesized' THEN 1 ELSE 0 END) AS synthesized FROM notes WHERE path=${sqlString(weeklyPath)};`,
  );
  return {
    daily_current: existsSync(dailyPath) && lstatSync(dailyPath).isFile() ? 1 : 0,
    weekly_current: Number(weeklyRow.count || 0) > 0 ? 1 : 0,
    weekly_synthesized: Number(weeklyRow.synthesized || 0) > 0 ? 1 : 0,
  };
}

function metric(id, value, unit = "count") {
  if (value === null || value === undefined || value === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? { metric_id: id, value: parsed, unit } : null;
}

function benchmarkMetricRows(benchmark) {
  if (!benchmark) return [];
  const rows = [
    metric("retrieval.case_tracks", benchmark.cases.length),
    metric("retrieval.semantic_coverage", benchmark.semantic_coverage.coverage, "ratio"),
  ];
  for (const [track, values] of Object.entries(benchmark.aggregates || {})) {
    rows.push(
      metric(`retrieval.${track}.cases`, values.cases),
      metric(`retrieval.${track}.pass_rate`, values.pass_rate, "ratio"),
      metric(`retrieval.${track}.hit_rate_at_k`, values.hit_rate_at_k, "ratio"),
      metric(`retrieval.${track}.recall_at_k`, values.recall_at_k, "ratio"),
      metric(`retrieval.${track}.mrr`, values.mrr, "ratio"),
      metric(`retrieval.${track}.ndcg_at_k`, values.ndcg_at_k, "ratio"),
      metric(`retrieval.${track}.negative_pass_rate`, values.negative_pass_rate, "ratio"),
      metric(`retrieval.${track}.unavailable`, values.unavailable),
      metric(`retrieval.${track}.degraded`, values.degraded),
      metric(`retrieval.${track}.latency_p50_ms`, values.latency_ms.p50, "ms"),
      metric(`retrieval.${track}.latency_p95_ms`, values.latency_ms.p95, "ms"),
    );
  }
  return rows.filter(Boolean);
}

function collectMetrics(report, benchmark, synthesis, pendingHours, currentHealth) {
  const summary = report.summary;
  return [
    metric("integrity.raw_failures", summary.raw_integrity_failures),
    metric("integrity.sensitive_quarantined", summary.sensitive_quarantined),
    metric("integrity.noncanonical_quarantined", summary.noncanonical_quarantined),
    metric("integrity.schema_violations", summary.schema_violations),
    metric("integrity.broken_links", summary.broken_links),
    metric("integrity.missing_summary", summary.missing_summary),
    metric("integrity.missing_scope_or_project", summary.missing_scope_or_project),
    metric("inbox.pending", summary.pending_inbox),
    metric("inbox.oldest_age_hours", pendingHours, "hours"),
    metric("semantic.coverage", summary.semantic_index.coverage, "ratio"),
    metric("semantic.missing_chunks", summary.semantic_index.missing_chunks),
    metric("graph.scope_connected_ratio", summary.graph.scope_connected_ratio, "ratio"),
    metric("graph.scope_coverage", summary.graph.scope_coverage, "ratio"),
    metric("graph.explicit_orphan_ratio", summary.graph.explicit_orphan_ratio, "ratio"),
    metric("review.overdue", summary.overdue_review),
    metric("handoff.stale", summary.stale_handoffs),
    metric("curation.pending", summary.needs_curation),
    metric("evidence.decisions_missing", summary.decisions_missing_evidence),
    metric("synthesis.daily_current", synthesis.daily_current, "boolean"),
    metric("synthesis.weekly_current", synthesis.weekly_current, "boolean"),
    metric("synthesis.weekly_synthesized", synthesis.weekly_synthesized, "boolean"),
    metric("index.notes", currentHealth.indexed_notes),
    ...benchmarkMetricRows(benchmark),
  ].filter(Boolean).sort((left, right) => left.metric_id.localeCompare(right.metric_id));
}

function fixedSlo(id, actual, target, severity, failureCode) {
  return {
    slo_id: id,
    status: actual === target ? "pass" : "fail",
    severity,
    actual,
    target: { eq: target },
    reason_code: actual === target ? "within_target" : failureCode,
  };
}

function rangedSlo(id, actual, { pass, warn }, severity, reasonCode) {
  if (actual === null || actual === undefined || actual === "") {
    return { slo_id: id, status: "unknown", severity, actual: null, target: { pass, warn }, reason_code: "metric_unavailable" };
  }
  if (!Number.isFinite(Number(actual))) {
    return { slo_id: id, status: "unknown", severity, actual: null, target: { pass, warn }, reason_code: "metric_unavailable" };
  }
  const value = Number(actual);
  return {
    slo_id: id,
    status: value >= pass ? "pass" : value >= warn ? "warn" : "fail",
    severity,
    actual: value,
    target: { pass, warn },
    reason_code: value >= pass ? "within_target" : reasonCode,
  };
}

function benchmarkValue(benchmark, track, field) {
  return benchmark?.aggregates?.[track]?.[field] ?? null;
}

function evaluateSlos({ report, benchmark, synthesis, pendingHours, policy, enforceDaily, requireWeekly }) {
  const q = report.summary;
  const evaluations = [
    fixedSlo("integrity.raw", q.raw_integrity_failures, 0, "P0", "raw_integrity_failure"),
    fixedSlo("integrity.sensitive", q.sensitive_quarantined, 0, "P0", "sensitive_quarantine_present"),
    fixedSlo("integrity.schema", q.schema_violations, 0, "P0", "schema_violation"),
    fixedSlo("integrity.noncanonical", q.noncanonical_quarantined, 0, "P1", "noncanonical_quarantine_present"),
    fixedSlo("integrity.links", q.broken_links, 0, "P1", "broken_link"),
    fixedSlo("integrity.summary", q.missing_summary, 0, "P1", "missing_summary"),
    fixedSlo("integrity.scope", q.missing_scope_or_project, 0, "P1", "missing_scope"),
    rangedSlo("semantic.coverage", q.semantic_index.coverage, policy.thresholds.semantic, "P2", "semantic_coverage_low"),
    rangedSlo(
      "graph.scope_connected",
      q.graph.scope_connected_ratio,
      { pass: policy.thresholds.graph.scope_connected_pass, warn: policy.thresholds.graph.scope_connected_warn },
      "P2",
      "scope_connectivity_low",
    ),
    rangedSlo(
      "retrieval.context_hit_at_3",
      benchmarkValue(benchmark, "context", "hit_rate_at_k"),
      {
        pass: policy.thresholds.retrieval.context_hit_at_3_pass,
        warn: policy.thresholds.retrieval.context_hit_at_3_warn,
      },
      "P1",
      "context_retrieval_regressed",
    ),
    rangedSlo(
      "retrieval.context_mrr",
      benchmarkValue(benchmark, "context", "mrr"),
      { pass: policy.thresholds.retrieval.context_mrr_pass, warn: policy.thresholds.retrieval.context_mrr_warn },
      "P1",
      "context_rank_regressed",
    ),
    rangedSlo(
      "retrieval.hybrid_hit_at_5",
      benchmarkValue(benchmark, "hybrid", "hit_rate_at_k"),
      {
        pass: policy.thresholds.retrieval.hybrid_hit_at_5_pass,
        warn: policy.thresholds.retrieval.hybrid_hit_at_5_warn,
      },
      "P2",
      "hybrid_retrieval_regressed",
    ),
  ];
  const benchmarkGates = benchmark?.gates?.filter((row) => row.passed !== null) || [];
  const passedBenchmarkGates = benchmarkGates.filter((row) => row.passed).length;
  evaluations.push({
    slo_id: "retrieval.benchmark_gates",
    status: !benchmark
      ? "unknown"
      : benchmark.status === "pass"
        ? "pass"
        : benchmark.status === "degraded"
          ? "warn"
          : "fail",
    severity: "P1",
    actual: benchmarkGates.length ? passedBenchmarkGates / benchmarkGates.length : null,
    target: { pass_rate: 1 },
    reason_code: !benchmark
      ? "metric_unavailable"
      : benchmark.status === "pass"
        ? "within_target"
        : benchmark.status === "degraded"
          ? "benchmark_dependency_degraded"
          : "benchmark_gate_failed",
  });
  const negative = benchmark?.cases?.filter((row) => row.status === "complete" && !row.expected_paths.length) || [];
  const negativePassRate = negative.length
    ? negative.filter((row) => row.passed).length / negative.length
    : null;
  evaluations.push({
    slo_id: "retrieval.negative_queries",
    status: negativePassRate !== null
      ? (negativePassRate >= policy.thresholds.retrieval.negative_pass_rate ? "pass" : "fail")
      : "unknown",
    severity: "P1",
    actual: negativePassRate,
    target: { min: policy.thresholds.retrieval.negative_pass_rate },
    reason_code: negativePassRate !== null && negativePassRate >= policy.thresholds.retrieval.negative_pass_rate
      ? "within_target"
      : negative.length
        ? "negative_query_leak"
        : "metric_unavailable",
  });
  evaluations.push({
    slo_id: "inbox.latency",
    status: q.pending_inbox === 0 ? "pass" : pendingHours > policy.thresholds.inbox.oldest_pending_fail_hours ? "fail" : "warn",
    severity: "P1",
    actual: pendingHours,
    target: { pending_count: 0, oldest_hours_lt: policy.thresholds.inbox.oldest_pending_fail_hours },
    reason_code: q.pending_inbox === 0 ? "within_target" : pendingHours > policy.thresholds.inbox.oldest_pending_fail_hours ? "inbox_overdue" : "inbox_pending",
  });
  if (enforceDaily) {
    evaluations.push(fixedSlo("synthesis.daily", synthesis.daily_current, 1, "P2", "daily_synthesis_missing"));
  }
  if (requireWeekly) {
    evaluations.push(fixedSlo("synthesis.weekly", synthesis.weekly_synthesized, 1, "P2", "weekly_synthesis_missing"));
  }
  return evaluations.sort((left, right) => left.slo_id.localeCompare(right.slo_id));
}

function overallStatus(evaluations) {
  if (evaluations.some((row) => row.status === "fail" && ["P0", "P1"].includes(row.severity))) return "fail";
  if (evaluations.some((row) => ["warn", "fail", "unknown"].includes(row.status) && row.severity !== "info")) return "warn";
  return evaluations.length ? "pass" : "unknown";
}

function benchmarkStorageStatus(benchmark, enabled) {
  if (!enabled) return "disabled";
  if (!benchmark) return "unavailable";
  if (benchmark.cases.length && benchmark.cases.every((row) => row.status === "complete")) return "complete";
  return benchmark.cases.some((row) => row.status === "complete") ? "partial" : "unavailable";
}

function canonicalSnapshotPayload(snapshot) {
  return {
    schema_version: OBSERVABILITY_SCHEMA_VERSION,
    observed_date: snapshot.observed_date,
    source: snapshot.source,
    index_fingerprint: snapshot.index_fingerprint,
    index_format_revision: snapshot.index_format_revision,
    policy_id: snapshot.policy_id,
    policy_sha256: snapshot.policy_sha256,
    benchmark_set_id: snapshot.benchmark_set_id,
    benchmark_set_sha256: snapshot.benchmark_set_sha256,
    benchmark_status: snapshot.benchmark_status,
    overall_status: snapshot.overall_status,
    metrics: snapshot.metrics.filter((row) => !row.metric_id.includes(".latency_")),
    slo_evaluations: snapshot.slo_evaluations,
    benchmark_cases: snapshot.benchmark_cases.map(({ latency_ms: _latency, ...row }) => row),
  };
}

export function persistKpiSnapshot(
  snapshot,
  policy,
  config = loadConfig(),
  { injectFailure = false, retentionDate = todayInZone() } = {},
) {
  const path = assertSafeDerivedPath(
    config,
    config.observabilityPath || join(config.vaultRoot, ".vault-context", "observability.sqlite"),
    "Observability database",
  );
  const release = acquireDirectoryLock(`${path}.lock`);
  try {
    const db = initializeObservability(config);
    const existing = sqliteRows(db, `SELECT snapshot_id FROM snapshots WHERE snapshot_id=${sqlString(snapshot.snapshot_id)};`);
    const retentionAnchor = validIsoDate(retentionDate, "retention date");
    const cutoffSnapshots = addDays(retentionAnchor, -(policy.retention.snapshots_days - 1));
    const cutoffCases = addDays(retentionAnchor, -(policy.retention.case_details_days - 1));
    const statements = [
      "PRAGMA foreign_keys=ON;",
      "PRAGMA busy_timeout=5000;",
      "BEGIN IMMEDIATE;",
      `INSERT OR IGNORE INTO snapshots(
snapshot_id,observed_date,observed_at,source,time_zone,index_fingerprint,index_format_revision,indexed_at_ms,note_count,
policy_id,policy_sha256,benchmark_set_id,benchmark_set_sha256,benchmark_status,overall_status,summary_json
) VALUES (
${[
  snapshot.snapshot_id,
  snapshot.observed_date,
  snapshot.observed_at,
  snapshot.source,
  "Asia/Tokyo",
  snapshot.index_fingerprint,
  snapshot.index_format_revision,
  snapshot.indexed_at_ms,
  snapshot.note_count,
  snapshot.policy_id,
  snapshot.policy_sha256,
  snapshot.benchmark_set_id,
  snapshot.benchmark_set_sha256,
  snapshot.benchmark_status,
  snapshot.overall_status,
  stableStringify(snapshot.summary),
].map(sqlString).join(",")}
);`,
    ];
    for (const row of snapshot.metrics) {
      statements.push(`INSERT OR IGNORE INTO metrics(snapshot_id,metric_id,value,unit) VALUES (${sqlString(snapshot.snapshot_id)},${sqlString(row.metric_id)},${row.value},${sqlString(row.unit)});`);
    }
    for (const row of snapshot.slo_evaluations) {
      statements.push(`INSERT OR IGNORE INTO slo_evaluations(snapshot_id,slo_id,status,severity,actual,target_json,reason_code) VALUES (${sqlString(snapshot.snapshot_id)},${sqlString(row.slo_id)},${sqlString(row.status)},${sqlString(row.severity)},${row.actual === null ? "NULL" : Number(row.actual)},${sqlString(stableStringify(row.target))},${sqlString(row.reason_code)});`);
    }
    for (const row of snapshot.benchmark_cases) {
      statements.push(`INSERT OR IGNORE INTO benchmark_case_results(snapshot_id,case_id,retrieval_mode,query_sha256,expected_paths_json,result_paths_json,k,hit_rank,reciprocal_rank,passed,status,latency_ms) VALUES (${sqlString(snapshot.snapshot_id)},${sqlString(row.case_id)},${sqlString(row.track)},${sqlString(row.query_sha256)},${sqlString(stableStringify(row.expected_paths))},${sqlString(stableStringify(row.result_paths))},${row.k},${row.hit_rank === null ? "NULL" : row.hit_rank},${row.reciprocal_rank},${row.passed ? 1 : 0},${sqlString(row.status)},${row.latency_ms});`);
    }
    if (injectFailure) statements.push("SELECT * FROM __vault_kpi_forced_failure__;");
    statements.push(
      `DELETE FROM benchmark_case_results WHERE snapshot_id IN (SELECT snapshot_id FROM snapshots WHERE observed_date<${sqlString(cutoffCases)});`,
      `DELETE FROM snapshots WHERE observed_date<${sqlString(cutoffSnapshots)};`,
      "COMMIT;",
    );
    runSqlite(db, statements.join("\n"));
    return { path: db, inserted: existing.length === 0 };
  } finally {
    release();
  }
}

export async function recordKpiSnapshot(options = {}, config = loadConfig()) {
  const currentDate = todayInZone();
  const date = validIsoDate(options.date || currentDate);
  if (date > currentDate) throw new Error("KPI snapshot date must not be in the future");
  const source = String(options.source || "manual");
  if (!/^[a-z][a-z0-9_-]{1,31}$/.test(source)) throw new Error("KPI snapshot source is invalid");
  const observedAt = timestampInZone();
  const policy = options.policy || loadKpiPolicy({ policyPath: options.policyPath }, config);
  const currentHealth = health(config);
  if (!currentHealth.ok) throw new Error("Vault health check failed before KPI collection");
  const report = quality({ today: date }, config);
  const benchmarkEnabled = options.benchmark !== false;
  const benchmark = benchmarkEnabled
    ? await evaluateRetrievalBenchmark({
      suitePath: policy.benchmark_suite,
      tracks: options.tracks,
      timeoutMs: options.timeoutMs,
      embedder: options.embedder,
    }, config)
    : null;
  const synthesis = synthesisMetrics(config, date);
  const pendingHours = oldestPendingHours(config, observedAt);
  const metrics = collectMetrics(report, benchmark, synthesis, pendingHours, currentHealth);
  const enforceDaily = options.enforceDaily ?? ["morning", "weekly"].includes(source);
  const requireWeekly = options.requireWeekly === true;
  const sloEvaluations = evaluateSlos({
    report,
    benchmark,
    synthesis,
    pendingHours,
    policy,
    enforceDaily,
    requireWeekly,
  });
  const meta = indexMetadata(config);
  const overall = overallStatus(sloEvaluations);
  const compactSummary = {
    overall_status: overall,
    source,
    benchmark_status: benchmark?.status || "disabled",
    breaches: sloEvaluations.filter((row) => row.status !== "pass").map((row) => ({
      slo_id: row.slo_id,
      status: row.status,
      severity: row.severity,
      reason_code: row.reason_code,
    })),
  };
  const snapshot = {
    observed_date: date,
    observed_at: observedAt,
    source,
    index_fingerprint: String(meta.fingerprint || ""),
    index_format_revision: String(meta.index_format_revision || ""),
    indexed_at_ms: Number(meta.indexed_at_ms || 0),
    note_count: Number(meta.note_count || currentHealth.indexed_notes || 0),
    policy_id: policy.policy_id,
    policy_sha256: policy.policy_sha256,
    benchmark_set_id: benchmark?.suite_id || null,
    benchmark_set_sha256: benchmark?.suite_sha256 || null,
    benchmark_status: benchmarkStorageStatus(benchmark, benchmarkEnabled),
    overall_status: overall,
    summary: compactSummary,
    metrics,
    slo_evaluations: sloEvaluations,
    benchmark_cases: benchmark?.cases || [],
  };
  snapshot.snapshot_id = sha256(stableStringify(canonicalSnapshotPayload(snapshot)));
  let persisted = null;
  if (options.write !== false) {
    persisted = persistKpiSnapshot(snapshot, policy, config, {
      injectFailure: options.injectFailure,
      retentionDate: currentDate,
    });
  }
  return {
    schema: "vault-kpi-snapshot/v1",
    snapshot_id: snapshot.snapshot_id,
    observed_date: date,
    observed_at: observedAt,
    source,
    overall_status: overall,
    benchmark_status: snapshot.benchmark_status,
    persisted: Boolean(persisted),
    inserted: persisted?.inserted ?? false,
    metrics: Object.fromEntries(metrics.map((row) => [row.metric_id, row.value])),
    slo_evaluations: sloEvaluations,
  };
}

function loadSnapshotParts(db, snapshotRows) {
  if (!snapshotRows.length) return [];
  const ids = snapshotRows.map((row) => sqlString(row.snapshot_id)).join(",");
  const metricRows = sqliteRows(db, `SELECT snapshot_id,metric_id,value,unit FROM metrics WHERE snapshot_id IN (${ids}) ORDER BY metric_id;`);
  const sloRows = sqliteRows(db, `SELECT snapshot_id,slo_id,status,severity,actual,target_json,reason_code FROM slo_evaluations WHERE snapshot_id IN (${ids}) ORDER BY slo_id;`);
  const metricsById = new Map();
  const slosById = new Map();
  for (const row of metricRows) {
    if (!metricsById.has(row.snapshot_id)) metricsById.set(row.snapshot_id, {});
    metricsById.get(row.snapshot_id)[row.metric_id] = Number(row.value);
  }
  for (const row of sloRows) {
    if (!slosById.has(row.snapshot_id)) slosById.set(row.snapshot_id, []);
    slosById.get(row.snapshot_id).push({
      slo_id: row.slo_id,
      status: row.status,
      severity: row.severity,
      actual: row.actual === null ? null : Number(row.actual),
      target: JSON.parse(row.target_json),
      reason_code: row.reason_code,
    });
  }
  return snapshotRows.map((row) => ({
    snapshot_id: row.snapshot_id,
    observed_date: row.observed_date,
    observed_at: row.observed_at,
    source: row.source,
    overall_status: row.overall_status,
    benchmark_status: row.benchmark_status,
    policy_id: row.policy_id,
    metrics: metricsById.get(row.snapshot_id) || {},
    slo_evaluations: slosById.get(row.snapshot_id) || [],
  }));
}

export function getLatestKpiSnapshot(options = {}, config = loadConfig()) {
  const path = validateExistingObservability(config);
  if (!path) return { found: false, snapshot: null };
  const rows = sqliteRows(path, `SELECT snapshot_id,observed_date,observed_at,source,overall_status,benchmark_status,policy_id
FROM snapshots ORDER BY observed_date DESC,observed_at DESC,rowid DESC LIMIT 1;`);
  return { found: rows.length > 0, snapshot: loadSnapshotParts(path, rows)[0] || null };
}

export function listKpiHistory(options = {}, config = loadConfig()) {
  const path = validateExistingObservability(config);
  if (!path) return { total: 0, results: [] };
  const limit = positiveInteger(options.limit || 100, "limit", 400);
  const filters = [];
  if (options.from) filters.push(`observed_date>=${sqlString(validIsoDate(options.from, "from"))}`);
  if (options.to) filters.push(`observed_date<=${sqlString(validIsoDate(options.to, "to"))}`);
  const where = filters.length ? `WHERE ${filters.join(" AND ")}` : "";
  const total = Number(sqliteRows(path, `SELECT COUNT(*) AS count FROM snapshots ${where};`)[0]?.count || 0);
  const rows = sqliteRows(path, `SELECT snapshot_id,observed_date,observed_at,source,overall_status,benchmark_status,policy_id
FROM snapshots ${where} ORDER BY observed_date DESC,observed_at DESC,rowid DESC LIMIT ${limit};`);
  return { total, truncated: total > rows.length, results: loadSnapshotParts(path, rows) };
}

function latestByDate(snapshots) {
  const byDate = new Map();
  for (const row of [...snapshots].sort((left, right) => left.observed_at.localeCompare(right.observed_at))) {
    byDate.set(row.observed_date, row);
  }
  return byDate;
}

function average(values) {
  return values.length ? Number((values.reduce((sum, value) => sum + value, 0) / values.length).toFixed(6)) : null;
}

function summarizePeriodBreaches(snapshots) {
  const statusRank = { unknown: 1, warn: 2, fail: 3 };
  const severityRank = { info: 0, P2: 1, P1: 2, P0: 3 };
  const summaries = new Map();
  for (const snapshot of snapshots) {
    for (const row of snapshot.slo_evaluations || []) {
      if (row.status === "pass" || row.severity === "info") continue;
      const existing = summaries.get(row.slo_id);
      if (!existing) {
        summaries.set(row.slo_id, {
          slo_id: row.slo_id,
          severity: row.severity,
          worst_status: row.status,
          first_seen: snapshot.observed_date,
          last_seen: snapshot.observed_date,
          occurrences: 1,
          reason_codes: [row.reason_code],
        });
        continue;
      }
      existing.last_seen = snapshot.observed_date;
      existing.occurrences += 1;
      if ((statusRank[row.status] || 0) > (statusRank[existing.worst_status] || 0)) {
        existing.worst_status = row.status;
      }
      if ((severityRank[row.severity] || 0) > (severityRank[existing.severity] || 0)) {
        existing.severity = row.severity;
      }
      if (!existing.reason_codes.includes(row.reason_code)) existing.reason_codes.push(row.reason_code);
    }
  }
  return [...summaries.values()].sort((left, right) =>
    (severityRank[right.severity] - severityRank[left.severity])
    || left.slo_id.localeCompare(right.slo_id));
}

export function getWeeklyKpiReport(options = {}, config = loadConfig()) {
  const date = validIsoDate(options.date || todayInZone());
  const days = positiveInteger(options.days || 7, "days", 31);
  const compareDays = positiveInteger(options.compareDays || days, "compareDays", 31);
  const currentStart = addDays(date, -(days - 1));
  const previousEnd = addDays(currentStart, -1);
  const previousStart = addDays(previousEnd, -(compareDays - 1));
  const db = validateExistingObservability(config);
  if (!db) {
    return {
      schema: "vault-kpi-report/v1",
      period: { start: currentStart, end: date, days_expected: days, days_present: 0 },
      comparison: { start: previousStart, end: previousEnd, days_expected: compareDays, days_present: 0 },
      overall_status: "unknown",
      metrics: [],
      slo_breaches: [],
      new_slo_breaches: [],
      unclassified_slo_breaches: [],
      regressions: [],
      missing_dates: datesBetween(currentStart, date),
      warnings: ["insufficient_history", "comparison_history_incomplete"],
    };
  }
  const latestRows = sqliteRows(db, `WITH ranked AS (
  SELECT snapshot_id,observed_date,observed_at,source,overall_status,benchmark_status,policy_id,
         ROW_NUMBER() OVER (PARTITION BY observed_date ORDER BY observed_at DESC,rowid DESC) AS rank
  FROM snapshots
  WHERE observed_date>=${sqlString(previousStart)} AND observed_date<=${sqlString(date)}
)
SELECT snapshot_id,observed_date,observed_at,source,overall_status,benchmark_status,policy_id
FROM ranked WHERE rank=1 ORDER BY observed_date,observed_at;`);
  const allRows = sqliteRows(db, `SELECT snapshot_id,observed_date,observed_at,source,overall_status,benchmark_status,policy_id
FROM snapshots
WHERE observed_date>=${sqlString(previousStart)} AND observed_date<=${sqlString(date)}
ORDER BY observed_date,observed_at,rowid;`);
  const allSnapshots = loadSnapshotParts(db, allRows);
  const byDate = latestByDate(loadSnapshotParts(db, latestRows));
  const currentDates = datesBetween(currentStart, date);
  const previousDates = datesBetween(previousStart, previousEnd);
  const current = currentDates.map((item) => byDate.get(item)).filter(Boolean);
  const previous = previousDates.map((item) => byDate.get(item)).filter(Boolean);
  const latest = current.at(-1) || null;
  const previousLatest = previous.at(-1) || null;
  const metricIds = new Set([...current, ...previous].flatMap((row) => Object.keys(row.metrics)));
  const metrics = [...metricIds].sort().map((metricId) => {
    const currentValues = current.map((row) => row.metrics[metricId]).filter(Number.isFinite);
    const previousValues = previous.map((row) => row.metrics[metricId]).filter(Number.isFinite);
    const currentEnd = latest?.metrics[metricId] ?? null;
    const previousEndValue = previousLatest?.metrics[metricId] ?? null;
    return {
      metric_id: metricId,
      current_end: currentEnd,
      previous_end: previousEndValue,
      delta: Number.isFinite(currentEnd) && Number.isFinite(previousEndValue)
        ? Number((currentEnd - previousEndValue).toFixed(6))
        : null,
      current_avg: average(currentValues),
      previous_avg: average(previousValues),
    };
  });
  const debtMetrics = new Set(["review.overdue", "handoff.stale", "curation.pending", "evidence.decisions_missing"]);
  const regressions = metrics.filter((row) => {
    if (!debtMetrics.has(row.metric_id) || !Number.isFinite(row.delta) || row.delta < 5) return false;
    const baseline = Math.max(1, Number(row.previous_end || 0));
    return row.delta / baseline >= 0.1;
  });
  const missingDates = currentDates.filter((item) => !byDate.has(item));
  const breaches = (latest?.slo_evaluations || []).filter((row) => row.status !== "pass" && row.severity !== "info");
  const currentPeriodBreaches = summarizePeriodBreaches(
    allSnapshots.filter((row) => row.observed_date >= currentStart),
  );
  const previousBreachIds = new Set(summarizePeriodBreaches(
    allSnapshots.filter((row) => row.observed_date <= previousEnd),
  ).map((row) => row.slo_id));
  const newBreachCandidates = currentPeriodBreaches.filter((row) => !previousBreachIds.has(row.slo_id));
  const comparisonComplete = previous.length === compareDays;
  let overall = latest?.overall_status || "unknown";
  if (current.length < Math.min(days, 5)) overall = overall === "fail" ? "fail" : "unknown";
  else if (regressions.length && overall === "pass") overall = "warn";
  const warnings = [];
  if (current.length < Math.min(days, 5)) warnings.push("insufficient_history");
  if (!comparisonComplete) warnings.push("comparison_history_incomplete");
  return {
    schema: "vault-kpi-report/v1",
    period: {
      start: currentStart,
      end: date,
      days_expected: days,
      days_present: current.length,
    },
    comparison: {
      start: previousStart,
      end: previousEnd,
      days_expected: compareDays,
      days_present: previous.length,
    },
    overall_status: overall,
    metrics,
    slo_breaches: breaches,
    new_slo_breaches: comparisonComplete ? newBreachCandidates : [],
    unclassified_slo_breaches: comparisonComplete ? [] : newBreachCandidates,
    regressions,
    missing_dates: missingDates,
    warnings,
  };
}
