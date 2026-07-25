import { randomUUID } from "node:crypto";
import {
  existsSync,
  lstatSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  realpathSync,
  renameSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, join, relative, resolve, sep } from "node:path";
import { tmpdir } from "node:os";
import { spawnSync } from "node:child_process";
import { deriveContextKey, tokenize } from "./context-key.mjs";
import {
  RELATION_FIELDS,
  SCHEMA_VERSION,
  asArray,
  deriveSummary,
  extractWikilinks,
  markdownPlainText,
  normalizeText,
  parseMarkdown,
  resolveVaultMarkdown,
  safeFilename,
  serializeMarkdown,
  sha256,
  timestampInZone,
  todayInZone,
  validateVaultProperties,
  vaultRelativePath,
} from "./schema.mjs";

const SKIP_DIRS = new Set([".git", ".obsidian", ".vault-context", "node_modules"]);
const INDEX_ROOTS = ["10 Records", "00 Inbox", "20 Synthesis"];
const PRIORITY_RANK = { P0: 0, P1: 1, P2: 2, P3: 3 };
const DEFAULT_EMBED_MODEL = process.env.VAULT_CONTEXT_EMBED_MODEL || "qwen3-embedding:0.6b";
const DEFAULT_SEMANTIC_MIN_SIMILARITY = 0.45;

function computeIndexFormatRevision() {
  return sha256([
    "vault-context-index/v3",
    readFileSync(new URL("./core.mjs", import.meta.url), "utf8"),
    readFileSync(new URL("./schema.mjs", import.meta.url), "utf8"),
    readFileSync(new URL("./context-key.mjs", import.meta.url), "utf8"),
    readFileSync(new URL("./benchmark.mjs", import.meta.url), "utf8"),
    readFileSync(new URL("./observability.mjs", import.meta.url), "utf8"),
    readFileSync(new URL("./server.mjs", import.meta.url), "utf8"),
    readFileSync(new URL("../schema/vault-note-v2.schema.json", import.meta.url), "utf8"),
    readFileSync(new URL("../package-lock.json", import.meta.url), "utf8"),
  ].join("\u0000"));
}

const INDEX_FORMAT_REVISION = computeIndexFormatRevision();

export function implementationIsCurrent() {
  return computeIndexFormatRevision() === INDEX_FORMAT_REVISION;
}

const CONTEXT_KINDS = new Set(["decision", "handoff", "risk", "learning", "task", "note", "question"]);
const KIND_DIRS = {
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

const SENSITIVE_PATTERNS = [
  /-----BEGIN [A-Z ]*PRIVATE KEY-----/i,
  /\b(?:proxy[-_])?authorization\s*:\s*[^\r\n]+/i,
  /(?:^|[^A-Za-z0-9_])["']?(?:[A-Z0-9]+[_-])*(?:API[_-]?KEY|CLIENT[_-]?SECRET|SECRET(?:[_-]?ACCESS)?[_-]?KEY|PRIVATE[_-]?KEY|PASSWORD|PASSWD|PASSPHRASE|ACCESS[_-]?TOKEN|REFRESH[_-]?TOKEN|TOKEN|SECRET)(?:[_-][A-Z0-9]+)*["']?\s*[:=]\s*["']?\S+/im,
  /(?:^|\s)--(?:[a-z0-9]+[-_])*(?:api[-_]?key|client[-_]?secret|secret|password|passwd|passphrase|token)(?:[-_][a-z0-9]+)*(?:\s+|=)["']?\S+/im,
  /(?:api[_-]?key|secret|password|passwd|token|bearer)\s*[:=]\s*\S+/i,
  /\bsk-[A-Za-z0-9_-]{12,}\b/,
  /\b(?:sk|rk)_(?:live|test)_[A-Za-z0-9]{16,}\b/,
  /\bgh[pousr]_[A-Za-z0-9_]{20,}\b/,
  /\bglpat-[A-Za-z0-9_-]{16,}\b/,
  /\bnpm_[A-Za-z0-9]{20,}\b/,
  /\bAIza[A-Za-z0-9_-]{30,}\b/,
  /\bxox[baprs]-[A-Za-z0-9-]{20,}\b/,
  /\bSG\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}\b/,
  /\b(?:hf|shpat|shpca|shppa|shpss)_[A-Za-z0-9]{20,}\b/,
  /\bdop_v1_[A-Fa-f0-9]{32,}\b/,
  /\bSK[A-Fa-f0-9]{32}\b/,
  /\bAKIA[0-9A-Z]{16}\b/,
  /\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b/,
  /\b(?:https?|postgres(?:ql)?|mysql|mongodb(?:\+srv)?|redis|amqps?):\/\/[^/\s:@]+:[^@\s]+@/i,
  /\b(?:SharedAccessSignature|SharedAccessKey)\s*=\s*\S+/i,
  /(?:^|[?&;\s])sig=[A-Za-z0-9%/+_-]{16,}(?:&|$)/im,
  /\b(?:cookie|set-cookie)\s*:\s*[^\r\n]+/i,
];
const SENSITIVE_KEY_PATTERN = /^(?:[A-Z0-9]+[_-])*(?:API[_-]?KEY|CLIENT[_-]?SECRET|SECRET(?:[_-]?ACCESS)?[_-]?KEY|PRIVATE[_-]?KEY|PASSWORD|PASSWD|PASSPHRASE|ACCESS[_-]?TOKEN|REFRESH[_-]?TOKEN|TOKEN|SECRET)(?:[_-][A-Z0-9]+)*$/i;
const SAFE_REFERENCE_KEY_PATTERN = /^(?:commit(?:_?sha)?|fix_?commit|occurrence_?id|pattern_?key|review_?comment_?id|ci_?run_?id)$/i;

const RAW_HASH_PATTERN = /^[a-f0-9]{64}$/;
const CONTEXT_RELATION_FIELDS = RELATION_FIELDS.filter((field) => !["projects", "source_raw", "outputs"].includes(field));
const QUERY_SYNONYMS = [
  [/(?:コンテクスト|文脈)/u, ["context"]],
  [/(?:読み込|取得)/u, ["load", "retrieve", "retrieval"]],
  [/(?:検索)/u, ["search"]],
  [/(?:インデックス|索引)/u, ["index"]],
  [/(?:テスト|試験)/u, ["test"]],
  [/(?:対象)/u, ["target"]],
  [/(?:確認|検証)/u, ["verify", "check", "validation"]],
  [/(?:スキャナ)/u, ["scanner"]],
];

export function loadConfig() {
  const vaultRoot = resolve(process.env.VAULT_CONTEXT_ROOT || "/Users/tener/obsidian");
  const indexPath = resolve(process.env.VAULT_CONTEXT_INDEX || join(vaultRoot, ".vault-context", "index.sqlite"));
  const observabilityPath = resolve(
    process.env.VAULT_CONTEXT_OBSERVABILITY || join(vaultRoot, ".vault-context", "observability.sqlite"),
  );
  return { vaultRoot, indexPath, observabilityPath, vaultName: basename(vaultRoot) };
}

function sqlString(value) {
  if (value === null || value === undefined) return "NULL";
  return `'${String(value).replaceAll("'", "''")}'`;
}

function sqlBlob(buffer) {
  return `X'${Buffer.from(buffer).toString("hex")}'`;
}

function runSqlite(indexPath, sql, { json = false } = {}) {
  mkdirSync(dirname(indexPath), { recursive: true });
  const args = json ? ["-json", indexPath, sql] : [indexPath];
  const result = json
    ? spawnSync("sqlite3", args, { encoding: "utf8", maxBuffer: 64 * 1024 * 1024, timeout: 30_000 })
    : spawnSync("sqlite3", args, { input: sql, encoding: "utf8", maxBuffer: 64 * 1024 * 1024, timeout: 30_000 });
  if (result.error) throw new Error(`sqlite3 failed: ${result.error.message}`);
  if (result.status !== 0) throw new Error((result.stderr || result.stdout || "sqlite3 failed").trim());
  return result.stdout || "";
}

function createSchema(indexPath) {
  runSqlite(indexPath, `
PRAGMA journal_mode=DELETE;
PRAGMA synchronous=NORMAL;
CREATE TABLE IF NOT EXISTS notes (
  path TEXT PRIMARY KEY,
  id TEXT,
  title TEXT NOT NULL,
  summary TEXT,
  schema_name TEXT,
  kind TEXT,
  lifecycle TEXT,
  status TEXT,
  priority TEXT,
  pinned INTEGER NOT NULL DEFAULT 0,
  canonical INTEGER NOT NULL DEFAULT 1,
  needs_curation INTEGER NOT NULL DEFAULT 0,
  context_key TEXT,
  next_action TEXT,
  source_kind TEXT,
  source_detail TEXT,
  confidence TEXT,
  evidence_json TEXT,
  origin TEXT,
  origin_ref TEXT,
  created TEXT,
  updated TEXT,
  review_after TEXT,
  captured_at TEXT,
  processed_at TEXT,
  immutable INTEGER NOT NULL DEFAULT 0,
  body_sha256 TEXT,
  raw_integrity_sha256 TEXT,
  sensitive_suspected INTEGER NOT NULL DEFAULT 0,
  frontmatter_error TEXT,
  validation_errors_json TEXT,
  tags_json TEXT,
  aliases_json TEXT,
  search_terms_json TEXT,
  scope_keys_json TEXT,
  projects_json TEXT,
  source_raw_json TEXT,
  links_json TEXT,
  body TEXT,
  search_text TEXT,
  content_sha256 TEXT NOT NULL,
  mtime_ms INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_notes_kind_status ON notes(kind, lifecycle, status);
CREATE INDEX IF NOT EXISTS idx_notes_priority ON notes(priority);
CREATE INDEX IF NOT EXISTS idx_notes_pinned ON notes(pinned, lifecycle);
CREATE INDEX IF NOT EXISTS idx_notes_review_after ON notes(review_after);
CREATE INDEX IF NOT EXISTS idx_notes_context_key ON notes(context_key);
CREATE TABLE IF NOT EXISTS edges (
  source_path TEXT NOT NULL,
  target_raw TEXT NOT NULL,
  target_path TEXT,
  kind TEXT NOT NULL,
  PRIMARY KEY (source_path, target_raw, kind)
);
CREATE INDEX IF NOT EXISTS idx_edges_target ON edges(target_path, target_raw);
CREATE INDEX IF NOT EXISTS idx_edges_source ON edges(source_path);
CREATE TABLE IF NOT EXISTS facets (
  path TEXT NOT NULL,
  kind TEXT NOT NULL,
  value TEXT NOT NULL,
  PRIMARY KEY (path, kind, value)
);
CREATE INDEX IF NOT EXISTS idx_facets_lookup ON facets(kind, value, path);
CREATE TABLE IF NOT EXISTS embeddings (
  path TEXT NOT NULL,
  model TEXT NOT NULL,
  dimensions INTEGER NOT NULL,
  vector BLOB NOT NULL,
  source_hash TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (path, model)
);
CREATE TABLE IF NOT EXISTS chunks (
  path TEXT NOT NULL,
  chunk_id TEXT NOT NULL,
  heading TEXT,
  ordinal INTEGER NOT NULL,
  text TEXT NOT NULL,
  content_sha256 TEXT NOT NULL,
  embedding_source_sha256 TEXT NOT NULL,
  PRIMARY KEY (path, chunk_id)
);
CREATE INDEX IF NOT EXISTS idx_chunks_path ON chunks(path, ordinal);
CREATE TABLE IF NOT EXISTS chunk_embeddings (
  path TEXT NOT NULL,
  chunk_id TEXT NOT NULL,
  model TEXT NOT NULL,
  dimensions INTEGER NOT NULL,
  vector BLOB NOT NULL,
  source_hash TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (path, chunk_id, model)
);
CREATE TABLE IF NOT EXISTS index_meta (key TEXT PRIMARY KEY, value TEXT);
CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
  path UNINDEXED,
  title,
  summary,
  context_key,
  next_action,
  tags,
  aliases,
  search_terms,
  body,
  tokenize='trigram'
);
CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(
  path UNINDEXED,
  chunk_id UNINDEXED,
  heading,
  text,
  tokenize='trigram'
);
`);
}

function splitLongChunk(heading, text, startingOrdinal) {
  const paragraphs = String(text || "").split(/\n{2,}/).map((part) => part.trim()).filter(Boolean);
  const chunks = [];
  let buffer = "";
  const flush = () => {
    if (!buffer.trim()) return;
    const ordinal = startingOrdinal + chunks.length;
    const content = buffer.trim();
    chunks.push({
      chunk_id: `${String(ordinal).padStart(4, "0")}-${sha256(`${heading}\n${content}`).slice(0, 10)}`,
      heading,
      ordinal,
      text: content,
      content_sha256: sha256(content),
    });
    buffer = "";
  };
  for (const paragraph of paragraphs.length ? paragraphs : [String(text || "")]) {
    if (buffer && buffer.length + paragraph.length + 2 > 1800) flush();
    if (paragraph.length <= 1800) {
      buffer = buffer ? `${buffer}\n\n${paragraph}` : paragraph;
      continue;
    }
    flush();
    for (let index = 0; index < paragraph.length; index += 1700) {
      buffer = paragraph.slice(index, index + 1800);
      flush();
    }
  }
  flush();
  return chunks;
}

function markdownChunks(body, summary) {
  const sections = [];
  if (String(summary || "").trim()) sections.push({ heading: "Summary", text: String(summary).trim() });
  let heading = "Content";
  let lines = [];
  const flush = () => {
    const text = lines.join("\n").trim();
    if (text) sections.push({ heading, text });
    lines = [];
  };
  for (const line of String(body || "").split("\n")) {
    const match = line.match(/^#{1,4}\s+(.+)$/);
    if (match) {
      flush();
      heading = match[1].trim();
    } else lines.push(line);
  }
  flush();
  const chunks = [];
  const normalizedSummary = normalizeText(summary);
  let indexedSummary = false;
  for (const section of sections) {
    const isCanonicalSummary = (
      normalizeText(section.heading) === "summary"
      && normalizedSummary
      && normalizeText(markdownPlainText(section.text)) === normalizeText(markdownPlainText(summary))
    );
    if (isCanonicalSummary && indexedSummary) continue;
    if (isCanonicalSummary) indexedSummary = true;
    chunks.push(...splitLongChunk(section.heading, section.text, chunks.length));
  }
  return chunks;
}

function rawIntegrityHash(source) {
  const exact = String(source || "");
  const frontmatter = exact.match(/^(---(?:\r\n|\n))([\s\S]*?)((?:\r\n|\n)---(?:(?:\r\n|\n)|$))/);
  if (!frontmatter) return sha256(exact);
  const withoutSelfHash = frontmatter[2].replace(
    /(^|(?:\r\n|\n))body_sha256:[^\r\n]*(?:(?:\r\n|\n)|$)/m,
    "$1",
  );
  return sha256(`${frontmatter[1]}${withoutSelfHash}${frontmatter[3]}${exact.slice(frontmatter[0].length)}`);
}

function walkMarkdown(root) {
  const files = [];
  const rootPath = resolve(root);
  const rootReal = existsSync(rootPath) ? realpathSync(rootPath) : rootPath;
  const assertInsideRoot = (path) => {
    const real = realpathSync(path);
    if (real !== rootReal && !real.startsWith(`${rootReal}${sep}`)) {
      throw new Error(`Indexed path escapes the configured vault through a symlink: ${path}`);
    }
  };
  function walk(dir) {
    assertInsideRoot(dir);
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      if (entry.isSymbolicLink?.()) continue;
      if (entry.isDirectory()) {
        if (!SKIP_DIRS.has(entry.name)) {
          const child = join(dir, entry.name);
          assertInsideRoot(child);
          walk(child);
        }
      } else if (entry.isFile() && entry.name.toLowerCase().endsWith(".md")) {
        const file = join(dir, entry.name);
        assertInsideRoot(file);
        files.push(file);
      }
    }
  }
  for (const relativeRoot of INDEX_ROOTS) {
    const candidate = join(rootPath, relativeRoot);
    if (!existsSync(candidate)) continue;
    if (lstatSync(candidate).isSymbolicLink()) {
      throw new Error(`Indexed root must not be a symlink: ${candidate}`);
    }
    if (!lstatSync(candidate).isDirectory()) {
      throw new Error(`Indexed root must be a directory: ${candidate}`);
    }
    assertInsideRoot(candidate);
    walk(candidate);
  }
  return files.sort();
}

function toVaultPath(vaultRoot, absolutePath) {
  return relative(vaultRoot, absolutePath).split(sep).join("/");
}

function legacyKind(properties, path) {
  if (properties.kind) return String(properties.kind).toLowerCase();
  if (properties.record_kind === "context-item") return String(properties.type || "note").toLowerCase();
  if (properties.record_kind) return String(properties.record_kind).toLowerCase();
  if (path.startsWith("00 Inbox/raw/")) return "raw";
  if (path.startsWith("00 Inbox/receipts/")) return "receipt";
  if (path.includes("/Daily/")) return "daily";
  if (path.includes("/Weekly/")) return "weekly";
  return "note";
}

function legacyLifecycle(properties) {
  if (properties.lifecycle) return String(properties.lifecycle);
  if (properties.archived === true) return "archived";
  return "active";
}

const INDEXED_KINDS = new Set([
  ...CONTEXT_KINDS,
  "project",
  "runbook",
  "raw",
  "receipt",
  "daily",
  "weekly",
]);

function quarantinedKindFromPath(path) {
  if (path.startsWith("00 Inbox/raw/")) return "raw";
  if (path.startsWith("00 Inbox/receipts/")) return "receipt";
  const recordKind = path.match(/^10 Records\/([^/]+)\//)?.[1];
  if (recordKind && INDEXED_KINDS.has(recordKind)) return recordKind;
  if (path.startsWith("20 Synthesis/daily/")) return "daily";
  if (path.startsWith("20 Synthesis/weekly/")) return "weekly";
  return "note";
}

function validateNoteProperties(properties, path, kind, frontmatterError) {
  const errors = validateVaultProperties(properties);
  if (frontmatterError) errors.push(`frontmatter: ${frontmatterError}`);
  if (!INDEXED_KINDS.has(kind)) errors.push(`unsupported kind: ${kind}`);
  if (path.startsWith("10 Records/")) {
    const expected = `10 Records/${kind}/${properties.id}.md`;
    if (path !== expected) errors.push(`canonical path must be ${expected}`);
    if (!["P0", "P1", "P2", "P3"].includes(String(properties.priority || ""))) errors.push("priority must be P0, P1, P2, or P3");
    if (!asArray(properties.scope_keys).length && !asArray(properties.projects).length) errors.push("record requires scope_keys or projects");
  }
  if (kind === "raw") {
    if (properties.immutable !== true) errors.push("raw must be immutable");
    if (!properties.body_sha256) errors.push("raw requires body_sha256");
  }
  return [...new Set(errors)];
}

function noteRow(vaultRoot, absolutePath) {
  const path = toVaultPath(vaultRoot, absolutePath);
  const source = readFileSync(absolutePath, "utf8");
  const parsed = parseMarkdown(source, path);
  const p = parsed.properties;
  const sensitive = suspectedSensitive(source);
  const kind = sensitive ? quarantinedKindFromPath(path) : legacyKind(p, path);
  // Quarantine is represented by its own fixed boolean. Parser/schema details
  // are intentionally discarded because pretty YAML errors can echo secrets.
  const validationErrors = sensitive ? [] : validateNoteProperties(p, path, kind, parsed.frontmatterError);
  const summary = sensitive ? "[redacted: sensitive content suspected]" : String(p.summary || parsed.summary || "").trim();
  const evidence = sensitive ? [] : asArray(p.evidence || p.evidence_url).filter(Boolean);
  const scopeKeys = sensitive ? [] : asArray(p.scope_keys || p.context_key).filter(Boolean);
  const legacyContextKey = sensitive ? null : p.legacy_context_key || p.context_key || null;
  const storedBody = sensitive ? "" : parsed.body;
  const storedTitle = sensitive ? "[sensitive note quarantined]" : parsed.title;
  const storedTags = sensitive ? [] : parsed.tags;
  const storedAliases = sensitive ? [] : parsed.aliases;
  const storedSearchTerms = sensitive ? [] : parsed.searchTerms;
  const storedProjects = sensitive ? [] : parsed.projects;
  const storedSourceRaw = sensitive ? [] : parsed.sourceRaw;
  const storedLinks = sensitive ? [] : parsed.links;
  const searchText = [
    storedTitle,
    summary,
    legacyContextKey,
    sensitive ? null : p.next_action,
    ...storedTags,
    ...storedAliases,
    ...storedSearchTerms,
    ...scopeKeys,
    ...storedProjects,
    markdownPlainText(storedBody),
  ].filter(Boolean).join("\n");
  const row = {
    path,
    id: sensitive ? null : p.id || null,
    title: storedTitle,
    summary,
    schema_name: sensitive ? null : p.schema || null,
    kind,
    lifecycle: sensitive ? "active" : legacyLifecycle(p),
    status: sensitive ? null : p.status || null,
    priority: sensitive ? null : p.priority || null,
    pinned: sensitive ? 0 : p.pinned === true ? 1 : 0,
    canonical: sensitive ? 0 : p.canonical === false ? 0 : 1,
    needs_curation: sensitive ? 0 : p.needs_curation === true ? 1 : 0,
    context_key: legacyContextKey || scopeKeys.join(" ") || null,
    next_action: sensitive ? null : p.next_action || null,
    source_kind: sensitive ? null : p.source_kind || p.origin_source || p.source || null,
    source_detail: sensitive ? null : p.source_detail || null,
    confidence: sensitive ? null : p.confidence || null,
    evidence_json: JSON.stringify(evidence),
    origin: sensitive ? null : p.origin || p.migrated_from || null,
    origin_ref: sensitive ? null : p.origin_ref || p.notion_url || null,
    created: sensitive ? null : p.created || null,
    updated: sensitive ? null : p.updated || p.migration_date || null,
    review_after: sensitive ? null : p.review_after || null,
    captured_at: sensitive ? null : p.captured_at || null,
    processed_at: sensitive ? null : p.processed_at || null,
    immutable: sensitive ? 0 : p.immutable === true ? 1 : 0,
    body_sha256: sensitive ? null : p.body_sha256 || null,
    raw_integrity_sha256: kind === "raw" ? rawIntegrityHash(source) : null,
    sensitive_suspected: sensitive ? 1 : 0,
    frontmatter_error: sensitive ? null : parsed.frontmatterError || null,
    validation_errors_json: JSON.stringify(validationErrors),
    tags_json: JSON.stringify(storedTags),
    aliases_json: JSON.stringify(storedAliases),
    search_terms_json: JSON.stringify(storedSearchTerms),
    scope_keys_json: JSON.stringify(scopeKeys),
    projects_json: JSON.stringify(storedProjects),
    source_raw_json: JSON.stringify(storedSourceRaw),
    links_json: JSON.stringify(storedLinks),
    body: storedBody,
    search_text: searchText,
    content_sha256: sha256(source),
    mtime_ms: Math.trunc(statSync(absolutePath).mtimeMs),
    edges: sensitive ? [] : parsed.edges,
    chunks: sensitive ? [] : markdownChunks(parsed.body, summary),
  };
  row.chunks = row.chunks.map((chunk) => ({
    ...chunk,
    embedding_source_sha256: sha256(embeddingInput({ ...row, ...chunk })),
  }));
  return row;
}

function fingerprint(files, root) {
  return sha256(files.map((path) => {
    const stat = statSync(path);
    return `${toVaultPath(root, path)}\u0000${stat.dev}\u0000${stat.ino}\u0000${stat.size}\u0000${stat.mtimeMs}\u0000${stat.ctimeMs}`;
  }).join("\n"));
}

function waitMilliseconds(milliseconds) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, milliseconds);
}

function assertSafeIndexPath(config) {
  const vaultRoot = resolve(config.vaultRoot);
  const indexPath = resolve(config.indexPath);
  const indexRelative = relative(vaultRoot, indexPath);
  if (!indexRelative || indexRelative === ".." || indexRelative.startsWith(`..${sep}`)) {
    throw new Error("Vault index path must stay inside the configured vault");
  }
  if (!existsSync(vaultRoot)) throw new Error("Configured vault root does not exist");
  const rootReal = realpathSync(vaultRoot);
  if (!statSync(rootReal).isDirectory()) throw new Error("Configured vault root is not a directory");

  let cursor = vaultRoot;
  const components = indexRelative.split(sep);
  for (let index = 0; index < components.length; index += 1) {
    const component = components[index];
    cursor = join(cursor, component);
    let metadata;
    try {
      metadata = lstatSync(cursor);
    } catch (error) {
      if (error.code === "ENOENT") break;
      throw error;
    }
    if (metadata.isSymbolicLink()) {
      throw new Error("Vault index path must not contain a symlink");
    }
    const isIndexFile = index === components.length - 1;
    if (!isIndexFile && !metadata.isDirectory()) {
      throw new Error("Vault index ancestor must be a directory");
    }
    if (isIndexFile && !metadata.isFile()) {
      throw new Error("Vault index path must be a regular file");
    }
    const cursorReal = realpathSync(cursor);
    const realRelative = relative(rootReal, cursorReal);
    if (realRelative === ".." || realRelative.startsWith(`..${sep}`)) {
      throw new Error("Vault index path escapes the configured vault");
    }
  }
  return indexPath;
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
      if (Date.now() - started >= timeoutMs) throw new Error("Timed out waiting for the Vault index lock");
      waitMilliseconds(50);
    }
  }
}

function acquireIndexLock(config, timeoutMs = 5000) {
  assertSafeIndexPath(config);
  return acquireDirectoryLock(`${config.indexPath}.lock`, timeoutMs);
}

function pathResolution(rows) {
  const exact = new Map();
  const bases = new Map();
  for (const row of rows) {
    const noExt = row.path.replace(/\.md$/i, "");
    exact.set(noExt, row.path);
    const base = basename(noExt);
    if (!bases.has(base)) bases.set(base, []);
    bases.get(base).push(row.path);
  }
  return (raw) => {
    const clean = String(raw || "").replace(/\.md$/i, "");
    if (exact.has(clean)) return exact.get(clean);
    const matches = bases.get(basename(clean)) || [];
    return matches.length === 1 ? matches[0] : null;
  };
}

export function reindex(config = loadConfig()) {
  const release = acquireIndexLock(config);
  const tempRoot = mkdtempSync(join(tmpdir(), "vault-context-index-"));
  const nextIndex = join(tempRoot, "index.sqlite");
  try {
    const files = walkMarkdown(config.vaultRoot);
    const rows = files.map((path) => noteRow(config.vaultRoot, path));
    const resolveTarget = pathResolution(rows);
    createSchema(nextIndex);
    const columns = [
      "path", "id", "title", "summary", "schema_name", "kind", "lifecycle", "status", "priority", "pinned",
      "canonical", "needs_curation", "context_key", "next_action", "source_kind", "source_detail", "confidence",
      "evidence_json", "origin", "origin_ref", "created", "updated", "review_after", "captured_at", "processed_at",
      "immutable", "body_sha256", "raw_integrity_sha256", "sensitive_suspected", "frontmatter_error", "validation_errors_json", "tags_json", "aliases_json", "search_terms_json", "scope_keys_json", "projects_json",
      "source_raw_json", "links_json", "body", "search_text", "content_sha256", "mtime_ms",
    ];
    const statements = ["BEGIN;"];
    for (const row of rows) {
      statements.push(`INSERT INTO notes (${columns.join(",")}) VALUES (${columns.map((key) => sqlString(row[key])).join(",")});`);
      statements.push(`INSERT INTO notes_fts(path,title,summary,context_key,next_action,tags,aliases,search_terms,body) VALUES (${[
        row.path, row.title, row.summary, row.context_key, row.next_action, row.tags_json, row.aliases_json,
        row.search_terms_json, row.body,
      ].map(sqlString).join(",")});`);
      for (const edge of row.edges) {
        statements.push(`INSERT OR IGNORE INTO edges(source_path,target_raw,target_path,kind) VALUES (${sqlString(row.path)},${sqlString(edge.target)},${sqlString(resolveTarget(edge.target))},${sqlString(edge.kind)});`);
      }
      for (const [facetKind, values] of [
        ["scope", jsonArray(row.scope_keys_json)],
        ["project", jsonArray(row.projects_json)],
        ["tag", jsonArray(row.tags_json)],
      ]) {
        for (const value of values) statements.push(`INSERT OR IGNORE INTO facets(path,kind,value) VALUES (${sqlString(row.path)},${sqlString(facetKind)},${sqlString(value)});`);
      }
      for (const chunk of row.chunks) {
        statements.push(`INSERT INTO chunks(path,chunk_id,heading,ordinal,text,content_sha256,embedding_source_sha256) VALUES (${sqlString(row.path)},${sqlString(chunk.chunk_id)},${sqlString(chunk.heading)},${chunk.ordinal},${sqlString(chunk.text)},${sqlString(chunk.content_sha256)},${sqlString(chunk.embedding_source_sha256)});`);
        statements.push(`INSERT INTO chunks_fts(path,chunk_id,heading,text) VALUES (${sqlString(row.path)},${sqlString(chunk.chunk_id)},${sqlString(chunk.heading)},${sqlString(chunk.text)});`);
      }
    }
    const indexedAt = Date.now();
    const meta = {
      indexed_at_ms: indexedAt,
      note_count: rows.length,
      fingerprint: fingerprint(files, config.vaultRoot),
      schema_version: 2,
      index_format_revision: INDEX_FORMAT_REVISION,
      frontmatter_errors: rows.filter((row) => row.frontmatter_error).length,
      schema_violations: rows.filter((row) => jsonArray(row.validation_errors_json).length).length,
    };
    for (const [key, value] of Object.entries(meta)) {
      statements.push(`INSERT OR REPLACE INTO index_meta(key,value) VALUES (${sqlString(key)},${sqlString(value)});`);
    }
    statements.push("COMMIT;");
    const sqlPath = join(tempRoot, "reindex.sql");
    writeFileSync(sqlPath, statements.join("\n"), "utf8");
    runSqlite(nextIndex, `.read ${sqlPath}\n`);
    assertSafeIndexPath(config);
    if (existsSync(config.indexPath)) {
      try {
        const hasChunkEmbeddings = runSqlite(config.indexPath, "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='chunk_embeddings'").trim() === "1";
        if (hasChunkEmbeddings) {
          runSqlite(nextIndex, `ATTACH DATABASE ${sqlString(config.indexPath)} AS old_index;
INSERT OR IGNORE INTO chunk_embeddings(path,chunk_id,model,dimensions,vector,source_hash,updated_at)
SELECT e.path,e.chunk_id,e.model,e.dimensions,e.vector,e.source_hash,e.updated_at
FROM old_index.chunk_embeddings e JOIN chunks c ON c.path=e.path AND c.chunk_id=e.chunk_id AND c.embedding_source_sha256=e.source_hash;
DETACH DATABASE old_index;`);
        }
      } catch {
        // Embeddings are an optional, disposable cache.
      }
    }
    assertSafeIndexPath(config);
    mkdirSync(dirname(config.indexPath), { recursive: true });
    assertSafeIndexPath(config);
    renameSync(nextIndex, config.indexPath);
    return {
      ok: true,
      vault: config.vaultRoot,
      index: config.indexPath,
      index_format_revision: INDEX_FORMAT_REVISION,
      notes: rows.length,
      edges: rows.reduce((sum, row) => sum + row.edges.length, 0),
      frontmatter_errors: meta.frontmatter_errors,
      schema_violations: meta.schema_violations,
    };
  } finally {
    rmSync(tempRoot, { recursive: true, force: true });
    release();
  }
}

function readMeta(config) {
  assertSafeIndexPath(config);
  if (!existsSync(config.indexPath)) return {};
  try {
    const output = runSqlite(config.indexPath, "SELECT key,value FROM index_meta", { json: true }).trim();
    const rows = output ? JSON.parse(output) : [];
    return Object.fromEntries(rows.map((row) => [row.key, row.value]));
  } catch {
    return {};
  }
}

export function ensureFreshIndex(config = loadConfig()) {
  const files = walkMarkdown(config.vaultRoot);
  const current = readMeta(config);
  const nextFingerprint = fingerprint(files, config.vaultRoot);
  if (
    !existsSync(config.indexPath)
    || current.fingerprint !== nextFingerprint
    || current.index_format_revision !== INDEX_FORMAT_REVISION
  ) return reindex(config);
  return { ok: true, fresh: true, notes: files.length, index: config.indexPath };
}

function queryRows(config, sql) {
  if (!config.indexAlreadyFresh) ensureFreshIndex(config);
  assertSafeIndexPath(config);
  const output = runSqlite(config.indexPath, sql, { json: true }).trim();
  return output ? JSON.parse(output) : [];
}

function freshIndexConfig(config) {
  if (config.indexAlreadyFresh) return config;
  ensureFreshIndex(config);
  return { ...config, indexAlreadyFresh: true };
}

function obsidianUrl(config, path) {
  return `obsidian://open?vault=${encodeURIComponent(config.vaultName)}&file=${encodeURIComponent(path.replace(/\.md$/, ""))}`;
}

function jsonArray(value) {
  try {
    return value ? JSON.parse(value) : [];
  } catch {
    return [];
  }
}

function rowSummary(config, row) {
  if (Boolean(row.sensitive_suspected)) {
    return {
      path: row.path,
      url: obsidianUrl(config, row.path),
      title: "[sensitive note quarantined]",
      summary: "[redacted: sensitive content suspected]",
      kind: row.kind,
      lifecycle: row.lifecycle,
      canonical: Boolean(row.canonical),
      sensitive_suspected: true,
      validation_errors: jsonArray(row.validation_errors_json),
    };
  }
  return {
    id: row.id,
    path: row.path,
    url: obsidianUrl(config, row.path),
    title: row.title,
    summary: row.summary,
    schema: row.schema_name,
    kind: row.kind,
    lifecycle: row.lifecycle,
    status: row.status,
    priority: row.priority,
    pinned: Boolean(row.pinned),
    canonical: Boolean(row.canonical),
    needs_curation: Boolean(row.needs_curation),
    context_key: row.context_key,
    next_action: row.next_action,
    evidence: jsonArray(row.evidence_json),
    updated: row.updated,
    review_after: row.review_after,
    confidence: row.confidence,
    source_kind: row.source_kind,
    origin: row.origin,
    origin_ref: row.origin_ref,
    tags: jsonArray(row.tags_json),
    aliases: jsonArray(row.aliases_json),
    search_terms: jsonArray(row.search_terms_json),
    scope_keys: jsonArray(row.scope_keys_json),
    projects: jsonArray(row.projects_json),
    links: jsonArray(row.links_json),
    sensitive_suspected: false,
    validation_errors: jsonArray(row.validation_errors_json),
  };
}

const SUMMARY_COLUMNS = `id,path,title,summary,schema_name,kind,lifecycle,status,priority,pinned,canonical,needs_curation,context_key,next_action,source_kind,confidence,evidence_json,origin,origin_ref,updated,review_after,tags_json,aliases_json,search_terms_json,scope_keys_json,projects_json,links_json,sensitive_suspected,validation_errors_json`;
const SUMMARY_COLUMNS_N = SUMMARY_COLUMNS.split(",").map((column) => `n.${column} AS ${column}`).join(",");

function activeSql(includeArchived = false) {
  return includeArchived ? "1=1" : "lifecycle!='archived'";
}

function retrievalEligibilitySql(alias = "", options = {}) {
  const prefix = alias ? `${alias}.` : "";
  const clauses = [`${prefix}sensitive_suspected=0`];
  if (!options.includeInvalid) clauses.push(`${prefix}validation_errors_json='[]'`);
  if (!options.includeNoncanonical) clauses.push(`${prefix}canonical=1`);
  return clauses.join(" AND ");
}

export function startup({ limit = 8 } = {}, config = loadConfig()) {
  const safeLimit = Math.min(Math.max(Number(limit) || 8, 1), 50);
  const rows = queryRows(config, `SELECT ${SUMMARY_COLUMNS} FROM notes WHERE pinned=1 AND lifecycle!='archived' AND ${retrievalEligibilitySql()} AND kind NOT IN ('template','raw','receipt','daily','weekly') ORDER BY CASE priority WHEN 'P0' THEN 0 WHEN 'P1' THEN 1 WHEN 'P2' THEN 2 ELSE 3 END, updated DESC, title LIMIT ${safeLimit}`);
  return { results: rows.map((row) => rowSummary(config, row)) };
}

function queryUnits(query) {
  const normalized = normalizeText(query);
  const words = [...new Set((normalized.match(/[\p{L}\p{N}._/-]+/gu) || []).filter((word) => /[\p{L}\p{N}]/u.test(word)))];
  const selectedWords = words.length <= 64
    ? words
    : [...words.slice(0, 24), ...words.slice(-32), ...words.filter((word) => /[._/-]|\d/u.test(word)).slice(0, 16)];
  const units = new Set();
  if (normalized.length <= 240) units.add(normalized);
  for (const word of selectedWords) units.add(word);
  for (const [pattern, synonyms] of QUERY_SYNONYMS) {
    if (pattern.test(normalized)) for (const synonym of synonyms) units.add(synonym);
  }
  const gramBudget = 64;
  let gramsAdded = 0;
  for (const word of selectedWords) {
    if (/[^\x00-\x7F]/.test(word) && word.length > 4) {
      for (let size = 2; size <= 4; size += 1) {
        const available = word.length - size + 1;
        const sampleCount = Math.min(12, available);
        for (let sample = 0; sample < sampleCount && gramsAdded < gramBudget; sample += 1) {
          const index = sampleCount === 1 ? 0 : Math.round((sample * (available - 1)) / (sampleCount - 1));
          const gram = word.slice(index, index + size);
          if (!units.has(gram)) {
            units.add(gram);
            gramsAdded += 1;
          }
        }
      }
    }
    if (gramsAdded >= gramBudget) break;
  }
  return [...units].filter((unit) => unit.length >= 2).slice(0, 128);
}

function grams(value, size = 3) {
  const normalized = normalizeText(value).replace(/\s+/g, "");
  if (normalized.length < size) return new Set(normalized ? [normalized] : []);
  const output = new Set();
  for (let index = 0; index <= normalized.length - size; index += 1) output.add(normalized.slice(index, index + size));
  return output;
}

function dice(left, right) {
  if (!left.size || !right.size) return 0;
  let overlap = 0;
  for (const value of left) if (right.has(value)) overlap += 1;
  return (2 * overlap) / (left.size + right.size);
}

function fieldScore(field, query, units, exactWeight, unitWeight) {
  const text = normalizeText(field);
  if (!text) return { score: 0, exact: false, matches: 0 };
  let score = 0;
  const exact = text.includes(query);
  if (exact) score += exactWeight;
  const matchedFactors = [];
  for (const unit of units) {
    if (text.includes(unit)) {
      matchedFactors.push(Math.min(1.6, Math.max(0.5, unit.length / 4)));
    }
  }
  matchedFactors.sort((left, right) => right - left);
  score += unitWeight * matchedFactors.slice(0, 8).reduce((sum, value) => sum + value, 0);
  return { score, exact, matches: matchedFactors.length };
}

function makeSnippet(body, query, units, limit = 240) {
  const plain = markdownPlainText(body);
  const normalized = normalizeText(plain);
  const needles = [query, ...units].filter(Boolean);
  let at = -1;
  for (const needle of needles) {
    const found = normalized.indexOf(needle);
    if (found !== -1 && (at === -1 || found < at)) at = found;
  }
  if (at === -1) return plain.slice(0, limit) + (plain.length > limit ? "…" : "");
  const start = Math.max(0, at - Math.floor(limit * 0.35));
  const text = plain.slice(start, start + limit);
  return `${start ? "…" : ""}${text}${start + limit < plain.length ? "…" : ""}`;
}

function rankChunks(query, units, options, config) {
  const filters = [activeSql(options.includeArchived).replaceAll("lifecycle", "n.lifecycle"), "n.kind!='template'", retrievalEligibilitySql("n", options)];
  if (!options.includeRaw) filters.push("n.kind NOT IN ('raw','receipt')");
  if (options.kind || options.type) filters.push(`n.kind=${sqlString(options.kind || options.type)}`);
  if (options.status) filters.push(`n.status=${sqlString(options.status)}`);
  if (options.project) filters.push(`n.projects_json LIKE ${sqlString(`%${options.project}%`)}`);
  if (options.contextKey) filters.push(`(n.context_key LIKE ${sqlString(`%${options.contextKey}%`)} OR n.scope_keys_json LIKE ${sqlString(`%${options.contextKey}%`)})`);
  const rows = queryRows(config, `SELECT c.path,c.chunk_id,c.heading,c.ordinal,c.text,n.id,n.title,n.summary,n.kind,n.status,n.priority,n.updated FROM chunks c JOIN notes n ON n.path=c.path WHERE ${filters.join(" AND ")}`);
  return rows.map((row) => {
    const heading = fieldScore(row.heading, query, units, 55, 12);
    const text = fieldScore(row.text, query, units, 28, 4);
    const fuzzy = dice(grams(query), grams(`${row.heading || ""} ${row.text || ""}`));
    const fuzzyScore = fuzzy >= 0.18 ? fuzzy * 22 : 0;
    return { ...row, score: heading.score + text.score + fuzzyScore, match_reasons: [heading.score ? "heading" : null, text.score ? "chunk" : null, fuzzyScore ? "ngram" : null].filter(Boolean) };
  }).filter((row) => row.match_reasons.length > 0).sort((left, right) => (
    right.score - left.score
    || String(left.path).localeCompare(String(right.path))
    || String(left.chunk_id).localeCompare(String(right.chunk_id))
  ));
}

export function searchChunks(query, options = {}, config = loadConfig()) {
  const normalized = normalizeText(query);
  if (!normalized) return { query, results: [] };
  if (suspectedSensitive(query)) throw new Error("Sensitive-looking search query was rejected");
  const indexedConfig = freshIndexConfig(config);
  const units = queryUnits(query);
  const limit = Math.min(Math.max(Number(options.limit) || 12, 1), 100);
  const results = rankChunks(normalized, units, options, indexedConfig).slice(0, limit).map((row) => ({
    path: row.path,
    url: obsidianUrl(indexedConfig, row.path),
    id: row.id,
    title: row.title,
    summary: row.summary,
    kind: row.kind,
    status: row.status,
    priority: row.priority,
    updated: row.updated,
    chunk_id: row.chunk_id,
    heading: row.heading,
    text: row.text,
    score: Number(row.score.toFixed(3)),
    match_reasons: row.match_reasons,
  }));
  return { query, normalized_query: normalized, method: "heading+chunk+ngram", results };
}

function scoreRow(row, query, units) {
  const fields = [
    ["title", row.title, 120, 24],
    ["summary", row.summary, 60, 14],
    ["aliases", row.aliases_json, 55, 13],
    // search_terms are curated routing metadata, so an exact match should beat
    // an incidental phrase repeated in a long summary or body.
    ["search_terms", row.search_terms_json, 110, 16],
    ["scope", row.scope_keys_json, 45, 11],
    ["project", row.projects_json, 42, 10],
    ["context_key", row.context_key, 36, 9],
    ["next_action", row.next_action, 30, 7],
    ["tags", row.tags_json, 28, 7],
    ["body", row.body, 16, 2.2],
  ];
  let score = 0;
  const reasons = [];
  for (const [name, value, exactWeight, unitWeight] of fields) {
    const result = fieldScore(value, query, units, exactWeight, unitWeight);
    score += result.score;
    if (result.exact || result.matches) reasons.push(name);
  }
  const fuzzy = dice(grams(query), grams(`${row.title || ""} ${row.summary || ""} ${row.aliases_json || ""}`));
  if (fuzzy >= 0.18) {
    score += fuzzy * 35;
    reasons.push("ngram");
  }
  if (!reasons.length) return { score: 0, reasons: [] };
  if (row.pinned) score += 4;
  if (row.canonical) score += 3;
  if (row.confidence === "high") score += 2;
  score += Math.max(0, 3 - (PRIORITY_RANK[row.priority] ?? 3));
  if (row.kind === "raw" || row.kind === "receipt") score -= 4;
  if (row.lifecycle === "history") score -= 2;
  return { score, reasons: [...new Set(reasons)] };
}

export function search(query, options = {}, config = loadConfig()) {
  const normalized = normalizeText(query);
  if (!normalized) return { query, results: [] };
  if (suspectedSensitive(query)) throw new Error("Sensitive-looking search query was rejected");
  const indexedConfig = freshIndexConfig(config);
  const units = queryUnits(query);
  const filters = [activeSql(options.includeArchived), "kind!='template'", retrievalEligibilitySql("", options)];
  if (!options.includeRaw) filters.push("kind NOT IN ('raw','receipt')");
  if (options.kind || options.type) filters.push(`kind=${sqlString(options.kind || options.type)}`);
  if (options.status) filters.push(`status=${sqlString(options.status)}`);
  if (options.project) filters.push(`projects_json LIKE ${sqlString(`%${options.project}%`)}`);
  if (options.contextKey) filters.push(`(context_key LIKE ${sqlString(`%${options.contextKey}%`)} OR scope_keys_json LIKE ${sqlString(`%${options.contextKey}%`)})`);
  const rows = queryRows(indexedConfig, `SELECT ${SUMMARY_COLUMNS},body,aliases_json,search_terms_json,scope_keys_json,projects_json,tags_json,canonical,content_sha256 FROM notes WHERE ${filters.join(" AND ")}`);
  const limit = Math.min(Math.max(Number(options.limit) || 10, 1), 100);
  const bestChunks = new Map();
  for (const chunk of rankChunks(normalized, units, options, indexedConfig)) {
    if (!bestChunks.has(chunk.path)) bestChunks.set(chunk.path, chunk);
  }
  const ranked = rows.map((row) => {
    const match = scoreRow(row, normalized, units);
    return { row, ...match };
  }).filter((entry) => entry.score > 0)
    .sort((left, right) => (
      right.score - left.score
      || String(right.row.updated || "").localeCompare(String(left.row.updated || ""))
      || String(left.row.path).localeCompare(String(right.row.path))
    ))
    .slice(0, limit)
    .map(({ row, score, reasons }) => ({
      ...rowSummary(indexedConfig, row),
      score: Number(score.toFixed(3)),
      match_reasons: reasons,
      snippet: bestChunks.get(row.path)?.text?.slice(0, 420) || makeSnippet(row.body, normalized, units),
      matched_heading: bestChunks.get(row.path)?.heading || null,
      matched_chunk_id: bestChunks.get(row.path)?.chunk_id || null,
    }));
  return { query, normalized_query: normalized, terms: units, method: "metadata+ngram+fulltext", results: ranked };
}

function rejectUnsafeTarget(value) {
  if (value.startsWith("/") || value.startsWith("\\") || value.split(/[\\/]/).includes("..")) {
    throw new Error("Path escapes the configured vault");
  }
}

export function fetchNote(target, config = loadConfig(), { allowSensitive = false } = {}) {
  ensureFreshIndex(config);
  const value = String(target || "").trim();
  if (!value) throw new Error("Note target is required");
  rejectUnsafeTarget(value);
  let absolutePath = null;
  if (value.toLowerCase().endsWith(".md")) {
    try {
      const candidate = resolveVaultMarkdown(config.vaultRoot, value);
      if (lstatSync(candidate).isFile()) absolutePath = candidate;
    } catch (error) {
      if (/escapes|Only Markdown/.test(error.message)) throw error;
    }
  }
  if (!absolutePath) {
    const rows = queryRows(config, `SELECT path FROM notes WHERE id=${sqlString(value)} OR origin_ref=${sqlString(value)} OR path=${sqlString(value)} OR title=${sqlString(value)} LIMIT 3`);
    if (rows.length !== 1) throw new Error(rows.length ? `Ambiguous note target: ${value}` : `Note not found: ${value}`);
    absolutePath = resolveVaultMarkdown(config.vaultRoot, rows[0].path);
  }
  const path = vaultRelativePath(config.vaultRoot, absolutePath);
  const source = readFileSync(absolutePath, "utf8");
  if (!allowSensitive && suspectedSensitive(source)) {
    throw new Error(`Sensitive content suspected; fetch rejected for ${path}`);
  }
  const parsed = parseMarkdown(source, path);
  return {
    path,
    url: obsidianUrl(config, path),
    title: parsed.title,
    summary: parsed.summary,
    properties: parsed.properties,
    markdown: parsed.body,
    links: parsed.links,
    edges: parsed.edges,
  };
}

export function backlinks(target, { limit = 50, kind } = {}, config = loadConfig()) {
  ensureFreshIndex(config);
  const note = fetchNote(target, config);
  const kindFilter = kind ? ` AND e.kind=${sqlString(kind)}` : "";
  const rows = queryRows(config, `SELECT ${SUMMARY_COLUMNS_N},e.kind AS relation_kind FROM edges e JOIN notes n ON n.path=e.source_path WHERE e.target_path=${sqlString(note.path)}${kindFilter} AND ${retrievalEligibilitySql("n")} ORDER BY n.pinned DESC,n.updated DESC LIMIT ${Math.min(Number(limit) || 50, 100)}`);
  return { target: note.path, results: rows.map((row) => ({ ...rowSummary(config, row), relation_kind: row.relation_kind })) };
}

function relatedRowsForPaths(paths, { limit = 30, includeArchived = false, automatic = false } = {}, config) {
  const unique = [...new Set(paths)].filter(Boolean);
  if (!unique.length) return [];
  const pathList = unique.map(sqlString).join(",");
  const lifecycle = includeArchived ? "1=1" : "n.lifecycle!='archived'";
  // High-degree facets such as global:* or a catch-all project are useful for
  // explicit browsing, but they are too weak to justify automatic expansion.
  const automaticFilter = automatic ? "AND seed.value NOT LIKE 'global:%' AND facet_degree.degree <= 24" : "";
  return queryRows(config, `SELECT ${SUMMARY_COLUMNS_N},COUNT(*) AS shared_count,GROUP_CONCAT(DISTINCT seed.kind || ':' || seed.value) AS shared_facets,SUM(1.0 / facet_degree.degree) AS relation_score
FROM facets seed
JOIN (SELECT kind,value,COUNT(DISTINCT path) AS degree FROM facets WHERE kind IN ('scope','project') GROUP BY kind,value) facet_degree ON facet_degree.kind=seed.kind AND facet_degree.value=seed.value
JOIN facets candidate ON candidate.kind=seed.kind AND candidate.value=seed.value
JOIN notes n ON n.path=candidate.path
WHERE seed.path IN (${pathList}) AND seed.kind IN ('scope','project') ${automaticFilter} AND candidate.path NOT IN (${pathList}) AND ${lifecycle} AND ${retrievalEligibilitySql("n")}
GROUP BY n.path
ORDER BY relation_score DESC,shared_count DESC,n.updated DESC
LIMIT ${Math.min(Math.max(Number(limit) || 30, 1), 100)}`);
}

export function relatedContext(target, { limit = 30, includeArchived = false } = {}, config = loadConfig()) {
  const note = fetchNote(target, config);
  const rows = relatedRowsForPaths([note.path], { limit, includeArchived }, config);
  return {
    target: note.path,
    results: rows.map((row) => ({
      ...rowSummary(config, row),
      shared_count: Number(row.shared_count),
      shared_facets: String(row.shared_facets || "").split(",").filter(Boolean),
      relation_score: Number(Number(row.relation_score || 0).toFixed(6)),
    })),
  };
}

function atomicWrite(path, content) {
  mkdirSync(dirname(path), { recursive: true });
  const temp = `${path}.${process.pid}.${randomUUID()}.tmp`;
  writeFileSync(temp, content, "utf8");
  renameSync(temp, path);
}

function validIsoDate(value, label = "date") {
  const date = String(value || "");
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) throw new Error(`${label} must be a valid YYYY-MM-DD date`);
  const parsed = new Date(`${date}T00:00:00Z`);
  if (!Number.isFinite(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== date) {
    throw new Error(`${label} must be a valid YYYY-MM-DD date`);
  }
  return date;
}

function writeValidatedNote(relativePath, properties, body, config, { overwrite = false } = {}) {
  assertNoSensitiveInput({ properties, body });
  const schemaErrors = validateVaultProperties(properties);
  if (schemaErrors.length) throw new Error(`Vault schema rejected write: ${schemaErrors.join("; ")}`);
  const absolutePath = resolveVaultMarkdown(config.vaultRoot, relativePath, { mustExist: false });
  if (!overwrite && existsSync(absolutePath)) throw new Error(`Vault note already exists: ${relativePath}`);
  atomicWrite(absolutePath, serializeMarkdown(properties, body));
  return absolutePath;
}

function refreshIndexAfterWrite(config) {
  try {
    const result = reindex(config);
    return { index_updated: true, index_warning: null, index_result: result };
  } catch (error) {
    return {
      index_updated: false,
      index_warning: `Markdown was saved, but the disposable index refresh failed: ${error.message}`,
      index_result: null,
    };
  }
}

function deterministicUuid(seed) {
  const hex = sha256(seed).slice(0, 32).split("");
  hex[12] = "5";
  hex[16] = ["8", "9", "a", "b"][Number.parseInt(hex[16], 16) % 4];
  const value = hex.join("");
  return `${value.slice(0, 8)}-${value.slice(8, 12)}-${value.slice(12, 16)}-${value.slice(16, 20)}-${value.slice(20)}`;
}

function defaultStatus(kind) {
  return ({
    decision: "proposed",
    handoff: "current",
    risk: "open",
    learning: "observed",
    task: "todo",
    question: "open",
    note: "current",
    project: "active",
    runbook: "draft",
  })[kind] || "current";
}

function wikilink(path, label) {
  const target = String(path).replace(/\.md$/i, "");
  return `[[${target}${label ? `|${label}` : ""}]]`;
}

function renderMachineBody(title, summary, body, nextAction, relations = {}) {
  const sections = [`# ${title}`, "", "## Summary", "", String(summary || title).trim()];
  if (nextAction) sections.push("", "## Next action", "", String(nextAction).trim());
  if (String(body || "").trim()) sections.push("", "## Content", "", String(body).trim());
  const relationLines = Object.entries(relations)
    .flatMap(([kind, links]) => asArray(links).map((link) => `- ${kind}: ${link}`));
  if (relationLines.length) sections.push("", "## Relations", "", ...relationLines);
  return sections.join("\n");
}

function assertNoSensitiveInput(value) {
  const seen = new WeakSet();
  const visit = (entry, key = "") => {
    if (typeof entry === "string") {
      if (suspectedSensitive(entry) || (key && SENSITIVE_KEY_PATTERN.test(key) && entry.trim())) return key || "value";
      return null;
    }
    if (!entry || typeof entry !== "object") return null;
    if (seen.has(entry)) return null;
    seen.add(entry);
    if (Array.isArray(entry)) {
      for (const item of entry) {
        const matched = visit(item, key);
        if (matched) return matched;
      }
      return null;
    }
    for (const [childKey, child] of Object.entries(entry)) {
      const matched = visit(child, childKey);
      if (matched) return matched;
    }
    return null;
  };
  const matchedField = visit(value);
  if (matchedField) throw new Error(`Input field ${matchedField} may contain a secret; capture was rejected`);
}

function createContextNote(args, config, { id = randomUUID(), reindexAfter = true, overwrite = false } = {}) {
  assertNoSensitiveInput(args);
  const kind = String(args.kind || args.type || "note").toLowerCase();
  if (!CONTEXT_KINDS.has(kind) && !["project", "runbook"].includes(kind)) throw new Error(`Unsupported note kind: ${kind}`);
  const title = String(args.title || "").trim();
  if (!title) throw new Error("title is required");
  const today = todayInZone();
  const context = deriveContextKey({ cwd: args.cwd || process.cwd(), task: `${title} ${args.task || ""}`, extra: args.extra || "" });
  const directory = KIND_DIRS[kind];
  const relativePath = join(directory, `${id}.md`).split(sep).join("/");
  const summary = String(args.summary || deriveSummary(args.body, { title, next_action: args.nextAction })).trim();
  const relations = Object.fromEntries(CONTEXT_RELATION_FIELDS.map((field) => {
    const camel = field.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase());
    return [field, asArray(args[field] || args[camel])];
  }));
  if (args.sourceRaw) relations.source_raw = asArray(args.sourceRaw);
  const properties = {
    schema: SCHEMA_VERSION,
    id,
    title,
    kind,
    lifecycle: args.lifecycle || "active",
    status: args.status || defaultStatus(kind),
    summary,
    priority: args.priority || "P2",
    pinned: Boolean(args.pinned),
    canonical: args.canonical !== false,
    needs_curation: Boolean(args.needsCuration),
    created: today,
    updated: today,
    review_after: args.reviewAfter ? validIsoDate(args.reviewAfter, "review_after") : null,
    scope_keys: asArray(args.scopeKeys || args.contextKey || context.key),
    projects: asArray(args.projects),
    owners: asArray(args.owners || args.owner),
    source_kind: args.sourceKind || args.source || "user",
    source_detail: args.sourceDetail || null,
    evidence: asArray(args.evidence || args.evidenceUrl),
    confidence: args.confidence || "medium",
    next_action: args.nextAction || null,
    ...relations,
    aliases: asArray(args.aliases),
    search_terms: asArray(args.searchTerms),
    tags: asArray(args.tags || ["codex"]),
    origin: args.origin || "native",
    origin_ref: args.originRef || null,
  };
  writeValidatedNote(relativePath, properties, renderMachineBody(title, summary, args.body, args.nextAction, relations), config, { overwrite });
  const refresh = reindexAfter ? refreshIndexAfterWrite(config) : { index_updated: false, index_warning: null };
  return {
    id,
    title,
    kind,
    scope_keys: properties.scope_keys,
    path: relativePath,
    url: obsidianUrl(config, relativePath),
    ...refresh,
  };
}

export function capture(args, config = loadConfig()) {
  return createContextNote(args, config);
}

export function captureRaw({ text, title, tags } = {}, config = loadConfig()) {
  const textBody = String(text || "").trim();
  if (!textBody) throw new Error("raw text is required");
  assertNoSensitiveInput({ text: textBody, title, tags });
  const now = new Date();
  const date = todayInZone(now);
  const id = randomUUID();
  const noteTitle = String(title || `Capture ${timestampInZone(now)}`).trim();
  const body = `# ${noteTitle}\n\n${textBody}`;
  const stamp = timestampInZone(now).replace(/[:]/g, "-");
  const relativePath = join("00 Inbox", "raw", date.slice(0, 4), date.slice(5, 7), `${stamp}-${safeFilename(noteTitle, 72)}--${id.slice(-8)}.md`).split(sep).join("/");
  const absolutePath = resolveVaultMarkdown(config.vaultRoot, relativePath, { mustExist: false });
  if (existsSync(absolutePath)) throw new Error(`Raw capture already exists: ${relativePath}`);
  const properties = {
    schema: SCHEMA_VERSION,
    id,
    title: noteTitle,
    kind: "raw",
    lifecycle: "active",
    status: "pending",
    summary: textBody.slice(0, 180),
    created: date,
    updated: date,
    captured_at: timestampInZone(now),
    source_kind: "user",
    tags: asArray(tags || ["inbox", "raw"]),
    immutable: true,
    body_sha256: "0".repeat(64),
  };
  properties.body_sha256 = rawIntegrityHash(serializeMarkdown(properties, body));
  writeValidatedNote(relativePath, properties, body, config);
  const refresh = refreshIndexAfterWrite(config);
  return { id, path: relativePath, body_sha256: properties.body_sha256, url: obsidianUrl(config, relativePath), ...refresh };
}

export function suspectedSensitive(text) {
  const value = String(text || "");
  if (SENSITIVE_PATTERNS.some((pattern) => pattern.test(value))) return true;
  for (const match of value.matchAll(/(?<![A-Za-z0-9_])[A-Za-z0-9_+=-]{48,}(?![A-Za-z0-9_])/g)) {
    const rawToken = match[0];
    const assignment = rawToken.match(/^([A-Za-z][A-Za-z0-9_-]{0,63})=(.+)$/);
    const token = assignment && SAFE_REFERENCE_KEY_PATTERN.test(assignment[1])
      ? assignment[2]
      : rawToken;
    if (token.length < 48) continue;
    if (/^(?:[a-f0-9]{40}|[a-f0-9]{64}|[a-f0-9]{128})$/i.test(token)) continue;
    const separators = (token.match(/[_+=-]/g) || []).length;
    if (separators > 2) continue;
    const classes = [
      /[a-z]/.test(token),
      /[A-Z]/.test(token),
      /\d/.test(token),
      /[_+=-]/.test(token),
    ].filter(Boolean).length;
    const frequencies = new Map();
    for (const character of token) frequencies.set(character, (frequencies.get(character) || 0) + 1);
    const entropy = [...frequencies.values()].reduce((sum, count) => {
      const probability = count / token.length;
      return sum - probability * Math.log2(probability);
    }, 0);
    if (classes >= 3 && new Set(token).size >= 12 && entropy >= 4.2) return true;
  }
  return false;
}

export function inbox({ limit = 50 } = {}, config = loadConfig()) {
  const indexedConfig = freshIndexConfig(config);
  const where = "n.kind='raw' AND NOT EXISTS (SELECT 1 FROM edges e JOIN notes r ON r.path=e.source_path WHERE e.target_path=n.path AND r.kind='receipt')";
  const safeLimit = Math.min(Math.max(Number(limit) || 50, 1), 200);
  const total = Number(queryRows(indexedConfig, `SELECT COUNT(*) AS count FROM notes n WHERE ${where}`)[0]?.count || 0);
  const rows = queryRows(indexedConfig, `SELECT ${SUMMARY_COLUMNS},body_sha256,raw_integrity_sha256,immutable FROM notes n WHERE ${where} ORDER BY n.captured_at,n.path LIMIT ${safeLimit}`);
  return {
    total,
    truncated: total > rows.length,
    results: rows.map((row) => {
      const immutableOk = Boolean(row.immutable)
        && RAW_HASH_PATTERN.test(String(row.body_sha256 || ""))
        && row.body_sha256 === row.raw_integrity_sha256;
      return {
        ...rowSummary(indexedConfig, row),
        immutable_ok: immutableOk,
        sensitive_suspected: Boolean(row.sensitive_suspected),
        processable: immutableOk && !Boolean(row.sensitive_suspected) && !jsonArray(row.validation_errors_json).length,
      };
    }),
  };
}

export function processRaw(args, config = loadConfig()) {
  const raw = fetchNote(args.target, config, { allowSensitive: true });
  if (legacyKind(raw.properties, raw.path) !== "raw") throw new Error("process requires a raw inbox note");
  const schemaErrors = validateVaultProperties(raw.properties);
  if (schemaErrors.length) throw new Error(`Raw note is quarantined by schema validation: ${schemaErrors.join("; ")}`);
  if (raw.properties.immutable !== true) throw new Error("Raw note is not sealed immutable; processing stopped");
  const expectedHash = raw.properties.body_sha256;
  if (!RAW_HASH_PATTERN.test(String(expectedHash || ""))) throw new Error("Raw note has no valid integrity hash; processing stopped");
  const rawAbsolute = resolveVaultMarkdown(config.vaultRoot, raw.path);
  const rawSource = readFileSync(rawAbsolute, "utf8");
  const actualHash = rawIntegrityHash(rawSource);
  if (expectedHash !== actualHash) throw new Error("Raw note integrity check failed; processing stopped");
  const sensitive = suspectedSensitive(rawSource);
  if (sensitive && !args.allowSensitive) throw new Error("Raw note may contain a secret; manual review is required");
  if (sensitive && (!args.title || !args.summary || !args.body)) {
    throw new Error("Sensitive raw processing requires an explicit sanitized title, summary, and body");
  }

  assertSafeIndexPath(config);
  const lock = acquireDirectoryLock(`${config.indexPath}.process-${sha256(raw.path).slice(0, 20)}.lock`);
  try {
    ensureFreshIndex(config);
    const existing = queryRows(config, `SELECT r.path,o.path AS output_path FROM edges e JOIN notes r ON r.path=e.source_path LEFT JOIN edges oe ON oe.source_path=r.path AND oe.kind='outputs' LEFT JOIN notes o ON o.path=oe.target_path WHERE r.kind='receipt' AND e.kind IN ('derived_from','source_raw') AND e.target_path=${sqlString(raw.path)} LIMIT 2`);
    if (existing.length) return { ok: true, idempotent: true, receipt: existing[0].path, output: existing[0].output_path };

    const requestedKind = String(args.kind || "note").toLowerCase();
    if (!CONTEXT_KINDS.has(requestedKind)) throw new Error(`Unsupported processed note kind: ${requestedKind}`);
    const outputId = deterministicUuid(`vault-context:processed-output:${raw.properties.id || raw.path}`);
    const orphanRows = queryRows(config, `SELECT ${SUMMARY_COLUMNS_N} FROM edges e JOIN notes n ON n.path=e.source_path WHERE e.kind='source_raw' AND e.target_path=${sqlString(raw.path)} AND n.kind IN ('decision','handoff','risk','learning','task','note','question') LIMIT 3`);
    if (orphanRows.length > 1) throw new Error("Multiple orphan outputs reference this raw note; manual reconciliation is required");
    const deterministicCandidates = Object.values(KIND_DIRS)
      .filter((directory) => directory.startsWith("10 Records/"))
      .map((directory) => `${directory}/${outputId}.md`)
      .filter((path) => existsSync(resolveVaultMarkdown(config.vaultRoot, path, { mustExist: false })));
    if (deterministicCandidates.length > 1) throw new Error("Multiple deterministic outputs exist for this raw note");

    let output;
    const existingOutputPath = orphanRows[0]?.path || deterministicCandidates[0];
    if (existingOutputPath) {
      const parsedOutput = fetchNote(existingOutputPath, config);
      const sourceTargets = extractWikilinks(parsedOutput.properties.source_raw);
      if (!sourceTargets.includes(raw.path.replace(/\.md$/i, ""))) {
        throw new Error("Existing processed output does not prove linkage to the raw note");
      }
      output = { id: parsedOutput.properties.id, title: parsedOutput.title, kind: parsedOutput.properties.kind, path: parsedOutput.path };
    } else {
      const safeRawTitle = sensitive ? `Sensitive raw ${raw.properties.id}` : raw.title;
      output = createContextNote({
        ...args,
        title: args.title || safeRawTitle,
        kind: requestedKind,
        summary: args.summary || deriveSummary(args.body || raw.markdown, { title: safeRawTitle, next_action: args.nextAction }),
        body: args.body || raw.markdown,
        sourceKind: args.sourceKind || "user",
        origin: "inbox",
        sourceRaw: [wikilink(raw.path)],
      }, config, { id: outputId, reindexAfter: false });
    }

    const date = validIsoDate(raw.properties.created || todayInZone(), "raw created");
    const receiptId = deterministicUuid(`vault-context:processing-receipt:${raw.properties.id || raw.path}`);
    const receiptPath = join("00 Inbox", "receipts", date.slice(0, 4), date.slice(5, 7), `${receiptId}.md`).split(sep).join("/");
    const receiptAbsolute = resolveVaultMarkdown(config.vaultRoot, receiptPath, { mustExist: false });
    if (!existsSync(receiptAbsolute)) {
      const now = new Date();
      const safeRawTitle = sensitive ? `Sensitive raw ${raw.properties.id}` : raw.title;
      const receiptProperties = {
        schema: SCHEMA_VERSION,
        id: receiptId,
        title: `Processed: ${safeRawTitle}`,
        kind: "receipt",
        lifecycle: "history",
        status: "processed",
        summary: `${safeRawTitle} を ${output.kind || requestedKind} として整理`,
        created: date,
        updated: todayInZone(now),
        processed_at: timestampInZone(now),
        source_kind: "agent",
        derived_from: [wikilink(raw.path)],
        outputs: [wikilink(output.path)],
        body_sha256: actualHash,
        tags: ["inbox", "receipt"],
      };
      const receiptBody = `# Processed: ${safeRawTitle}\n\n- Raw: ${wikilink(raw.path, safeRawTitle)}\n- Output: ${wikilink(output.path, output.title)}\n- Integrity: verified`;
      writeValidatedNote(receiptPath, receiptProperties, receiptBody, config);
    }
    const refresh = refreshIndexAfterWrite(config);
    return {
      ok: true,
      idempotent: false,
      recovered: Boolean(existingOutputPath),
      raw: raw.path,
      output: output.path,
      receipt: receiptPath,
      ...refresh,
    };
  } finally {
    lock();
  }
}

function dateDaysBefore(dateString, days) {
  const date = new Date(`${validIsoDate(dateString)}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() - days);
  return date.toISOString().slice(0, 10);
}

function graphMetrics(config) {
  const nodes = queryRows(config, `SELECT path,kind,projects_json,scope_keys_json FROM notes WHERE lifecycle!='archived' AND ${retrievalEligibilitySql()} AND kind IN ('decision','handoff','risk','learning','task','note','question','project','runbook')`);
  const nodePaths = new Set(nodes.map((row) => row.path));
  const edges = queryRows(config, "SELECT source_path,target_path,kind FROM edges WHERE target_path IS NOT NULL").filter((edge) => nodePaths.has(edge.source_path) && nodePaths.has(edge.target_path) && edge.source_path !== edge.target_path);
  const linked = new Set(edges.flatMap((edge) => [edge.source_path, edge.target_path]));
  const scoped = nodes.filter((row) => jsonArray(row.scope_keys_json).length || jsonArray(row.projects_json).length);
  const sharedScopeRows = queryRows(config, `SELECT DISTINCT f.path FROM facets f JOIN (SELECT kind,value FROM facets WHERE kind IN ('scope','project') GROUP BY kind,value HAVING COUNT(DISTINCT path)>1) shared ON shared.kind=f.kind AND shared.value=f.value`);
  const scopeConnected = new Set(sharedScopeRows.map((row) => row.path));
  return {
    nodes: nodes.length,
    explicit_edges: edges.length,
    explicit_orphans: nodes.filter((row) => !linked.has(row.path)).length,
    explicit_orphan_ratio: nodes.length ? Number((nodes.filter((row) => !linked.has(row.path)).length / nodes.length).toFixed(4)) : 0,
    scope_coverage: nodes.length ? Number((scoped.length / nodes.length).toFixed(4)) : 0,
    scope_connected_nodes: scopeConnected.size,
    scope_connected_ratio: nodes.length ? Number((scopeConnected.size / nodes.length).toFixed(4)) : 0,
    average_explicit_degree: nodes.length ? Number(((2 * edges.length) / nodes.length).toFixed(3)) : 0,
  };
}

export function quality(options = {}, config = loadConfig()) {
  const indexedConfig = freshIndexConfig(config);
  const today = validIsoDate(options.today || todayInZone(), "today");
  const staleCutoff = dateDaysBefore(today, Number(options.staleHandoffDays) || 14);
  const rows = queryRows(indexedConfig, `SELECT ${SUMMARY_COLUMNS},body_sha256,raw_integrity_sha256,immutable,scope_keys_json,projects_json FROM notes`);
  const active = rows.filter((row) => (
    row.lifecycle === "active"
    && !["template", "raw", "receipt", "daily", "weekly"].includes(row.kind)
    && !Boolean(row.sensitive_suspected)
    && Boolean(row.canonical)
    && !jsonArray(row.validation_errors_json).length
  ));
  const broken = queryRows(indexedConfig, "SELECT source_path,target_raw,kind FROM edges WHERE target_path IS NULL AND (target_raw LIKE '10 Records/%' OR target_raw LIKE '20 Synthesis/%' OR target_raw LIKE '10 Context/%' OR target_raw LIKE '10 Projects/%' OR target_raw LIKE '20 Knowledge/%' OR target_raw LIKE '30 Context/%' OR target_raw LIKE '40 Journal/%')");
  const rawRows = rows.filter((row) => row.kind === "raw");
  const pendingInbox = inbox({ limit: Number(options.limit) || 50 }, indexedConfig);
  const checks = {
    overdue_review: active.filter((row) => row.review_after && row.review_after <= today),
    low_confidence: active.filter((row) => row.confidence === "low"),
    needs_curation: active.filter((row) => row.needs_curation),
    missing_summary: active.filter((row) => !String(row.summary || "").trim()),
    missing_scope_or_project: active.filter((row) => !jsonArray(row.scope_keys_json).length && !jsonArray(row.projects_json).length),
    decisions_missing_evidence: active.filter((row) => row.kind === "decision" && !jsonArray(row.evidence_json).length),
    stale_handoffs: active.filter((row) => row.kind === "handoff" && row.status === "current" && (!row.updated || row.updated <= staleCutoff)),
    pinned_items: active.filter((row) => row.pinned),
    pending_inbox: pendingInbox.results,
    raw_integrity_failures: rawRows.filter((row) => (
      !row.immutable
      || !RAW_HASH_PATTERN.test(String(row.body_sha256 || ""))
      || row.body_sha256 !== row.raw_integrity_sha256
    )),
    sensitive_quarantined: rows.filter((row) => Boolean(row.sensitive_suspected)),
    noncanonical_quarantined: rows.filter((row) => !Boolean(row.sensitive_suspected) && !Boolean(row.canonical)),
    schema_violations: rows.filter((row) => jsonArray(row.validation_errors_json).length),
    broken_links: broken,
  };
  const summaryCounts = Object.fromEntries(Object.entries(checks).map(([name, values]) => [name, values.length]));
  summaryCounts.pending_inbox = pendingInbox.total;
  summaryCounts.pinned_limit = Number(options.pinnedLimit) || 8;
  summaryCounts.pinned_over_limit = checks.pinned_items.length > summaryCounts.pinned_limit;
  summaryCounts.today = today;
  summaryCounts.stale_handoff_cutoff = staleCutoff;
  summaryCounts.graph = graphMetrics(indexedConfig);
  summaryCounts.semantic_index = semanticCoverage(DEFAULT_EMBED_MODEL, indexedConfig);
  const maxRows = Number(options.limit) || 50;
  const formatted = {};
  for (const [name, values] of Object.entries(checks)) {
    if (["broken_links"].includes(name)) formatted[name] = values.slice(0, maxRows);
    else if (name === "pending_inbox") formatted[name] = values.slice(0, maxRows);
    else formatted[name] = values.slice(0, maxRows).map((row) => rowSummary(indexedConfig, row));
  }
  return { summary: summaryCounts, checks: formatted };
}

export function review({ before = todayInZone(), limit = 50 } = {}, config = loadConfig()) {
  const indexedConfig = freshIndexConfig(config);
  const date = validIsoDate(before, "before");
  const where = `lifecycle='active' AND ${retrievalEligibilitySql()} AND review_after IS NOT NULL AND review_after!='' AND review_after<=${sqlString(date)}`;
  const total = Number(queryRows(indexedConfig, `SELECT COUNT(*) AS count FROM notes WHERE ${where}`)[0]?.count || 0);
  const rows = queryRows(indexedConfig, `SELECT ${SUMMARY_COLUMNS} FROM notes WHERE ${where} ORDER BY review_after,CASE priority WHEN 'P0' THEN 0 WHEN 'P1' THEN 1 WHEN 'P2' THEN 2 ELSE 3 END LIMIT ${Math.min(Number(limit) || 50, 100)}`);
  return { before: date, total, truncated: total > rows.length, results: rows.map((row) => rowSummary(indexedConfig, row)) };
}

function linkList(rows, empty = "- なし") {
  if (!rows.length) return empty;
  return rows.map((row) => `- ${wikilink(row.path, row.title)}${row.summary ? ` — ${row.summary}` : ""}`).join("\n");
}

function uniqueRowsByPath(rows) {
  const seen = new Set();
  return rows.filter((row) => {
    if (!row?.path || seen.has(row.path)) return false;
    seen.add(row.path);
    return true;
  });
}

function dailyRows(date, config) {
  return queryRows(config, `SELECT ${SUMMARY_COLUMNS},captured_at,processed_at FROM notes WHERE kind NOT IN ('daily','weekly','template') AND ${retrievalEligibilitySql()} AND (updated=${sqlString(date)} OR created=${sqlString(date)} OR captured_at LIKE ${sqlString(`${date}%`)} OR processed_at LIKE ${sqlString(`${date}%`)}) ORDER BY kind,title`);
}

export function generateDaily({ date = todayInZone() } = {}, config = loadConfig()) {
  const normalizedDate = validIsoDate(date);
  const indexedConfig = freshIndexConfig(config);
  const changed = dailyRows(normalizedDate, indexedConfig);
  const focus = queryRows(indexedConfig, `SELECT ${SUMMARY_COLUMNS} FROM notes WHERE lifecycle='active' AND ${retrievalEligibilitySql()} AND priority IN ('P0','P1') AND status NOT IN ('done','closed','mitigated') AND kind IN ('project','task','handoff','risk','question') ORDER BY CASE priority WHEN 'P0' THEN 0 ELSE 1 END,updated DESC LIMIT 12`);
  const due = review({ before: normalizedDate, limit: 12 }, indexedConfig);
  const pending = inbox({ limit: 12 }, indexedConfig);
  const id = `daily-${normalizedDate}`;
  const title = `${normalizedDate} Daily Context`;
  const relativePath = `20 Synthesis/daily/${normalizedDate.slice(0, 4)}/${normalizedDate}.md`;
  const body = [
    `# ${title}`,
    "",
    "> [!summary] 今日の入口",
    `> 重要項目 ${focus.length}件、更新 ${changed.length}件、未処理Inbox ${pending.total}件、レビュー期限 ${due.total}件。`,
    "",
    "## Current focus",
    "",
    linkList(focus),
    "",
    "## 今日の更新",
    "",
    linkList(changed),
    "",
    "## 未処理Inbox",
    "",
    linkList(pending.results),
    "",
    "## Review due",
    "",
    linkList(due.results),
  ].join("\n");
  const properties = {
    schema: SCHEMA_VERSION,
    id,
    title,
    kind: "daily",
    lifecycle: "active",
    status: "generated",
    summary: `重要 ${focus.length} / 更新 ${changed.length} / Inbox ${pending.total} / Review ${due.total}`,
    created: normalizedDate,
    updated: normalizedDate,
    generated_by: "vault-context",
    source_kind: "agent",
    related: uniqueRowsByPath([...focus, ...changed, ...pending.results, ...due.results]).slice(0, 60).map((row) => wikilink(row.path)),
    tags: ["journal", "daily", "generated"],
  };
  writeValidatedNote(relativePath, properties, body, config, { overwrite: true });
  const refresh = refreshIndexAfterWrite(config);
  return { ok: true, date: normalizedDate, path: relativePath, focus: focus.length, changed: changed.length, pending_inbox: pending.total, review_due: due.total, ...refresh };
}

function isoWeek(dateString) {
  const date = new Date(`${dateString}T12:00:00Z`);
  const day = date.getUTCDay() || 7;
  date.setUTCDate(date.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
  const week = Math.ceil((((date - yearStart) / 86400000) + 1) / 7);
  const monday = new Date(`${dateString}T12:00:00Z`);
  monday.setUTCDate(monday.getUTCDate() - ((monday.getUTCDay() || 7) - 1));
  const sunday = new Date(monday);
  sunday.setUTCDate(sunday.getUTCDate() + 6);
  return {
    year: date.getUTCFullYear(),
    week,
    label: `${date.getUTCFullYear()}-W${String(week).padStart(2, "0")}`,
    start: monday.toISOString().slice(0, 10),
    end: sunday.toISOString().slice(0, 10),
  };
}

export function generateWeekly({ date = todayInZone(), narrative = "" } = {}, config = loadConfig()) {
  const normalizedDate = validIsoDate(date);
  assertNoSensitiveInput({ narrative });
  const narrativeText = String(narrative || "").trim();
  const indexedConfig = freshIndexConfig(config);
  const period = isoWeek(normalizedDate);
  const rows = queryRows(indexedConfig, `SELECT ${SUMMARY_COLUMNS} FROM notes WHERE ${retrievalEligibilitySql()} AND kind NOT IN ('raw','receipt','daily','weekly','template') AND updated>=${sqlString(period.start)} AND updated<=${sqlString(period.end)} ORDER BY CASE priority WHEN 'P0' THEN 0 WHEN 'P1' THEN 1 WHEN 'P2' THEN 2 ELSE 3 END,updated DESC,title`);
  const completed = rows.filter((row) => ["accepted", "done", "closed", "mitigated", "verified"].includes(row.status));
  const active = rows.filter((row) => !completed.includes(row));
  const commitments = rows.filter((row) => row.next_action);
  const title = `${period.label} Weekly Synthesis`;
  const relativePath = `20 Synthesis/weekly/${period.year}/${period.label}.md`;
  const absolutePath = resolveVaultMarkdown(config.vaultRoot, relativePath, { mustExist: false });
  if (!narrativeText && existsSync(absolutePath)) {
    const existing = fetchNote(relativePath, indexedConfig);
    const existingProperties = existing.properties || {};
    if (
      existingProperties.kind === "weekly"
      && existingProperties.status === "synthesized"
      && existingProperties.period_start === period.start
      && existingProperties.period_end === period.end
      && !validateVaultProperties(existingProperties).length
    ) {
      return {
        ok: true,
        ...period,
        path: relativePath,
        candidates: rows.map((row) => rowSummary(indexedConfig, row)),
        completed: completed.length,
        active: active.length,
        commitments: commitments.length,
        preserved_existing: true,
        index_updated: false,
        index_warning: null,
        index_result: null,
      };
    }
  }
  const sections = [
    `# ${title}`,
    "",
    "> [!summary] 週の概況",
    `> 更新 ${rows.length}件、完了・確定 ${completed.length}件、継続 ${active.length}件、次の一手 ${commitments.length}件。`,
  ];
  if (narrativeText) sections.push("", "## Synthesis", "", narrativeText);
  sections.push(
    "",
    "## 完了・確定",
    "",
    linkList(completed),
    "",
    "## 継続中",
    "",
    linkList(active),
    "",
    "## 約束・次の一手",
    "",
    commitments.length ? commitments.map((row) => `- ${wikilink(row.path, row.title)} — ${row.next_action}`).join("\n") : "- なし",
    "",
    "## Source map",
    "",
    linkList(rows),
  );
  const properties = {
    schema: SCHEMA_VERSION,
    id: `weekly-${period.label}`,
    title,
    kind: "weekly",
    lifecycle: "active",
    status: narrativeText ? "synthesized" : "generated",
    summary: `更新 ${rows.length} / 完了・確定 ${completed.length} / 継続 ${active.length}`,
    created: normalizedDate,
    updated: normalizedDate,
    period_start: period.start,
    period_end: period.end,
    generated_by: narrativeText ? "codex+vault-context" : "vault-context",
    source_kind: "agent",
    related: rows.slice(0, 100).map((row) => wikilink(row.path)),
    tags: ["journal", "weekly", "synthesis"],
  };
  writeValidatedNote(relativePath, properties, sections.join("\n"), config, { overwrite: true });
  const refresh = refreshIndexAfterWrite(config);
  return { ok: true, ...period, path: relativePath, candidates: rows.map((row) => rowSummary(config, row)), completed: completed.length, active: active.length, commitments: commitments.length, ...refresh };
}

function contextScopeFacets(key) {
  const facets = [];
  if (key.owner && key.repo) facets.push(`repo:${key.owner.toLowerCase()}/${key.repo.toLowerCase()}`);
  for (const token of key.issue_tokens || []) {
    const number = String(token).match(/\d+/)?.[0];
    if (number) facets.push(`issue:${number}`);
  }
  return [...new Set(facets)];
}

function scopedRowsForContext(key, limit, config) {
  const facets = contextScopeFacets(key);
  if (!facets.length) return [];
  const rows = queryRows(config, `SELECT ${SUMMARY_COLUMNS_N},COUNT(*) AS scope_match_count,GROUP_CONCAT(DISTINCT f.value) AS scope_matches
FROM facets f
JOIN notes n ON n.path=f.path
WHERE f.kind='scope' AND f.value IN (${facets.map(sqlString).join(",")}) AND n.lifecycle!='archived' AND ${retrievalEligibilitySql("n")}
GROUP BY n.path
ORDER BY scope_match_count DESC,CASE n.priority WHEN 'P0' THEN 0 WHEN 'P1' THEN 1 WHEN 'P2' THEN 2 ELSE 3 END,n.updated DESC
LIMIT ${Math.min(Math.max(Number(limit) || 8, 1), 30)}`);
  return rows.map((row) => ({
    ...rowSummary(config, row),
    score: 80 * Number(row.scope_match_count || 1),
    match_reasons: ["derived_scope"],
    scope_matches: String(row.scope_matches || "").split(",").filter(Boolean),
  }));
}

function truncateContextValue(value, limit) {
  const text = String(value || "").replace(/\s+/g, " ").trim();
  return text.length <= limit ? text : `${text.slice(0, Math.max(0, limit - 1)).trimEnd()}…`;
}

function compactContextRow(row) {
  return {
    path: row.path,
    title: truncateContextValue(row.title, 100),
    kind: row.kind || null,
    status: row.status || null,
    priority: row.priority || null,
    score: Number.isFinite(Number(row.score)) ? Number(Number(row.score).toFixed(3)) : null,
    match_reasons: asArray(row.match_reasons).slice(0, 5),
    scope_matches: asArray(row.scope_matches).slice(0, 3),
    shared_facets: asArray(row.shared_facets).slice(0, 3),
  };
}

function contextRecordText(row, mode = "full") {
  const titleLimit = mode === "minimal" ? 80 : 120;
  const summaryLimit = mode === "full" ? 220 : mode === "compact" ? 100 : 0;
  const nextLimit = mode === "full" ? 120 : 0;
  const meta = [row.priority, row.kind, row.status].filter(Boolean).join(" ");
  const lines = [`- ${truncateContextValue(row.title, titleLimit)}${meta ? ` (${meta})` : ""}`];
  if (summaryLimit) lines.push(`  summary: ${truncateContextValue(row.summary || "要約なし", summaryLimit)}`);
  if (nextLimit && row.next_action) lines.push(`  next: ${truncateContextValue(row.next_action, nextLimit)}`);
  if (row.shared_facets?.length) lines.push(`  via: ${row.shared_facets.slice(0, 3).join(", ")}`);
  lines.push(`  path: ${row.path}`);
  return lines.join("\n");
}

function packContextText(groups, scopeLabel, budget) {
  let text = `Derived scope: ${truncateContextValue(scopeLabel || "none", 120)}`;
  const selected = Object.fromEntries(groups.map((group) => [group.key, []]));
  const omitted = Object.fromEntries(groups.map((group) => [group.key, 0]));
  for (const group of groups) {
    const rows = group.rows.slice(0, group.maxItems || group.rows.length);
    omitted[group.key] += Math.max(0, group.rows.length - rows.length);
    let section = "";
    for (const row of rows) {
      const prefix = section ? "\n" : `\n\n${group.label}:\n`;
      const formats = ["full", "compact", "minimal"].map((mode) => contextRecordText(row, mode));
      const formatted = formats.find((candidate) => text.length + section.length + prefix.length + candidate.length <= budget);
      if (!formatted) {
        omitted[group.key] += 1;
        continue;
      }
      section += `${prefix}${formatted}`;
      selected[group.key].push(compactContextRow(row));
    }
    if (!rows.length) {
      const empty = `\n\n${group.label}:\n- なし`;
      if (text.length + empty.length <= budget) section = empty;
    }
    text += section;
  }
  return { text, selected, omitted };
}

export function contextForPrompt({
  prompt = "",
  cwd = process.cwd(),
  limit = 8,
  budget = 2600,
  scopeOnly = false,
} = {}, config = loadConfig()) {
  const safeLimit = Math.min(Math.max(Number(limit) || 8, 1), 30);
  const safeBudget = Math.min(Math.max(Number(budget) || 2600, 400), 12_000);
  const sensitivePrompt = suspectedSensitive(prompt);
  const usePrompt = !scopeOnly && !sensitivePrompt && String(prompt || "").trim();
  const key = deriveContextKey({ cwd, task: usePrompt ? prompt : "" });
  const indexedConfig = freshIndexConfig(config);
  // Startup context is deliberately small.  Larger pinned sets tend to surface
  // generic policies after the prompt-relevant pinned records are deduplicated.
  const pinned = startup({ limit: Math.min(3, safeLimit) }, indexedConfig).results;
  const lexical = usePrompt
    ? search(prompt, { limit: Math.min(safeLimit * 2, 30), includeArchived: false }, indexedConfig).results
    : [];
  const scoped = scopedRowsForContext(key, safeLimit, indexedConfig);
  const relevantByPath = new Map();
  for (const row of [...lexical, ...scoped]) {
    const current = relevantByPath.get(row.path);
    if (!current) {
      relevantByPath.set(row.path, { ...row });
      continue;
    }
    current.score = Number(current.score || 0) + Number(row.score || 0);
    current.match_reasons = [...new Set([...asArray(current.match_reasons), ...asArray(row.match_reasons)])];
    current.scope_matches = [...new Set([...asArray(current.scope_matches), ...asArray(row.scope_matches)])];
  }
  const relevant = [...relevantByPath.values()]
    .sort((left, right) => Number(right.score || 0) - Number(left.score || 0))
    .slice(0, safeLimit);
  const seen = new Set();
  const dedupe = (rows) => rows.filter((row) => {
    const id = row.path;
    if (!id || seen.has(id)) return false;
    seen.add(id);
    return true;
  });
  const relevantUnique = dedupe(relevant);
  const pinnedUnique = dedupe(pinned);
  const graphSeeds = relevantUnique.filter((row) => asArray(row.match_reasons).length).slice(0, 3);
  const neighbors = relatedRowsForPaths(
    graphSeeds.map((row) => row.path),
    { limit: Math.max(4, Math.floor(safeLimit / 2)), automatic: true },
    indexedConfig,
  ).map((row) => ({
    ...rowSummary(indexedConfig, row),
    shared_count: Number(row.shared_count),
    shared_facets: String(row.shared_facets || "").split(",").filter(Boolean),
    relation_score: Number(Number(row.relation_score || 0).toFixed(6)),
  }));
  const neighborUnique = dedupe(neighbors);
  const packed = packContextText([
    { key: "relevant", label: "Relevant", rows: relevantUnique, maxItems: 3 },
    { key: "pinned", label: "Pinned", rows: pinnedUnique, maxItems: 3 },
    { key: "neighbors", label: "Scope-neighbors", rows: neighborUnique, maxItems: 2 },
  ], key.key, safeBudget);
  const omittedTotal = Object.values(packed.omitted).reduce((sum, value) => sum + value, 0);
  const scope = {
    key: key.key,
    repo: key.repo,
    owner: key.owner,
    branch: key.branch,
    issue_tokens: key.issue_tokens,
    warnings: key.warnings,
  };
  const packet = {
    trust: "untrusted-data",
    scope,
    sensitive_prompt_omitted: sensitivePrompt || scopeOnly,
    pinned: packed.selected.pinned,
    relevant: packed.selected.relevant,
    neighbors: packed.selected.neighbors,
    omitted: packed.omitted,
    text: packed.text,
    budget: safeBudget,
    truncated: omittedTotal > 0,
  };
  packet.serialized_chars = JSON.stringify({ ...packet, serialized_chars: 0 }).length;
  packet.serialized_chars = JSON.stringify(packet).length;
  return packet;
}

function embeddingInput(row) {
  return [
    `Title: ${row.title}`,
    `Summary: ${row.summary || ""}`,
    `Kind: ${row.kind || ""}`,
    `Status: ${row.status || ""}`,
    `Scope: ${jsonArray(row.scope_keys_json).join(", ")}`,
    `Projects: ${jsonArray(row.projects_json).join(", ")}`,
    `Tags: ${jsonArray(row.tags_json).join(", ")}`,
    `Section: ${row.heading || "Content"}`,
    `Text: ${markdownPlainText(row.text || row.body).slice(0, 2400)}`,
  ].join("\n");
}

async function ollamaEmbed(input, { model = DEFAULT_EMBED_MODEL, timeoutMs = 120_000 } = {}) {
  const response = await fetch("http://127.0.0.1:11434/api/embed", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ model, input, truncate: true }),
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!response.ok) throw new Error(`Ollama embed failed (${response.status})`);
  const payload = await response.json();
  if (!Array.isArray(payload.embeddings)) throw new Error(payload.error || "Ollama returned no embeddings");
  return payload.embeddings;
}

function vectorBuffer(values) {
  const buffer = Buffer.allocUnsafe(values.length * 4);
  values.forEach((value, index) => buffer.writeFloatLE(Number(value), index * 4));
  return buffer;
}

function bufferVector(hex, dimensions) {
  const buffer = Buffer.from(hex, "hex");
  const values = new Float32Array(dimensions);
  for (let index = 0; index < dimensions; index += 1) values[index] = buffer.readFloatLE(index * 4);
  return values;
}

function cosine(left, right) {
  let dot = 0;
  let leftNorm = 0;
  let rightNorm = 0;
  const size = Math.min(left.length, right.length);
  for (let index = 0; index < size; index += 1) {
    dot += left[index] * right[index];
    leftNorm += left[index] * left[index];
    rightNorm += right[index] * right[index];
  }
  return leftNorm && rightNorm ? dot / Math.sqrt(leftNorm * rightNorm) : 0;
}

export async function embedVault({ model = DEFAULT_EMBED_MODEL, batchSize = 12, force = false } = {}, config = loadConfig()) {
  const indexedConfig = freshIndexConfig(config);
  assertSafeIndexPath(indexedConfig);
  const safeBatchSize = Number(batchSize);
  if (!Number.isInteger(safeBatchSize) || safeBatchSize < 1 || safeBatchSize > 64) {
    throw new Error("batchSize must be an integer from 1 to 64");
  }
  const rows = queryRows(indexedConfig, `SELECT c.path,c.chunk_id,c.heading,c.text,c.embedding_source_sha256,n.title,n.summary,n.kind,n.status,n.scope_keys_json,n.projects_json,n.tags_json FROM chunks c JOIN notes n ON n.path=c.path WHERE n.lifecycle!='archived' AND ${retrievalEligibilitySql("n")} AND n.kind NOT IN ('raw','receipt','template','daily') ORDER BY c.path,c.ordinal`);
  const existing = new Map(queryRows(indexedConfig, `SELECT path,chunk_id,source_hash FROM chunk_embeddings WHERE model=${sqlString(model)}`).map((row) => [`${row.path}\u0000${row.chunk_id}`, row.source_hash]));
  const pending = rows.filter((row) => force || existing.get(`${row.path}\u0000${row.chunk_id}`) !== row.embedding_source_sha256);
  let embedded = 0;
  for (let index = 0; index < pending.length; index += safeBatchSize) {
    const batch = pending.slice(index, index + safeBatchSize);
    const vectors = await ollamaEmbed(batch.map(embeddingInput), { model });
    if (vectors.length !== batch.length) throw new Error("Embedding batch size mismatch");
    const statements = ["BEGIN;"];
    for (let offset = 0; offset < batch.length; offset += 1) {
      const row = batch[offset];
      const vector = vectors[offset];
      statements.push(`INSERT OR REPLACE INTO chunk_embeddings(path,chunk_id,model,dimensions,vector,source_hash,updated_at) VALUES (${sqlString(row.path)},${sqlString(row.chunk_id)},${sqlString(model)},${vector.length},${sqlBlob(vectorBuffer(vector))},${sqlString(row.embedding_source_sha256)},${sqlString(timestampInZone())});`);
      embedded += 1;
    }
    statements.push("COMMIT;");
    assertSafeIndexPath(indexedConfig);
    runSqlite(indexedConfig.indexPath, statements.join("\n"));
  }
  return { ok: true, model, chunks: rows.length, embedded, cached: rows.length - pending.length };
}

function semanticCoverage(model, config, { includeArchived = false } = {}) {
  const indexedConfig = freshIndexConfig(config);
  const lifecycle = includeArchived ? "1=1" : "n.lifecycle!='archived'";
  const eligibility = `${retrievalEligibilitySql("n")} AND n.kind NOT IN ('raw','receipt','template','daily')`;
  const eligible = Number(queryRows(indexedConfig, `SELECT COUNT(*) AS count FROM chunks c JOIN notes n ON n.path=c.path WHERE ${lifecycle} AND ${eligibility}`)[0]?.count || 0);
  const embedded = Number(queryRows(indexedConfig, `SELECT COUNT(*) AS count
FROM chunks c
JOIN notes n ON n.path=c.path
JOIN chunk_embeddings e ON e.path=c.path AND e.chunk_id=c.chunk_id AND e.model=${sqlString(model)} AND e.source_hash=c.embedding_source_sha256
WHERE ${lifecycle} AND ${eligibility}`)[0]?.count || 0);
  return {
    eligible_chunks: eligible,
    embedded_chunks: embedded,
    missing_chunks: Math.max(0, eligible - embedded),
    coverage: eligible ? Number((embedded / eligible).toFixed(4)) : 1,
    complete: embedded === eligible,
  };
}

export async function semanticSearch(query, options = {}, config = loadConfig()) {
  const indexedConfig = freshIndexConfig(config);
  const model = options.model || DEFAULT_EMBED_MODEL;
  const minimumSimilarity = options.minimumSimilarity === undefined
    ? DEFAULT_SEMANTIC_MIN_SIMILARITY
    : Number(options.minimumSimilarity);
  if (!Number.isFinite(minimumSimilarity) || minimumSimilarity < 0 || minimumSimilarity > 1) {
    throw new Error("minimumSimilarity must be a finite number from 0 to 1");
  }
  const normalized = normalizeText(query);
  const coverage = semanticCoverage(model, indexedConfig, { includeArchived: options.includeArchived });
  if (!normalized) {
    return {
      query,
      model,
      method: "RRF(metadata+ngram+fulltext, semantic, scope-graph)",
      insufficient_evidence: true,
      semantic_coverage: coverage,
      warnings: coverage.complete ? [] : [`Semantic index is missing ${coverage.missing_chunks} eligible chunks`],
      results: [],
    };
  }
  if (suspectedSensitive(query)) throw new Error("Sensitive-looking semantic query was rejected");
  const embedder = options.embedder || ollamaEmbed;
  const [queryVector] = await embedder([String(query)], { model, timeoutMs: options.timeoutMs || 30_000 });
  const lifecycleFilter = options.includeArchived ? "1=1" : "n.lifecycle!='archived'";
  const rows = queryRows(indexedConfig, `SELECT ${SUMMARY_COLUMNS_N},c.chunk_id,c.heading,c.text,hex(e.vector) AS vector_hex,e.dimensions FROM chunk_embeddings e JOIN chunks c ON c.path=e.path AND c.chunk_id=e.chunk_id AND c.embedding_source_sha256=e.source_hash JOIN notes n ON n.path=e.path WHERE e.model=${sqlString(model)} AND ${lifecycleFilter} AND ${retrievalEligibilitySql("n")}`);
  if (!rows.length) throw new Error(`No semantic index for ${model}; run vault-context embed first`);
  const semanticChunks = rows
    .filter((row) => Number(row.dimensions) === queryVector.length)
    .map((row) => ({ row, similarity: cosine(queryVector, bufferVector(row.vector_hex, Number(row.dimensions))) }))
    .filter((entry) => entry.similarity >= minimumSimilarity)
    .sort((left, right) => (
      right.similarity - left.similarity
      || String(left.row.path).localeCompare(String(right.row.path))
      || String(left.row.chunk_id).localeCompare(String(right.row.chunk_id))
    ));
  const semanticByPath = new Map();
  for (const candidate of semanticChunks) if (!semanticByPath.has(candidate.row.path)) semanticByPath.set(candidate.row.path, candidate);
  const semantic = [...semanticByPath.values()].sort((left, right) => (
    right.similarity - left.similarity
    || String(left.row.path).localeCompare(String(right.row.path))
  ));
  const lexical = search(query, { ...options, limit: Math.max(Number(options.limit) || 10, 20) }, indexedConfig).results;
  const fused = new Map();
  lexical.forEach((row, index) => {
    const lexicalWeight = 0.75 + Math.min(1.75, Math.max(0, Number(row.score) || 0) / 180);
    fused.set(row.path, {
      row,
      score: lexicalWeight / (60 + index + 1),
      lexical_rank: index + 1,
      lexical_score: Number(row.score) || 0,
    });
  });
  semantic.slice(0, 80).forEach(({ row, similarity }, index) => {
    const current = fused.get(row.path) || { row: rowSummary(indexedConfig, row), score: 0 };
    current.score += 1 / (60 + index + 1);
    current.semantic_rank = index + 1;
    current.similarity = similarity;
    current.semantic_chunk = { chunk_id: row.chunk_id, heading: row.heading, text: row.text };
    fused.set(row.path, current);
  });
  const graphRows = relatedRowsForPaths(
    [...fused.values()]
      .sort((left, right) => right.score - left.score || String(left.row.path).localeCompare(String(right.row.path)))
      .slice(0, 5)
      .map((entry) => entry.row.path),
    { limit: 50, includeArchived: options.includeArchived, automatic: true },
    indexedConfig,
  );
  graphRows.forEach((row, index) => {
    const current = fused.get(row.path) || { row: rowSummary(indexedConfig, row), score: 0 };
    current.score += 0.2 / (60 + index + 1);
    current.graph_rank = index + 1;
    current.shared_facets = String(row.shared_facets || "").split(",").filter(Boolean);
    fused.set(row.path, current);
  });
  const limit = Math.min(Math.max(Number(options.limit) || 10, 1), 100);
  const results = [...fused.values()]
    .sort((left, right) => right.score - left.score || String(left.row.path).localeCompare(String(right.row.path)))
    .slice(0, limit)
    .map((entry) => ({
    ...entry.row,
    hybrid_score: Number(entry.score.toFixed(6)),
    lexical_rank: entry.lexical_rank || null,
    lexical_score: entry.lexical_score || null,
    semantic_rank: entry.semantic_rank || null,
    semantic_similarity: entry.similarity === undefined ? null : Number(entry.similarity.toFixed(5)),
    semantic_chunk: entry.semantic_chunk || null,
    graph_rank: entry.graph_rank || null,
    shared_facets: entry.shared_facets || [],
    }));
  return {
    query,
    model,
    method: "RRF(metadata+ngram+fulltext, semantic, scope-graph)",
    insufficient_evidence: results.length === 0,
    minimum_semantic_similarity: minimumSimilarity,
    semantic_coverage: coverage,
    warnings: coverage.complete ? [] : [`Semantic index is missing ${coverage.missing_chunks} eligible chunks`],
    results,
  };
}

export function health(config = loadConfig()) {
  const sqlite = spawnSync("sqlite3", ["--version"], { encoding: "utf8" });
  let indexedNotes = 0;
  let embeddings = 0;
  let semantic = { eligible_chunks: 0, embedded_chunks: 0, missing_chunks: 0, coverage: 0, complete: false };
  let schemaInSync = null;
  let indexPathSafe = true;
  let indexPathError = null;
  let indexReadable = null;
  let indexReadError = null;
  try {
    assertSafeIndexPath(config);
  } catch (error) {
    indexPathSafe = false;
    indexPathError = error.message;
  }
  if (indexPathSafe && existsSync(config.indexPath)) {
    try {
      indexedNotes = Number(runSqlite(config.indexPath, "SELECT COUNT(*) FROM notes").trim() || 0);
      embeddings = Number(runSqlite(config.indexPath, "SELECT COUNT(*) FROM chunk_embeddings").trim() || 0);
      semantic = semanticCoverage(DEFAULT_EMBED_MODEL, config);
      indexReadable = true;
    } catch {
      indexedNotes = 0;
      indexReadable = false;
      indexReadError = "Vault index could not be read";
    }
  }
  try {
    const packageSchema = readFileSync(new URL("../schema/vault-note-v2.schema.json", import.meta.url), "utf8");
    const vaultSchemaPath = join(config.vaultRoot, "90 System", "Schemas", "vault-note-v2.schema.json");
    schemaInSync = existsSync(vaultSchemaPath)
      ? sha256(packageSchema) === sha256(readFileSync(vaultSchemaPath, "utf8"))
      : null;
  } catch {
    schemaInSync = false;
  }
  return {
    ok: existsSync(config.vaultRoot)
      && sqlite.status === 0
      && schemaInSync !== false
      && indexPathSafe
      && indexReadable !== false,
    vault: config.vaultRoot,
    vault_exists: existsSync(config.vaultRoot),
    index: config.indexPath,
    index_exists: existsSync(config.indexPath),
    index_path_safe: indexPathSafe,
    index_path_error: indexPathError,
    index_readable: indexReadable,
    index_read_error: indexReadError,
    indexed_notes: indexedNotes,
    embeddings,
    embedding_model: DEFAULT_EMBED_MODEL,
    semantic_index: semantic,
    schema_in_sync: schemaInSync,
    sqlite_available: sqlite.status === 0,
    sqlite_version: sqlite.status === 0 ? sqlite.stdout.trim() : null,
    time_zone: "Asia/Tokyo",
  };
}

export { deriveContextKey, parseMarkdown };
