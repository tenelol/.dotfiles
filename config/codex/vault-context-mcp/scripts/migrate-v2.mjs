#!/usr/bin/env node

import {
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  realpathSync,
  renameSync,
  rmSync,
  rmdirSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, join, relative, resolve, sep } from "node:path";
import {
  SCHEMA_VERSION,
  asArray,
  deriveSummary,
  extractWikilinks,
  markdownPlainText,
  normalizeText,
  parseMarkdown,
  serializeMarkdown,
  sha256,
  todayInZone,
  validateVaultProperties,
} from "../src/schema.mjs";

const KIND_DIR = {
  decision: "10 Records/decision",
  handoff: "10 Records/handoff",
  risk: "10 Records/risk",
  learning: "10 Records/learning",
  task: "10 Records/task",
  note: "10 Records/note",
  question: "10 Records/question",
  project: "10 Records/project",
  runbook: "10 Records/runbook",
};

const SOURCE_DIRS = [
  "10 Context/Items",
  "10 Context/Projects",
  "10 Context/Runbooks",
];

const SCOPE_RULES = [
  ["repo:nerdechdev/overseassales", /\b(?:nerdechdev|overseassales(?:-dev)?)\b/i],
  ["project:tokiwa", /\btokiwa\b|ハーモニィ|uue?\d{2}|xp照合/i],
  ["project:kia-keiuno", /\bk[.]?uno\b|\bkeiuno\b|\bkia\b/i],
  ["repo:kuraryu405/iniad-quest", /\biniad[- ]?quest\b|\bquest\b.*\biniad\b/i],
  ["repo:tenelol/dotfiles", /\bdotfiles\b|\bnix-darwin\b|\baerospace\b|\brift\b/i],
  ["course:cos201", /\bcos201\b/i],
  ["course:cot201-cs3", /\bcot201\b|\bcs3\b/i],
  ["tool:imoocs", /\bimoocs\b|\bmoocscollect\b/i],
  ["project:portfolio", /\bportfolio\b|名刺|ポートフォリオ/i],
  ["project:ashen-oath", /ashen oath|灰鐘の誓い|\bthree-js\b/i],
  ["project:sweet-honey", /sweet ?honey/i],
  ["project:the-gavel-ai-dog", /the-gavel|the gavel|ai-dog|aiドッグ/i],
  ["project:codex-context", /codex.*context|context.*codex|notion-context|obsidian.*vault/i],
  ["global:codex", /codex.*(?:policy|workflow|skill|subagent|automation)|(?:policy|workflow).*codex/i],
];

function assertSafeVaultPath(vault, target, { mustExist = false } = {}) {
  const root = resolve(vault);
  if (!existsSync(root)) throw new Error(`Configured vault does not exist: ${root}`);
  const rootReal = realpathSync(root);
  const candidate = resolve(target);
  if (candidate !== root && !candidate.startsWith(`${root}${sep}`)) {
    throw new Error(`Path escapes the configured vault: ${candidate}`);
  }
  if (mustExist && !existsSync(candidate)) throw new Error(`Expected migration path does not exist: ${candidate}`);
  let existing = candidate;
  while (!existsSync(existing)) {
    const parent = dirname(existing);
    if (parent === existing) break;
    existing = parent;
  }
  const relativeExisting = relative(root, existing);
  let cursor = root;
  for (const segment of relativeExisting.split(sep).filter(Boolean)) {
    cursor = join(cursor, segment);
    if (lstatSync(cursor).isSymbolicLink()) {
      throw new Error(`Migration path must not traverse a symlink: ${cursor}`);
    }
  }
  const existingReal = realpathSync(existing);
  if (existingReal !== rootReal && !existingReal.startsWith(`${rootReal}${sep}`)) {
    throw new Error(`Migration path escapes the configured vault through a symlink: ${candidate}`);
  }
  return candidate;
}

function walk(root, vault) {
  const files = [];
  if (!existsSync(root)) return files;
  assertSafeVaultPath(vault, root, { mustExist: true });
  for (const entry of readdirSync(root, { withFileTypes: true })) {
    const path = join(root, entry.name);
    if (entry.isSymbolicLink()) throw new Error(`Migration source must not contain a symlink: ${path}`);
    assertSafeVaultPath(vault, path, { mustExist: true });
    if (entry.isDirectory()) files.push(...walk(path, vault));
    else if (entry.isFile() && entry.name.toLowerCase().endsWith(".md")) files.push(path);
  }
  return files.sort();
}

function vaultPath(vault, path) {
  return relative(vault, path).split(sep).join("/");
}

function stableId(value, oldPath) {
  const raw = String(value || "").trim();
  if (/^[0-9a-f-]{16,64}$/i.test(raw)) return raw.toLowerCase();
  return sha256(`${oldPath}\n${raw}`).slice(0, 32);
}

function legacyKind(parsed, path) {
  const p = parsed.properties;
  if (p.kind) return String(p.kind).toLowerCase();
  if (p.record_kind === "context-item") return String(p.type || "note").toLowerCase();
  if (p.record_kind === "project" || path.includes("/Projects/")) return "project";
  if (p.record_kind === "runbook" || path.includes("/Runbooks/")) return "runbook";
  return String(p.type || "note").toLowerCase();
}

function isLearning(kind, parsed) {
  if (kind !== "risk") return false;
  const text = `${parsed.title}\n${parsed.body}\n${parsed.tags.join(" ")}`;
  return /(?:^|\b)learning(?:\b|[-:：])|学習|^kind:\s*pain$/im.test(text);
}

function shortenTitle(title) {
  const normalized = String(title || "Untitled").replace(/\s+/g, " ").trim();
  if (normalized.length <= 140) return { title: normalized, original: null };
  const prefix = normalized.slice(0, 139);
  const boundaries = [prefix.lastIndexOf("。"), prefix.lastIndexOf("："), prefix.lastIndexOf(": "), prefix.lastIndexOf(" - "), prefix.lastIndexOf(" ")];
  const boundary = Math.max(...boundaries);
  const cut = boundary >= 70 ? prefix.slice(0, boundary) : prefix;
  return { title: `${cut.trim()}…`, original: normalized };
}

function cleanConnectorEnvelope(body) {
  let output = String(body || "").replace(/\r\n?/g, "\n");
  const blankEnvelope = /Here is the result of "view"[\s\S]*?<blank-page>[\s\S]*$/i.test(output)
    || /<ancestor-path>[\s\S]*?<blank-page>/i.test(output);
  if (blankEnvelope) output = "";
  output = output.replace(/\n?## Migration provenance[\s\S]*$/i, "");
  output = output.replace(/\n?## Relations\s*\n[\s\S]*?(?=\n## |$)/i, "");
  output = output.replace(/^#\s+.+\n+/, "");
  output = output.replace(/\n{3,}/g, "\n\n").trim();
  return { body: output, blankEnvelope };
}

function statusFor(kind, status) {
  const value = String(status || "").trim();
  const maps = {
    decision: { 完了: "accepted", 進行中: "proposed", 未着手: "proposed" },
    handoff: { 完了: "closed", 進行中: "current", 未着手: "current" },
    risk: { 完了: "mitigated", 進行中: "monitoring", 未着手: "open" },
    learning: { 完了: "valid", 進行中: "observed", 未着手: "observed" },
    task: { 完了: "done", 進行中: "doing", 未着手: "todo" },
    question: { 完了: "answered", 進行中: "open", 未着手: "open" },
    note: { 完了: "current", 進行中: "current", 未着手: "draft" },
    project: { 完了: "closed", 進行中: "active", 未着手: "planned" },
    runbook: { 完了: "verified", 進行中: "draft", 未着手: "draft" },
  };
  return maps[kind]?.[value] || value || ({ decision: "proposed", handoff: "current", risk: "open", learning: "observed", task: "todo", question: "open", note: "current", project: "active", runbook: "draft" })[kind];
}

function lifecycleFor(kind, properties, status) {
  if (properties.archived === true || properties.lifecycle === "archived") return "archived";
  if (["closed", "done"].includes(status) && ["handoff", "task", "project"].includes(kind)) return "history";
  return properties.lifecycle || "active";
}

function sourceKind(value) {
  const source = normalizeText(value);
  if (!source) return "unknown";
  if (source.includes("runtime") && source.includes("ci")) return "mixed";
  if (source.includes("repository") || source === "repo" || source.includes("github")) return "repository";
  if (source.includes("runtime")) return "runtime";
  if (source.includes("ci")) return "ci";
  if (source.includes("user")) return "user";
  if (source.includes("agent") || source.includes("codex")) return "agent";
  if (source.includes("notion")) return "import";
  if (source.includes("web")) return "web";
  return "mixed";
}

function priorityFor(value) {
  const normalized = normalizeText(value);
  if (["p0", "critical", "urgent"].includes(normalized)) return "P0";
  if (["p1", "high"].includes(normalized)) return "P1";
  if (["p3", "low"].includes(normalized)) return "P3";
  return "P2";
}

function scopeKeys(parsed, cleanedBody) {
  const haystack = `${parsed.title}\n${parsed.properties.context_key || ""}\n${cleanedBody}\n${parsed.tags.join(" ")}`;
  const keys = [];
  for (const [key, pattern] of SCOPE_RULES) if (pattern.test(haystack) && !keys.includes(key)) keys.push(key);
  const evidence = asArray(parsed.properties.evidence || parsed.properties.evidence_url).join("\n");
  for (const match of evidence.matchAll(/https?:\/\/github\.com\/([^/\s]+)\/([^/#?\s]+)/gi)) {
    const key = `repo:${match[1].toLowerCase()}/${match[2].replace(/\.git$/i, "").toLowerCase()}`;
    if (!keys.includes(key)) keys.unshift(key);
  }
  const issues = [
    ...[...evidence.matchAll(/github\.com\/[^/]+\/[^/]+\/(?:pull|issues)\/(\d+)/gi)].map((match) => `issue:${match[1]}`),
    ...[...haystack.matchAll(/(?:issue|pr|pull)\s*#(\d{1,7})/gi)].map((match) => `issue:${match[1]}`),
  ];
  for (const issue of issues) if (!keys.includes(issue)) keys.push(issue);
  return keys.slice(0, 8);
}

function rewriteWikilinks(body, byOldPath) {
  return String(body || "").replace(/\[\[([^\]|#]+)(#[^\]|]+)?(\|[^\]]+)?\]\]/g, (whole, rawTarget, subpath = "", alias = "") => {
    const normalized = rawTarget.trim().replace(/\.md$/i, "");
    const target = byOldPath.get(normalized) || byOldPath.get(basename(normalized));
    if (!target) return whole;
    return `[[${target.newPath.replace(/\.md$/i, "")}${subpath || ""}${alias || ""}]]`;
  });
}

function searchTerms(parsed, originalTitle) {
  const values = new Set([
    ...parsed.tags,
    ...asArray(parsed.properties.search_terms),
    ...String(parsed.properties.context_key || "").split(/\s+/),
  ]);
  if (originalTitle) values.add(originalTitle);
  return [...values].map((value) => String(value).trim()).filter((value) => value.length >= 2).slice(0, 40);
}

function fallbackScope(parsed, id) {
  const generic = new Set(["codex", "decision", "handoff", "risk", "learning", "note", "task", "question", "workflow", "context"]);
  const tag = parsed.tags.map(normalizeText).find((value) => value.length >= 2 && !generic.has(value));
  const titleToken = normalizeText(parsed.title).match(/[\p{L}\p{N}][\p{L}\p{N}._-]*/u)?.[0];
  const token = String(tag || titleToken || id.slice(-12)).replace(/[^\p{L}\p{N}._-]+/gu, "-").replace(/^-|-$/g, "").slice(0, 64);
  return `topic:${token || `uncurated-${id.slice(-12)}`}`;
}

function machineBody(title, summary, body, nextAction, needsCuration) {
  const sections = [`# ${title}`, "", "## Summary", "", summary || title];
  if (nextAction) sections.push("", "## Next action", "", String(nextAction).trim());
  if (body) sections.push("", "## Content", "", body);
  if (needsCuration && !body) sections.push("", "## Curation state", "", "Imported source body was empty. Metadata is preserved; do not infer missing facts.");
  return sections.join("\n");
}

function resolveRelations(record, byOldPath) {
  const rawTargets = [
    ...extractWikilinks(record.parsed.properties.related),
    ...extractWikilinks(record.parsed.properties.projects),
  ];
  const projects = [];
  const related = [];
  for (const raw of rawTargets) {
    const normalized = raw.replace(/\.md$/i, "");
    const target = byOldPath.get(normalized) || byOldPath.get(basename(normalized));
    if (!target || target === record) continue;
    const link = `[[${target.newPath.replace(/\.md$/, "")}]]`;
    const list = target.kind === "project" ? projects : related;
    if (!list.includes(link)) list.push(link);
  }
  return { projects, related };
}

function buildRecords(vault) {
  const records = [];
  for (const directory of SOURCE_DIRS) {
    for (const absolutePath of walk(join(vault, directory), vault)) {
      const oldPath = vaultPath(vault, absolutePath);
      const source = readFileSync(absolutePath, "utf8");
      const parsed = parseMarkdown(source, oldPath);
      let kind = legacyKind(parsed, oldPath);
      if (isLearning(kind, parsed)) kind = "learning";
      if (!KIND_DIR[kind]) kind = "note";
      const id = stableId(parsed.properties.id, oldPath);
      const newPath = `${KIND_DIR[kind]}/${id}.md`;
      records.push({ absolutePath, oldPath, source, beforeHash: sha256(source), parsed, kind, id, newPath });
    }
  }
  return records;
}

function atomicWrite(vault, path, content) {
  assertSafeVaultPath(vault, path);
  mkdirSync(dirname(path), { recursive: true });
  const temp = `${path}.migration-v2.tmp`;
  assertSafeVaultPath(vault, temp);
  writeFileSync(temp, content, "utf8");
  renameSync(temp, path);
}

function removeEmptyDirectories(vault, root) {
  if (!existsSync(root)) return;
  assertSafeVaultPath(vault, root, { mustExist: true });
  const rootStat = lstatSync(root);
  if (rootStat.isSymbolicLink()) throw new Error(`Migration cleanup refuses symlink: ${root}`);
  if (!rootStat.isDirectory()) return;
  for (const entry of readdirSync(root)) {
    const path = join(root, entry);
    assertSafeVaultPath(vault, path, { mustExist: true });
    const childStat = lstatSync(path);
    if (childStat.isSymbolicLink()) throw new Error(`Migration cleanup refuses symlink: ${path}`);
    if (childStat.isDirectory()) removeEmptyDirectories(vault, path);
  }
  if (!readdirSync(root).length) rmdirSync(root);
}

function updateMigrationMaps(vault, mapping) {
  const candidates = [
    "90 System/Manifests/notion-migration-manifest.json",
    "90 System/Migrations/notion-migration-manifest.json",
  ];
  for (const relativePath of candidates) {
    const path = join(vault, relativePath);
    if (!existsSync(path)) continue;
    assertSafeVaultPath(vault, path, { mustExist: true });
    const manifest = JSON.parse(readFileSync(path, "utf8"));
    for (const record of manifest.records || []) if (mapping.has(record.path)) record.path = mapping.get(record.path);
    atomicWrite(vault, path, `${JSON.stringify(manifest, null, 2)}\n`);
  }
  const sourceCandidates = [
    "90 System/Manifests/notion-source-map.json",
    "90 System/Migrations/notion-source-map.json",
  ];
  for (const relativePath of sourceCandidates) {
    const path = join(vault, relativePath);
    if (!existsSync(path)) continue;
    assertSafeVaultPath(vault, path, { mustExist: true });
    const sourceMap = JSON.parse(readFileSync(path, "utf8"));
    for (const [url, oldPath] of Object.entries(sourceMap)) if (mapping.has(oldPath)) sourceMap[url] = mapping.get(oldPath);
    atomicWrite(vault, path, `${JSON.stringify(sourceMap, null, 2)}\n`);
  }
  const moves = [
    ["90 System/Manifests/notion-migration-manifest.json", "90 System/Migrations/notion-migration-manifest.json"],
    ["90 System/Manifests/notion-source-map.json", "90 System/Migrations/notion-source-map.json"],
  ];
  for (const [from, to] of moves) {
    const source = join(vault, from);
    const destination = join(vault, to);
    if (!existsSync(source) || source === destination) continue;
    assertSafeVaultPath(vault, source, { mustExist: true });
    assertSafeVaultPath(vault, destination);
    mkdirSync(dirname(destination), { recursive: true });
    if (existsSync(destination)) throw new Error(`Migration metadata destination already exists: ${to}`);
    renameSync(source, destination);
  }
  removeEmptyDirectories(vault, join(vault, "90 System", "Manifests"));
}

function preflightApply(vault, records, manifestPath, manifestContent) {
  const conflicts = [];
  for (const record of records) {
    assertSafeVaultPath(vault, record.absolutePath, { mustExist: true });
    const destination = join(vault, record.newPath);
    assertSafeVaultPath(vault, destination);
    if (!existsSync(destination)) continue;
    const current = readFileSync(destination, "utf8");
    if (current !== record.content) conflicts.push(record.newPath);
  }
  const metadataMoves = [
    ["90 System/Manifests/notion-migration-manifest.json", "90 System/Migrations/notion-migration-manifest.json"],
    ["90 System/Manifests/notion-source-map.json", "90 System/Migrations/notion-source-map.json"],
  ];
  for (const [from, to] of metadataMoves) {
    const source = join(vault, from);
    const destination = join(vault, to);
    if (existsSync(source)) assertSafeVaultPath(vault, source, { mustExist: true });
    assertSafeVaultPath(vault, destination);
    if (existsSync(source) && existsSync(destination)) conflicts.push(`${from} -> ${to}`);
  }
  assertSafeVaultPath(vault, manifestPath);
  if (existsSync(manifestPath) && readFileSync(manifestPath, "utf8") !== manifestContent) {
    conflicts.push(vaultPath(vault, manifestPath));
  }
  if (conflicts.length) {
    throw new Error(`Migration refused before writing because destinations conflict: ${conflicts.slice(0, 10).join(", ")}`);
  }
}

function main() {
  const args = new Set(process.argv.slice(2));
  const apply = args.has("--apply");
  const vaultFlag = process.argv.indexOf("--vault");
  const vault = resolve(vaultFlag === -1 ? process.env.VAULT_CONTEXT_ROOT || "/Users/tener/obsidian" : process.argv[vaultFlag + 1]);
  const records = buildRecords(vault);
  if (apply && records.length === 0) {
    throw new Error("Migration refused: no legacy source records were found; existing manifests were left unchanged.");
  }
  const idSet = new Set();
  const pathSet = new Set();
  for (const record of records) {
    if (idSet.has(record.id)) throw new Error(`Duplicate record id: ${record.id}`);
    if (pathSet.has(record.newPath)) throw new Error(`Duplicate destination: ${record.newPath}`);
    idSet.add(record.id);
    pathSet.add(record.newPath);
  }
  const byOldPath = new Map();
  for (const record of records) {
    const noExt = record.oldPath.replace(/\.md$/i, "");
    byOldPath.set(noExt, record);
    const base = basename(noExt);
    if (!byOldPath.has(base)) byOldPath.set(base, record);
    else if (byOldPath.get(base) !== record) byOldPath.delete(base);
  }
  let envelopes = 0;
  let learnings = 0;
  let longTitles = 0;
  let missingScope = 0;
  let fallbackScopes = 0;
  const mapping = new Map();
  const migration = [];
  for (const record of records) {
    const p = record.parsed.properties;
    const cleaned = cleanConnectorEnvelope(record.parsed.body);
    cleaned.body = rewriteWikilinks(cleaned.body, byOldPath);
    if (cleaned.blankEnvelope) envelopes += 1;
    if (record.kind === "learning") learnings += 1;
    const shortened = shortenTitle(record.parsed.title);
    if (shortened.original) longTitles += 1;
    const scopes = scopeKeys(record.parsed, cleaned.body);
    const scopeFallback = !scopes.length;
    if (scopeFallback) {
      missingScope += 1;
      fallbackScopes += 1;
      scopes.push(fallbackScope(record.parsed, record.id));
    }
    const relations = resolveRelations(record, byOldPath);
    const status = statusFor(record.kind, p.status);
    const summary = deriveSummary(cleaned.body, {
      title: shortened.title,
      summary: p.summary,
      next_action: p.next_action,
    }, 320);
    const needsCuration = Boolean(cleaned.blankEnvelope || !cleaned.body || scopeFallback || p.needs_curation);
    const aliases = [...new Set([...asArray(p.aliases), ...(shortened.original ? [shortened.original] : [])])];
    const originRef = p.origin_ref || p.notion_url || null;
    const sourceDetail = p.source_detail || p.origin_source || p.source || null;
    const properties = {
      schema: SCHEMA_VERSION,
      id: record.id,
      title: shortened.title,
      kind: record.kind,
      lifecycle: lifecycleFor(record.kind, p, status),
      status,
      summary,
      priority: priorityFor(p.priority),
      pinned: Boolean(p.pinned),
      canonical: p.canonical !== false,
      needs_curation: needsCuration,
      created: p.created || p.updated || p.migration_date || todayInZone(),
      updated: p.updated || p.migration_date || todayInZone(),
      review_after: p.review_after || null,
      scope_keys: scopes,
      projects: relations.projects,
      owners: asArray(p.owners || p.owner),
      source_kind: sourceKind(sourceDetail),
      source_detail: sourceDetail,
      evidence: asArray(p.evidence || p.evidence_url).filter(Boolean),
      confidence: p.confidence || (cleaned.body ? "medium" : "low"),
      next_action: p.next_action || null,
      related: relations.related,
      aliases,
      search_terms: searchTerms(record.parsed, shortened.original),
      tags: record.parsed.tags,
      origin: p.origin || p.migrated_from || (originRef ? "notion" : "native"),
      origin_ref: originRef,
      legacy_context_key: p.context_key || p.legacy_context_key || null,
    };
    const schemaErrors = validateVaultProperties(properties);
    if (schemaErrors.length) throw new Error(`Migration schema violation for ${record.oldPath}: ${schemaErrors.join("; ")}`);
    const content = serializeMarkdown(properties, machineBody(shortened.title, summary, cleaned.body, p.next_action, needsCuration));
    record.content = content;
    record.afterHash = sha256(content);
    record.properties = properties;
    mapping.set(record.oldPath, record.newPath);
    migration.push({
      id: record.id,
      old_path: record.oldPath,
      new_path: record.newPath,
      before_sha256: record.beforeHash,
      after_sha256: record.afterHash,
      kind: record.kind,
      envelope_removed: cleaned.blankEnvelope,
      needs_curation: needsCuration,
    });
  }
  const report = {
    ok: true,
    mode: apply ? "apply" : "dry-run",
    vault,
    records: records.length,
    connector_envelopes_removed: envelopes,
    risks_reclassified_as_learning: learnings,
    long_titles_shortened: longTitles,
    missing_scope: missingScope,
    fallback_scope: fallbackScopes,
  };
  if (!apply) {
    console.log(JSON.stringify(report, null, 2));
    return;
  }
  const generatedAt = todayInZone();
  const manifestPath = join(vault, "90 System", "Migrations", `v2-migration-${generatedAt}.json`);
  const manifestContent = `${JSON.stringify({ version: 2, generated_at: generatedAt, ...report, records: migration }, null, 2)}\n`;
  preflightApply(vault, records, manifestPath, manifestContent);
  for (const record of records) atomicWrite(vault, join(vault, record.newPath), record.content);
  updateMigrationMaps(vault, mapping);
  atomicWrite(vault, manifestPath, manifestContent);
  for (const record of records) {
    if (record.oldPath === record.newPath || !existsSync(record.absolutePath)) continue;
    assertSafeVaultPath(vault, record.absolutePath, { mustExist: true });
    if (lstatSync(record.absolutePath).isSymbolicLink()) {
      throw new Error(`Migration deletion refuses symlink: ${record.absolutePath}`);
    }
    rmSync(record.absolutePath);
  }
  for (const directory of SOURCE_DIRS) removeEmptyDirectories(vault, join(vault, directory));
  console.log(JSON.stringify({ ...report, manifest: vaultPath(vault, manifestPath) }, null, 2));
}

main();
