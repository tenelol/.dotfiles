import { existsSync, lstatSync, readFileSync, realpathSync } from "node:fs";
import { join, relative, resolve, sep } from "node:path";
import {
  contextForPrompt,
  fetchNote,
  health,
  loadConfig,
  relatedContext,
  search,
  searchChunks,
  semanticSearch,
  suspectedSensitive,
} from "./core.mjs";
import { sha256 } from "./schema.mjs";

const SUITE_SCHEMA = "vault-retrieval-golden/v1";
const TRACKS = new Set(["lexical", "chunks", "hybrid", "context", "scope"]);
const TRACK_DEFAULT_K = { lexical: 5, chunks: 5, hybrid: 5, context: 3, scope: 5 };

function isPlainObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function finiteNumber(value, label, { min = -Infinity, max = Infinity } = {}) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < min || parsed > max) {
    throw new Error(`${label} must be a finite number from ${min} to ${max}`);
  }
  return parsed;
}

function positiveInteger(value, label, { max = 100 } = {}) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1 || parsed > max) {
    throw new Error(`${label} must be an integer from 1 to ${max}`);
  }
  return parsed;
}

function safeVaultFile(vaultRoot, input, defaultRelative) {
  const root = resolve(vaultRoot);
  const rootReal = realpathSync(root);
  const candidate = resolve(root, input || defaultRelative);
  const rel = relative(root, candidate);
  if (!rel || rel === ".." || rel.startsWith(`..${sep}`)) {
    throw new Error("Golden query suite must stay inside the configured vault");
  }
  let cursor = root;
  for (const component of rel.split(sep)) {
    cursor = join(cursor, component);
    if (!existsSync(cursor)) throw new Error("Golden query suite does not exist");
    const metadata = lstatSync(cursor);
    if (metadata.isSymbolicLink()) throw new Error("Golden query suite path must not contain a symlink");
    const cursorReal = realpathSync(cursor);
    const realRel = relative(rootReal, cursorReal);
    if (realRel === ".." || realRel.startsWith(`..${sep}`)) {
      throw new Error("Golden query suite escapes the configured vault");
    }
  }
  if (!lstatSync(candidate).isFile()) throw new Error("Golden query suite must be a regular file");
  return candidate;
}

function normalizedPaths(values, label) {
  const paths = [...new Set((values || []).map((value) => String(value || "").trim()).filter(Boolean))];
  for (const path of paths) {
    if (
      path.startsWith("/")
      || path.startsWith("\\")
      || path.split(/[\\/]/).includes("..")
      || !/^(?:10 Records|20 Synthesis)\/.+\.md$/.test(path)
    ) {
      throw new Error(`${label} contains an unsafe Vault path`);
    }
  }
  return paths;
}

function validateExpectedNotes(cases, config) {
  const expected = new Set();
  for (const item of cases) {
    for (const path of [
      ...item.expect.relevant.map((entry) => entry.path),
      ...item.expect.required_any,
      ...item.expect.required_all,
      ...item.expect.forbidden,
    ]) expected.add(path);
    if (item.input.seed_path) expected.add(item.input.seed_path);
  }
  for (const path of expected) {
    const note = fetchNote(path, config);
    if (note.properties?.schema !== "vault-note/v2" || note.properties?.canonical === false) {
      throw new Error(`Golden query expectation is not a canonical vault-note/v2 record: ${path}`);
    }
  }
}

function normalizeCase(raw, index) {
  if (!isPlainObject(raw)) throw new Error(`cases[${index}] must be an object`);
  const id = String(raw.id || "").trim();
  if (!/^[a-z0-9][a-z0-9._-]{2,79}$/.test(id)) throw new Error(`cases[${index}].id is invalid`);
  const tier = raw.tier === "diagnostic" ? "diagnostic" : "gate";
  const tracks = [...new Set((raw.tracks || []).map((value) => String(value)))];
  if (!tracks.length || tracks.some((track) => !TRACKS.has(track))) {
    throw new Error(`${id}.tracks must contain supported retrieval tracks`);
  }
  const input = isPlainObject(raw.input) ? raw.input : {};
  const query = String(input.query || "");
  if (tracks.some((track) => track !== "scope") && !query.trim()) throw new Error(`${id} requires a query`);
  if (query.length > 2000) throw new Error(`${id} query is too long`);
  if (query && suspectedSensitive(query)) throw new Error(`${id} query looks sensitive`);
  const seedPath = input.seed_path ? normalizedPaths([input.seed_path], `${id}.input.seed_path`)[0] : null;
  if (tracks.includes("scope") && !seedPath) throw new Error(`${id} scope track requires seed_path`);
  const rawExpect = isPlainObject(raw.expect) ? raw.expect : {};
  const relevant = (rawExpect.relevant || []).map((entry, relevanceIndex) => {
    if (!isPlainObject(entry)) throw new Error(`${id}.expect.relevant[${relevanceIndex}] must be an object`);
    const path = normalizedPaths([entry.path], `${id}.expect.relevant`)[0];
    const grade = positiveInteger(entry.grade || 1, `${id}.expect.relevant.grade`, { max: 3 });
    return { path, grade };
  });
  const requiredAny = normalizedPaths(rawExpect.required_any, `${id}.expect.required_any`);
  const requiredAll = normalizedPaths(rawExpect.required_all, `${id}.expect.required_all`);
  const forbidden = normalizedPaths(rawExpect.forbidden, `${id}.expect.forbidden`);
  const maxResults = rawExpect.max_results === undefined || rawExpect.max_results === null
    ? null
    : Number(rawExpect.max_results);
  if (maxResults !== null && (!Number.isInteger(maxResults) || maxResults < 0 || maxResults > 100)) {
    throw new Error(`${id}.expect.max_results must be an integer from 0 to 100`);
  }
  if (!relevant.length && !requiredAny.length && !requiredAll.length && maxResults === null && !forbidden.length) {
    throw new Error(`${id} has no measurable expectation`);
  }
  const trackK = {};
  for (const [track, value] of Object.entries(raw.track_k || {})) {
    if (!TRACKS.has(track)) throw new Error(`${id}.track_k contains an unsupported track`);
    trackK[track] = positiveInteger(value, `${id}.track_k.${track}`, { max: 30 });
  }
  return {
    id,
    tier,
    tracks,
    input: { query, cwd: input.cwd ? String(input.cwd) : undefined, seed_path: seedPath },
    expect: {
      relevant,
      required_any: requiredAny,
      required_all: requiredAll,
      forbidden,
      max_results: maxResults,
    },
    track_k: trackK,
    tags: [...new Set((raw.tags || []).map((value) => String(value).trim()).filter(Boolean))].slice(0, 20),
  };
}

export function loadGoldenSuite({ suitePath } = {}, config = loadConfig()) {
  const path = safeVaultFile(
    config.vaultRoot,
    suitePath || process.env.VAULT_CONTEXT_GOLDEN_SUITE,
    "90 System/Policies/retrieval-golden-queries.json",
  );
  const source = readFileSync(path, "utf8");
  let raw;
  try {
    raw = JSON.parse(source);
  } catch {
    throw new Error("Golden query suite is not valid JSON");
  }
  if (!isPlainObject(raw) || raw.schema !== SUITE_SCHEMA) {
    throw new Error(`Golden query suite schema must be ${SUITE_SCHEMA}`);
  }
  const suiteId = String(raw.suite_id || "").trim();
  if (!/^[a-z0-9][a-z0-9._-]{2,79}$/.test(suiteId)) throw new Error("Golden query suite_id is invalid");
  if (!Array.isArray(raw.cases) || !raw.cases.length || raw.cases.length > 100) {
    throw new Error("Golden query suite must contain 1 to 100 cases");
  }
  const cases = raw.cases.map(normalizeCase);
  if (new Set(cases.map((item) => item.id)).size !== cases.length) throw new Error("Golden query case ids must be unique");
  const defaults = isPlainObject(raw.defaults) ? raw.defaults : {};
  const minimumSemanticCoverage = finiteNumber(
    defaults.minimum_semantic_coverage ?? 1,
    "defaults.minimum_semantic_coverage",
    { min: 0, max: 1 },
  );
  const minimumCaseCount = positiveInteger(defaults.minimum_case_count ?? 1, "defaults.minimum_case_count", { max: 100 });
  if (cases.length < minimumCaseCount) throw new Error(`Golden query suite requires at least ${minimumCaseCount} cases`);
  const gates = {};
  for (const [name, value] of Object.entries(raw.gates || {})) {
    gates[name] = finiteNumber(value, `gates.${name}`, { min: 0, max: name.endsWith("forbidden_hits") ? 1000 : 1 });
  }
  for (const name of Object.keys(gates)) {
    if (name === "all.negative_pass_rate" || name === "all.forbidden_hits") continue;
    const match = name.match(/^(lexical|chunks|hybrid|context|scope)\.(?:relevant_hit_at_|hit_at_|recall_at_|ndcg_at_)(\d+)$/);
    if (!match) {
      if (/^(lexical|chunks|hybrid|context|scope)\.mrr$/.test(name)) continue;
      throw new Error(`Unsupported benchmark gate: ${name}`);
    }
    const track = match[1];
    const requestedK = positiveInteger(match[2], `gates.${name} k`, { max: 30 });
    const trackCases = cases.filter((item) => item.tracks.includes(track));
    if (!trackCases.length) throw new Error(`Benchmark gate ${name} has no matching cases`);
    if (trackCases.some((item) => (item.track_k[track] || TRACK_DEFAULT_K[track]) !== requestedK)) {
      throw new Error(`Benchmark gate ${name} does not match the configured ${track} case k`);
    }
  }
  validateExpectedNotes(cases, config);
  return {
    schema: SUITE_SCHEMA,
    suite_id: suiteId,
    suite_sha256: sha256(source),
    path: relative(config.vaultRoot, path).split(sep).join("/"),
    defaults: { minimum_semantic_coverage: minimumSemanticCoverage, minimum_case_count: minimumCaseCount },
    gates,
    cases,
  };
}

function deduplicatedPaths(rows) {
  return [...new Set((rows || []).map((row) => row?.path).filter(Boolean))];
}

function percentile(values, percentileValue) {
  if (!values.length) return null;
  const sorted = [...values].sort((left, right) => left - right);
  const index = Math.min(sorted.length - 1, Math.max(0, Math.ceil(percentileValue * sorted.length) - 1));
  return Number(sorted[index].toFixed(3));
}

function dcg(paths, grades, k) {
  return paths.slice(0, k).reduce((sum, path, index) => {
    const grade = grades.get(path) || 0;
    return sum + ((2 ** grade) - 1) / Math.log2(index + 2);
  }, 0);
}

function scoreOutcome(item, track, paths, latencyMs, runtimeStatus = "complete") {
  const k = item.track_k[track] || TRACK_DEFAULT_K[track];
  const top = paths.slice(0, k);
  const rankByPath = new Map(paths.map((path, index) => [path, index + 1]));
  const relevantGrades = new Map(item.expect.relevant.map((entry) => [entry.path, entry.grade]));
  const relevantPaths = [...new Set([
    ...item.expect.relevant.map((entry) => entry.path),
    ...item.expect.required_any,
    ...item.expect.required_all,
  ])];
  const relevantRanks = relevantPaths.map((path) => rankByPath.get(path)).filter(Boolean);
  const firstRelevantRank = relevantRanks.length ? Math.min(...relevantRanks) : null;
  const requiredAnyPassed = !item.expect.required_any.length
    || item.expect.required_any.some((path) => top.includes(path));
  const requiredAllPassed = item.expect.required_all.every((path) => top.includes(path));
  const forbiddenHits = item.expect.forbidden.filter((path) => top.includes(path));
  const maxResultsPassed = item.expect.max_results === null || paths.length <= item.expect.max_results;
  const positivePassed = !relevantPaths.length || relevantRanks.some((rank) => rank <= k);
  const passed = runtimeStatus === "complete"
    && requiredAnyPassed
    && requiredAllPassed
    && forbiddenHits.length === 0
    && maxResultsPassed
    && positivePassed;
  const matchedRelevant = relevantPaths.filter((path) => top.includes(path));
  const idealGrades = [...relevantGrades.values()].sort((left, right) => right - left);
  const idealDcg = idealGrades.slice(0, k).reduce(
    (sum, grade, index) => sum + ((2 ** grade) - 1) / Math.log2(index + 2),
    0,
  );
  const actualDcg = dcg(paths, relevantGrades, k);
  return {
    case_id: item.id,
    tier: item.tier,
    track,
    query_sha256: sha256(track === "scope" ? `scope:${item.input.seed_path}` : item.input.query),
    status: runtimeStatus,
    passed,
    k,
    result_count: paths.length,
    hit_rank: firstRelevantRank,
    reciprocal_rank: firstRelevantRank ? Number((1 / firstRelevantRank).toFixed(6)) : 0,
    recall_at_k: relevantPaths.length ? Number((matchedRelevant.length / relevantPaths.length).toFixed(6)) : null,
    ndcg_at_k: idealDcg ? Number((actualDcg / idealDcg).toFixed(6)) : null,
    forbidden_hits: forbiddenHits.length,
    expected_paths: relevantPaths,
    result_paths: top,
    latency_ms: Number(latencyMs.toFixed(3)),
  };
}

async function retrieveForTrack(item, track, suite, config, options) {
  const k = item.track_k[track] || TRACK_DEFAULT_K[track];
  const limit = Math.max(k, track === "context" ? 8 : 10);
  if (track === "lexical") return deduplicatedPaths(search(item.input.query, { limit }, config).results);
  if (track === "chunks") return deduplicatedPaths(searchChunks(item.input.query, { limit }, config).results);
  if (track === "context") {
    return deduplicatedPaths(contextForPrompt({
      prompt: item.input.query,
      cwd: item.input.cwd || config.vaultRoot,
      limit,
      budget: 12_000,
    }, config).relevant);
  }
  if (track === "scope") return deduplicatedPaths(relatedContext(item.input.seed_path, { limit }, config).results);
  const currentHealth = options.currentHealth;
  if (currentHealth.semantic_index.coverage < suite.defaults.minimum_semantic_coverage) {
    return { runtimeStatus: "degraded", paths: [] };
  }
  try {
    const response = await semanticSearch(item.input.query, {
      limit,
      embedder: options.embedder,
      timeoutMs: options.timeoutMs,
    }, config);
    return deduplicatedPaths(response.results);
  } catch {
    return { runtimeStatus: "unavailable", paths: [] };
  }
}

function aggregateTrack(track, outcomes) {
  const rows = outcomes.filter((row) => row.track === track);
  const complete = rows.filter((row) => row.status === "complete");
  const positive = complete.filter((row) => row.expected_paths.length);
  const negative = complete.filter((row) => !row.expected_paths.length);
  const latencies = complete.map((row) => row.latency_ms);
  return {
    cases: rows.length,
    complete: complete.length,
    degraded: rows.filter((row) => row.status === "degraded").length,
    unavailable: rows.filter((row) => row.status === "unavailable").length,
    passed: rows.filter((row) => row.passed).length,
    pass_rate: rows.length ? Number((rows.filter((row) => row.passed).length / rows.length).toFixed(6)) : null,
    hit_rate_at_k: positive.length
      ? Number((positive.filter((row) => row.hit_rank && row.hit_rank <= row.k).length / positive.length).toFixed(6))
      : null,
    recall_at_k: positive.length
      ? Number((positive.reduce((sum, row) => sum + Number(row.recall_at_k || 0), 0) / positive.length).toFixed(6))
      : null,
    mrr: positive.length
      ? Number((positive.reduce((sum, row) => sum + row.reciprocal_rank, 0) / positive.length).toFixed(6))
      : null,
    ndcg_at_k: positive.length
      ? Number((positive.reduce((sum, row) => sum + Number(row.ndcg_at_k || 0), 0) / positive.length).toFixed(6))
      : null,
    negative_pass_rate: negative.length
      ? Number((negative.filter((row) => row.passed).length / negative.length).toFixed(6))
      : null,
    forbidden_hits: rows.reduce((sum, row) => sum + row.forbidden_hits, 0),
    latency_ms: {
      p50: percentile(latencies, 0.5),
      p95: percentile(latencies, 0.95),
    },
  };
}

function gateActual(name, aggregates, outcomes) {
  if (name === "all.negative_pass_rate") {
    const negative = outcomes.filter((row) => row.status === "complete" && !row.expected_paths.length);
    return negative.length ? negative.filter((row) => row.passed).length / negative.length : null;
  }
  if (name === "all.forbidden_hits") return outcomes.reduce((sum, row) => sum + row.forbidden_hits, 0);
  const match = name.match(/^(lexical|chunks|hybrid|context|scope)\.(relevant_hit_at_\d+|hit_at_\d+|recall_at_\d+|mrr|ndcg_at_\d+)$/);
  if (!match) throw new Error(`Unsupported benchmark gate: ${name}`);
  const aggregate = aggregates[match[1]];
  if (!aggregate) return null;
  if (match[2].startsWith("relevant_hit_at_") || match[2].startsWith("hit_at_")) return aggregate.hit_rate_at_k;
  if (match[2].startsWith("recall_at_")) return aggregate.recall_at_k;
  if (match[2].startsWith("ndcg_at_")) return aggregate.ndcg_at_k;
  return aggregate.mrr;
}

export async function evaluateRetrievalBenchmark(options = {}, config = loadConfig()) {
  const suite = options.suite || loadGoldenSuite({ suitePath: options.suitePath }, config);
  const selectedTracks = options.tracks?.length ? new Set(options.tracks) : null;
  if (selectedTracks && [...selectedTracks].some((track) => !TRACKS.has(track))) {
    throw new Error("Benchmark tracks contain an unsupported value");
  }
  const currentHealth = health(config);
  const outcomes = [];
  for (const item of suite.cases) {
    for (const track of item.tracks) {
      if (selectedTracks && !selectedTracks.has(track)) continue;
      const started = performance.now();
      const retrieved = await retrieveForTrack(item, track, suite, config, {
        currentHealth,
        embedder: options.embedder,
        timeoutMs: options.timeoutMs,
      });
      const latency = performance.now() - started;
      const paths = Array.isArray(retrieved) ? retrieved : retrieved.paths;
      const runtimeStatus = Array.isArray(retrieved) ? "complete" : retrieved.runtimeStatus;
      outcomes.push(scoreOutcome(item, track, paths, latency, runtimeStatus));
    }
  }
  const aggregates = {};
  for (const track of TRACKS) {
    if (outcomes.some((row) => row.track === track)) aggregates[track] = aggregateTrack(track, outcomes);
  }
  const gates = Object.entries(suite.gates).map(([gate, target]) => {
    const actual = gateActual(gate, aggregates, outcomes);
    const maximum = gate.endsWith("forbidden_hits");
    return {
      gate,
      target,
      actual: actual === null ? null : Number(actual.toFixed(6)),
      passed: actual === null ? null : (maximum ? actual <= target : actual >= target),
    };
  });
  const gatedTracks = new Set(gates.map((gate) => gate.gate.split(".")[0]).filter((name) => TRACKS.has(name)));
  const gateRows = outcomes.filter((row) => row.tier === "gate" && gatedTracks.has(row.track));
  const runtimeDegraded = gateRows.some((row) => row.status !== "complete");
  const failedGate = gates.some((gate) => gate.passed === false)
    || gateRows.some((row) => row.status === "complete" && !row.passed);
  const status = runtimeDegraded ? "degraded" : failedGate ? "fail" : "pass";
  return {
    schema: "vault-retrieval-benchmark/v1",
    suite_id: suite.suite_id,
    suite_sha256: suite.suite_sha256,
    status,
    semantic_coverage: currentHealth.semantic_index,
    aggregates,
    gates,
    cases: outcomes,
  };
}
