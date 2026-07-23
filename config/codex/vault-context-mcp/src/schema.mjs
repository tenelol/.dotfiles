import { createHash } from "node:crypto";
import { existsSync, readFileSync, realpathSync } from "node:fs";
import { basename, relative, resolve, sep } from "node:path";
import { parse as parseYaml, stringify as stringifyYaml } from "yaml";
import Ajv2020 from "ajv/dist/2020.js";

export const SCHEMA_VERSION = "vault-note/v2";
export const TIME_ZONE = "Asia/Tokyo";

const VAULT_NOTE_SCHEMA = JSON.parse(readFileSync(new URL("../schema/vault-note-v2.schema.json", import.meta.url), "utf8"));
const validateVaultNote = new Ajv2020({ allErrors: true, strict: false }).compile(VAULT_NOTE_SCHEMA);

export const RELATION_FIELDS = [
  "projects",
  "related",
  "supersedes",
  "superseded_by",
  "depends_on",
  "supports",
  "contradicts",
  "derived_from",
  "source_raw",
  "outputs",
];

const PROPERTY_ORDER = [
  "schema",
  "id",
  "title",
  "kind",
  "lifecycle",
  "status",
  "summary",
  "priority",
  "pinned",
  "canonical",
  "needs_curation",
  "created",
  "updated",
  "review_after",
  "scope_keys",
  "projects",
  "owners",
  "source_kind",
  "source_detail",
  "evidence",
  "confidence",
  "next_action",
  "related",
  "supersedes",
  "superseded_by",
  "depends_on",
  "supports",
  "contradicts",
  "derived_from",
  "source_raw",
  "outputs",
  "aliases",
  "search_terms",
  "tags",
  "origin",
  "origin_ref",
  "legacy_context_key",
  "captured_at",
  "processed_at",
  "immutable",
  "body_sha256",
  "generated_by",
  "period_start",
  "period_end",
];

export function sha256(value) {
  return createHash("sha256").update(String(value ?? ""), "utf8").digest("hex");
}

export function normalizeText(value) {
  return String(value ?? "").normalize("NFKC").toLowerCase().replace(/\s+/g, " ").trim();
}

export function asArray(value) {
  if (Array.isArray(value)) return value.filter((entry) => entry !== null && entry !== undefined).map(String);
  if (value === null || value === undefined || value === "") return [];
  return [String(value)];
}

export function validateVaultProperties(properties) {
  if (validateVaultNote(properties)) return [];
  return (validateVaultNote.errors || []).map((error) => {
    const location = error.instancePath || "/";
    return `${location} ${error.message || error.keyword}`.trim();
  });
}

function sanitizeYamlValue(value) {
  if (value instanceof Date) return value.toISOString();
  if (Array.isArray(value)) return value.map(sanitizeYamlValue);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([key, entry]) => [key, sanitizeYamlValue(entry)]));
  }
  return value;
}

export function orderedProperties(properties) {
  const input = sanitizeYamlValue(properties || {});
  const output = {};
  for (const key of PROPERTY_ORDER) {
    if (Object.hasOwn(input, key) && input[key] !== undefined) output[key] = input[key];
  }
  for (const [key, value] of Object.entries(input)) {
    if (!Object.hasOwn(output, key) && value !== undefined) output[key] = value;
  }
  return output;
}

export function serializeMarkdown(properties, body) {
  const yaml = stringifyYaml(orderedProperties(properties), {
    lineWidth: 0,
    defaultStringType: "QUOTE_DOUBLE",
    defaultKeyType: "PLAIN",
  }).trimEnd();
  return `---\n${yaml}\n---\n\n${String(body || "").trim()}\n`;
}

function parseFrontmatter(text) {
  const normalized = String(text || "").replace(/^\uFEFF/, "").replace(/\r\n?/g, "\n");
  if (!normalized.startsWith("---\n")) return { properties: {}, body: normalized, error: null };
  const end = normalized.indexOf("\n---\n", 4);
  if (end === -1) return { properties: {}, body: normalized, error: "Unterminated YAML frontmatter" };
  const source = normalized.slice(4, end);
  try {
    const parsed = parseYaml(source, { prettyErrors: true, uniqueKeys: true }) || {};
    if (!parsed || Array.isArray(parsed) || typeof parsed !== "object") {
      return { properties: {}, body: normalized.slice(end + 5), error: "Frontmatter must be a mapping" };
    }
    return { properties: sanitizeYamlValue(parsed), body: normalized.slice(end + 5), error: null };
  } catch (error) {
    return { properties: {}, body: normalized.slice(end + 5), error: error.message };
  }
}

export function extractWikilinks(value) {
  const links = [];
  const visit = (entry) => {
    if (Array.isArray(entry)) {
      for (const item of entry) visit(item);
      return;
    }
    if (entry && typeof entry === "object") {
      for (const item of Object.values(entry)) visit(item);
      return;
    }
    for (const match of String(entry ?? "").matchAll(/\[\[([^\]|#]+)(?:[|#][^\]]*)?\]\]/g)) {
      const target = match[1].trim().replace(/\.md$/i, "");
      if (target && !links.includes(target)) links.push(target);
    }
  };
  visit(value);
  return links;
}

export function markdownPlainText(markdown) {
  return String(markdown || "")
    .replace(/```[\s\S]*?```/g, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/!\[\[[^\]]+\]\]/g, " ")
    .replace(/\[\[([^\]|#]+)(?:[|#]([^\]]+))?\]\]/g, (_, target, label) => label || basename(target))
    .replace(/!?(?:\[([^\]]*)\])\([^)]*\)/g, "$1")
    .replace(/^#{1,6}\s+/gm, "")
    .replace(/^>\s?\[![^\]]+\][^\n]*$/gm, "")
    .replace(/^[-*+]\s+/gm, "")
    .replace(/[*_~`|]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

export function deriveSummary(body, properties = {}, limit = 280) {
  const explicit = String(properties.summary || "").trim();
  if (explicit) return explicit.slice(0, limit);
  const painSummary = String(body || "").match(/^summary:\s*(.+)$/m)?.[1]?.trim();
  const candidate = painSummary || markdownPlainText(
    String(body || "")
      .replace(/^#\s+.+$/m, "")
      .replace(/## Migration provenance[\s\S]*$/i, "")
      .replace(/## Relations[\s\S]*?(?=\n## |$)/i, ""),
  );
  const fallback = String(properties.next_action || properties.title || "").trim();
  const summary = candidate || fallback;
  if (summary.length <= limit) return summary;
  const prefix = summary.slice(0, limit - 1);
  const boundary = Math.max(prefix.lastIndexOf("。"), prefix.lastIndexOf("."), prefix.lastIndexOf(" "));
  return `${prefix.slice(0, boundary > limit * 0.55 ? boundary + 1 : limit - 1).trim()}…`;
}

export function parseMarkdown(markdown, path = "") {
  const { properties, body, error } = parseFrontmatter(markdown);
  const heading = body.match(/^#\s+(.+)$/m)?.[1]?.trim();
  const title = String(properties.title || heading || basename(path, ".md") || "Untitled");
  const edges = [];
  const seen = new Set();
  const addEdge = (target, kind) => {
    const key = `${kind}\u0000${target}`;
    if (!target || seen.has(key)) return;
    seen.add(key);
    edges.push({ target, kind });
  };
  for (const field of RELATION_FIELDS) {
    for (const target of extractWikilinks(properties[field])) addEdge(target, field);
  }
  for (const target of extractWikilinks(body)) addEdge(target, "link");
  const links = [...new Set(edges.map((edge) => edge.target))];
  return {
    properties,
    body,
    title,
    summary: deriveSummary(body, { ...properties, title }),
    links,
    edges,
    tags: asArray(properties.tags),
    aliases: asArray(properties.aliases),
    searchTerms: asArray(properties.search_terms),
    scopeKeys: asArray(properties.scope_keys),
    projects: asArray(properties.projects),
    sourceRaw: asArray(properties.source_raw),
    frontmatterError: error,
  };
}

export function todayInZone(date = new Date(), timeZone = TIME_ZONE) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

export function timeInZone(date = new Date(), timeZone = TIME_ZONE) {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone,
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.hour}:${values.minute}:${values.second}`;
}

export function timestampInZone(date = new Date(), timeZone = TIME_ZONE) {
  return `${todayInZone(date, timeZone)}T${timeInZone(date, timeZone)}`;
}

export function safeFilename(title, limit = 100) {
  const cleaned = String(title || "Untitled")
    .normalize("NFC")
    .replace(/[\\/:*?"<>|#^\[\]]/g, "-")
    .replace(/[\u0000-\u001f]/g, " ")
    .replace(/\s+/g, " ")
    .replace(/[. ]+$/g, "")
    .trim();
  return (cleaned || "Untitled").slice(0, limit);
}

export function vaultRelativePath(vaultRoot, absolutePath) {
  const root = resolve(vaultRoot);
  const candidate = resolve(absolutePath);
  if (candidate !== root && !candidate.startsWith(`${root}${sep}`)) throw new Error("Path escapes the configured vault");
  return relative(root, candidate).split(sep).join("/");
}

export function resolveVaultMarkdown(vaultRoot, target, { mustExist = true } = {}) {
  const root = resolve(vaultRoot);
  const rootReal = existsSync(root) ? realpathSync(root) : root;
  const value = String(target || "").trim();
  if (!value) throw new Error("Note target is required");
  const candidate = resolve(root, value);
  if (candidate !== root && !candidate.startsWith(`${root}${sep}`)) throw new Error("Path escapes the configured vault");
  if (!candidate.toLowerCase().endsWith(".md")) throw new Error("Only Markdown notes inside the vault may be accessed");
  if (mustExist && !existsSync(candidate)) throw new Error(`Note not found: ${value}`);
  let existing = candidate;
  while (!existsSync(existing)) {
    const parent = resolve(existing, "..");
    if (parent === existing) break;
    existing = parent;
  }
  if (existsSync(existing)) {
    const existingReal = realpathSync(existing);
    if (existingReal !== rootReal && !existingReal.startsWith(`${rootReal}${sep}`)) {
      throw new Error("Path escapes the configured vault through a symlink");
    }
  }
  return candidate;
}

export function readParsedMarkdown(vaultRoot, absolutePath) {
  const path = vaultRelativePath(vaultRoot, absolutePath);
  return { path, ...parseMarkdown(readFileSync(absolutePath, "utf8"), path) };
}
