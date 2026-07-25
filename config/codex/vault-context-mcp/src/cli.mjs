#!/usr/bin/env node

import { readFileSync } from "node:fs";
import { basename } from "node:path";
import { evaluateRetrievalBenchmark } from "./benchmark.mjs";
import {
  backlinks,
  capture,
  captureRaw,
  contextForPrompt,
  deriveContextKey,
  embedVault,
  fetchNote,
  generateDaily,
  generateWeekly,
  health,
  inbox,
  loadConfig,
  processRaw,
  quality,
  relatedContext,
  reindex,
  review,
  search,
  searchChunks,
  semanticSearch,
  startup,
} from "./core.mjs";
import {
  getLatestKpiSnapshot,
  getWeeklyKpiReport,
  listKpiHistory,
  recordKpiSnapshot,
} from "./observability.mjs";

const CAPTURE_TYPES = new Set(["task", "decision", "note", "risk", "learning", "question", "handoff", "investigation"]);

function parseArgs(argv) {
  const flags = {};
  const positional = [];
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--") {
      positional.push(...argv.slice(i + 1));
      break;
    }
    if (arg.startsWith("--no-")) {
      flags[arg.slice(5).replaceAll("-", "_")] = false;
    } else if (arg.startsWith("--")) {
      const body = arg.slice(2);
      const eq = body.indexOf("=");
      if (eq !== -1) flags[body.slice(0, eq).replaceAll("-", "_")] = body.slice(eq + 1);
      else if (argv[i + 1] && !argv[i + 1].startsWith("-")) flags[body.replaceAll("-", "_")] = argv[++i];
      else flags[body.replaceAll("-", "_")] = true;
    } else positional.push(arg);
  }
  return { flags, positional };
}

function bool(value, fallback = false) {
  if (value === undefined) return fallback;
  if (typeof value === "boolean") return value;
  return !["0", "false", "no", "off"].includes(String(value).toLowerCase());
}

function integer(value, fallback) {
  const parsed = Number.parseInt(String(value ?? ""), 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function number(value, fallback) {
  if (value === undefined) return fallback;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : Number.NaN;
}

function optionalBool(value) {
  return value === undefined ? undefined : bool(value);
}

function body(flags) {
  if (flags.body) return String(flags.body);
  if (flags.body_file) return readFileSync(String(flags.body_file), "utf8");
  if (bool(flags.stdin, false)) return readFileSync(0, "utf8");
  return "";
}

function output(value, json = false) {
  if (json) {
    console.log(JSON.stringify(value, null, 2));
    return;
  }
  const rows = Array.isArray(value) ? value : value?.results;
  if (!rows) {
    console.log(JSON.stringify(value, null, 2));
    return;
  }
  if (!rows.length) console.log("No results.");
  for (const row of rows) {
    const meta = [row.kind || row.type, row.status, row.priority].filter(Boolean).join(" ");
    console.log(`${row.title || row.path}${meta ? ` (${meta})` : ""}`);
    if (row.path) console.log(`  ${row.path}`);
    if (row.next_action) console.log(`  next: ${row.next_action}`);
  }
}

function captureArgs(type, title, flags) {
  return {
    kind: type === "investigation" ? "note" : type,
    title,
    summary: flags.summary,
    status: flags.status,
    lifecycle: flags.lifecycle,
    priority: flags.priority,
    contextKey: flags.context_key,
    scopeKeys: flags.scope_keys ? String(flags.scope_keys).split(",").map((value) => value.trim()).filter(Boolean) : undefined,
    projects: flags.projects ? String(flags.projects).split(",").map((value) => value.trim()).filter(Boolean) : undefined,
    owners: flags.owners ? String(flags.owners).split(",").map((value) => value.trim()).filter(Boolean) : (flags.owner ? [String(flags.owner)] : undefined),
    nextAction: flags.next_action,
    evidenceUrl: flags.evidence_url,
    evidence: flags.evidence ? String(flags.evidence).split(",").map((value) => value.trim()).filter(Boolean) : undefined,
    sourceKind: flags.source_kind || flags.source,
    sourceDetail: flags.source_detail,
    confidence: flags.confidence,
    reviewAfter: flags.review_after,
    pinned: bool(flags.pinned, false),
    tags: flags.tags ? String(flags.tags).split(",").map((tag) => tag.trim()).filter(Boolean) : ["codex"],
    aliases: flags.aliases ? String(flags.aliases).split(",").map((value) => value.trim()).filter(Boolean) : undefined,
    searchTerms: flags.search_terms ? String(flags.search_terms).split(",").map((value) => value.trim()).filter(Boolean) : undefined,
    related: flags.related ? String(flags.related).split(",").map((value) => value.trim()).filter(Boolean) : undefined,
    supersedes: flags.supersedes ? String(flags.supersedes).split(",").map((value) => value.trim()).filter(Boolean) : undefined,
    supersededBy: flags.superseded_by ? String(flags.superseded_by).split(",").map((value) => value.trim()).filter(Boolean) : undefined,
    dependsOn: flags.depends_on ? String(flags.depends_on).split(",").map((value) => value.trim()).filter(Boolean) : undefined,
    supports: flags.supports ? String(flags.supports).split(",").map((value) => value.trim()).filter(Boolean) : undefined,
    contradicts: flags.contradicts ? String(flags.contradicts).split(",").map((value) => value.trim()).filter(Boolean) : undefined,
    derivedFrom: flags.derived_from ? String(flags.derived_from).split(",").map((value) => value.trim()).filter(Boolean) : undefined,
    body: body(flags),
    cwd: flags.cwd || process.cwd(),
    task: flags.task,
    extra: flags.extra,
  };
}

function usage() {
  return `Usage:
  vault-context health
  vault-context reindex
  vault-context key [--cwd PATH] [--task TEXT]
  vault-context startup [--limit N]
  vault-context context --prompt TEXT [--stdin] [--scope-only] [--budget N]
  vault-context search QUERY [--kind decision] [--status accepted]
  vault-context chunks QUERY [--kind decision]
  vault-context semantic QUERY [--model qwen3-embedding:0.6b] [--minimum-similarity 0.45]
  vault-context embed [--model qwen3-embedding:0.6b] [--batch-size 12] [--force]
  vault-context fetch PATH_OR_ID
  vault-context backlinks PATH_OR_ID
  vault-context related PATH_OR_ID
  vault-context quality [--today YYYY-MM-DD]
  vault-context benchmark [--suite VAULT_RELATIVE_PATH] [--tracks lexical,chunks,hybrid,context,scope] [--strict]
  vault-context kpi snapshot [--date YYYY-MM-DD] [--source morning] [--no-write] [--no-benchmark]
  vault-context kpi latest
  vault-context kpi history [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--limit N]
  vault-context kpi report [--date YYYY-MM-DD] [--days 7] [--compare-days 7]
  vault-context review [--before YYYY-MM-DD]
  vault-context inbox
  vault-context raw --stdin [--title TITLE]
  vault-context process RAW_PATH --kind note --summary TEXT --body-file PATH
  vault-context daily [--date YYYY-MM-DD]
  vault-context weekly [--date YYYY-MM-DD] [--stdin]
  vault-context decision|handoff|risk|learning|question|investigation TITLE [options]

All commands accept --json.`;
}

async function main() {
  const [command = "help", ...rest] = process.argv.slice(2);
  const { flags, positional } = parseArgs(rest);
  if (["help", "--help", "-h"].includes(command) || flags.help) {
    console.log(usage());
    return;
  }
  const config = loadConfig();
  let result;
  switch (command) {
    case "health":
      result = health(config);
      break;
    case "reindex":
      result = reindex(config);
      break;
    case "key":
      result = deriveContextKey({ cwd: flags.cwd || process.cwd(), task: positional.join(" ") || flags.task || "", extra: flags.extra || "" });
      break;
    case "startup":
      result = startup({ limit: integer(flags.limit, 8) }, config);
      break;
    case "context":
      result = contextForPrompt({
        prompt: bool(flags.stdin, false) ? readFileSync(0, "utf8") : flags.prompt || positional.join(" "),
        cwd: flags.cwd || process.cwd(),
        limit: integer(flags.limit, 8),
        budget: integer(flags.budget, 2600),
        scopeOnly: bool(flags.scope_only, false),
      }, config);
      break;
    case "search":
      result = search(positional.join(" ") || flags.query || "", {
        limit: integer(flags.limit, 10),
        kind: flags.kind || flags.type,
        status: flags.status,
        contextKey: flags.context_key,
        project: flags.project,
        includeArchived: bool(flags.archived, false),
        includeRaw: bool(flags.raw, false),
        includeInvalid: bool(flags.invalid, false),
        includeNoncanonical: bool(flags.noncanonical, false),
      }, config);
      break;
    case "chunks":
      result = searchChunks(positional.join(" ") || flags.query || "", {
        limit: integer(flags.limit, 12),
        kind: flags.kind || flags.type,
        status: flags.status,
        contextKey: flags.context_key,
        project: flags.project,
        includeArchived: bool(flags.archived, false),
        includeRaw: bool(flags.raw, false),
        includeInvalid: bool(flags.invalid, false),
        includeNoncanonical: bool(flags.noncanonical, false),
      }, config);
      break;
    case "semantic":
      result = await semanticSearch(positional.join(" ") || flags.query || "", {
        limit: integer(flags.limit, 10),
        model: flags.model,
        minimumSimilarity: number(flags.minimum_similarity, undefined),
        includeArchived: bool(flags.archived, false),
      }, config);
      break;
    case "embed":
      result = await embedVault({
        model: flags.model,
        batchSize: integer(flags.batch_size, 12),
        force: bool(flags.force, false),
      }, config);
      break;
    case "fetch":
      result = fetchNote(positional.join(" ") || flags.target, config);
      break;
    case "backlinks":
      result = backlinks(positional.join(" ") || flags.target, { limit: integer(flags.limit, 50) }, config);
      break;
    case "related":
      result = relatedContext(positional.join(" ") || flags.target, { limit: integer(flags.limit, 30), includeArchived: bool(flags.archived, false) }, config);
      break;
    case "quality":
      result = quality({
        today: flags.today,
        pinnedLimit: integer(flags.pinned_limit, 8),
        staleHandoffDays: integer(flags.stale_handoff_days, 14),
        limit: integer(flags.limit, 50),
      }, config);
      break;
    case "benchmark":
      result = await evaluateRetrievalBenchmark({
        suitePath: flags.suite,
        tracks: flags.tracks ? String(flags.tracks).split(",").map((value) => value.trim()).filter(Boolean) : undefined,
        timeoutMs: integer(flags.timeout_ms, undefined),
      }, config);
      if (bool(flags.strict, false) && result.status === "fail") process.exitCode = 2;
      break;
    case "kpi": {
      const subcommand = positional.shift() || "latest";
      if (subcommand === "snapshot") {
        result = await recordKpiSnapshot({
          date: flags.date,
          source: flags.source || "manual",
          policyPath: flags.policy,
          benchmark: bool(flags.benchmark, true),
          tracks: flags.tracks ? String(flags.tracks).split(",").map((value) => value.trim()).filter(Boolean) : undefined,
          timeoutMs: integer(flags.timeout_ms, undefined),
          write: bool(flags.write, true),
          enforceDaily: optionalBool(flags.enforce_daily),
          requireWeekly: bool(flags.require_weekly, false),
        }, config);
        if (bool(flags.strict, false) && result.overall_status === "fail") process.exitCode = 2;
      } else if (subcommand === "latest") {
        result = getLatestKpiSnapshot({}, config);
      } else if (subcommand === "history") {
        result = listKpiHistory({
          from: flags.from,
          to: flags.to,
          limit: integer(flags.limit, 100),
        }, config);
      } else if (subcommand === "report") {
        result = getWeeklyKpiReport({
          date: flags.date,
          days: integer(flags.days, 7),
          compareDays: integer(flags.compare_days, 7),
        }, config);
        if (bool(flags.strict, false) && result.overall_status === "fail") process.exitCode = 2;
      } else {
        throw new Error(`Unknown kpi subcommand: ${subcommand}`);
      }
      break;
    }
    case "review":
      result = review({ before: flags.before, limit: integer(flags.limit, 50) }, config);
      break;
    case "inbox":
      result = inbox({ limit: integer(flags.limit, 50) }, config);
      break;
    case "raw":
      result = captureRaw({
        text: body(flags) || positional.join(" "),
        title: flags.title,
        tags: flags.tags ? String(flags.tags).split(",").map((tag) => tag.trim()).filter(Boolean) : undefined,
      }, config);
      break;
    case "process":
      result = processRaw({
        ...captureArgs(flags.kind || flags.type || "note", flags.title, flags),
        target: positional.join(" ") || flags.target,
        allowSensitive: bool(flags.allow_sensitive, false),
      }, config);
      break;
    case "daily":
      result = generateDaily({ date: flags.date }, config);
      break;
    case "weekly":
      result = generateWeekly({ date: flags.date, narrative: body(flags) }, config);
      break;
    case "capture": {
      const type = positional.shift() || flags.type || "note";
      if (!CAPTURE_TYPES.has(type)) throw new Error(`Unsupported capture type: ${type}`);
      result = capture(captureArgs(type, positional.join(" ") || flags.title, flags), config);
      break;
    }
    default:
      if (!CAPTURE_TYPES.has(command)) throw new Error(`Unknown command: ${command}\n${usage()}`);
      result = capture(captureArgs(command, positional.join(" ") || flags.title, flags), config);
  }
  output(result, bool(flags.json, false));
}

main().catch((error) => {
  console.error(`${basename(process.argv[1])}: ${error.message}`);
  process.exit(1);
});
