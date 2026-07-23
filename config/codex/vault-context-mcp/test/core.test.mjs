import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, mkdirSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { tmpdir } from "node:os";
import test from "node:test";
import {
  backlinks,
  capture,
  captureRaw,
  contextForPrompt,
  ensureFreshIndex,
  fetchNote,
  generateDaily,
  generateWeekly,
  health,
  implementationIsCurrent,
  inbox,
  parseMarkdown,
  processRaw,
  quality,
  relatedContext,
  reindex,
  review,
  search,
  searchChunks,
  semanticSearch,
  startup,
} from "../src/core.mjs";
import { serializeMarkdown, todayInZone } from "../src/schema.mjs";

function fixture() {
  const vaultRoot = mkdtempSync(join(tmpdir(), "vault-context-test-"));
  const config = { vaultRoot, indexPath: join(vaultRoot, ".vault-context", "index.sqlite"), vaultName: "test" };
  const alphaPath = "10 Records/decision/11111111-1111-1111-1111-111111111111.md";
  const betaPath = "10 Records/note/22222222-2222-2222-2222-222222222222.md";
  mkdirSync(join(vaultRoot, "10 Records", "decision"), { recursive: true });
  mkdirSync(join(vaultRoot, "10 Records", "note"), { recursive: true });
  writeFileSync(join(vaultRoot, alphaPath), `---
schema: vault-note/v2
id: 11111111-1111-1111-1111-111111111111
title: Obsidian検索の設計判断
kind: decision
lifecycle: active
status: accepted
summary: 日本語の無空白queryをchunkとtrigramで検索する。
priority: P1
pinned: false
canonical: true
needs_curation: false
created: 2026-07-23
updated: 2026-07-23
review_after: 2026-07-22
scope_keys:
  - project:codex-context
projects: []
source_kind: repository
evidence:
  - https://example.com/evidence
confidence: high
next_action: semantic indexを再生成する
related:
  - "[[10 Records/note/22222222-2222-2222-2222-222222222222]]"
aliases:
  - 検索インデックス
search_terms:
  - Obsidian
  - RAG
tags:
  - codex
  - search
---

# Obsidian検索の設計判断

## Summary

日本語の無空白queryをchunkとtrigramで検索する。

## Content

検索インデックスはMarkdownを正本として再生成できる。
`, "utf8");
  writeFileSync(join(vaultRoot, betaPath), serializeMarkdown({
    schema: "vault-note/v2",
    id: "22222222-2222-2222-2222-222222222222",
    title: "無関係なPinnedノート",
    kind: "note",
    lifecycle: "active",
    status: "current",
    summary: "天気のメモ。",
    priority: "P3",
    pinned: true,
    canonical: true,
    needs_curation: false,
    created: "2026-07-22",
    updated: "2026-07-22",
    scope_keys: ["topic:weather"],
    source_kind: "user",
    confidence: "medium",
    tags: ["weather"],
  }, "# 無関係なPinnedノート\n\n## Content\n\n晴れ。"), "utf8");
  return { config, alphaPath, betaPath, cleanup: () => rmSync(vaultRoot, { recursive: true, force: true }) };
}

function sqliteRows(config, sql) {
  const result = spawnSync("sqlite3", ["-json", config.indexPath, sql], { encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim() ? JSON.parse(result.stdout) : [];
}

test("YAML block lists, index, Japanese search, chunks, startup, backlinks, and quality", () => {
  const { config, alphaPath, cleanup } = fixture();
  try {
    const parsed = parseMarkdown(readFileSync(join(config.vaultRoot, alphaPath), "utf8"), alphaPath);
    assert.equal(implementationIsCurrent(), true);
    assert.deepEqual(parsed.tags, ["codex", "search"]);
    assert.deepEqual(parsed.scopeKeys, ["project:codex-context"]);
    assert.equal(reindex(config).notes, 2);
    const result = search("Obsidian検索インデックス", {}, config);
    assert.equal(result.results[0].title, "Obsidian検索の設計判断");
    assert.notEqual(result.results[0].title, "無関係なPinnedノート");
    const chunks = searchChunks("日本語無空白query", {}, config);
    assert.equal(chunks.results[0].path, alphaPath);
    assert.equal(startup({}, config).results.length, 1);
    assert.equal(backlinks("無関係なPinnedノート", {}, config).results[0].title, "Obsidian検索の設計判断");
    const report = quality({ today: "2026-07-23" }, config);
    assert.equal(report.summary.overdue_review, 1);
    assert.equal(report.summary.broken_links, 0);
    assert.equal(report.summary.raw_integrity_failures, 0);
    assert.equal(report.summary.schema_violations, 0);
    assert.equal(report.summary.graph.scope_coverage, 1);
  } finally {
    cleanup();
  }
});

test("an exact curated search term outranks an incidental phrase in prose", () => {
  const { config, alphaPath, cleanup } = fixture();
  const incidentalPath = "10 Records/decision/33333333-3333-3333-3333-333333333333.md";
  try {
    const alpha = readFileSync(join(config.vaultRoot, alphaPath), "utf8").replace("  - RAG\n", "  - RAG\n  - ベクトル検索\n");
    writeFileSync(join(config.vaultRoot, alphaPath), alpha, "utf8");
    writeFileSync(join(config.vaultRoot, incidentalPath), serializeMarkdown({
      schema: "vault-note/v2",
      id: "33333333-3333-3333-3333-333333333333",
      title: "検索障害の処理",
      kind: "decision",
      lifecycle: "active",
      status: "accepted",
      summary: "翻訳・ベクトル検索・回答生成の一時障害を処理する。ベクトル検索はfallbackできる。",
      priority: "P2",
      pinned: false,
      canonical: true,
      needs_curation: false,
      created: "2026-07-23",
      updated: "2026-07-23",
      scope_keys: ["project:other"],
      source_kind: "repository",
      confidence: "high",
    }, "# 検索障害の処理\n\n## Content\n\nベクトル検索の一時障害を再試行する。"), "utf8");
    reindex(config);
    assert.equal(search("ベクトル検索", {}, config).results[0].path, alphaPath);
  } finally {
    cleanup();
  }
});

test("fetch rejects vault escapes and accepts IDs", () => {
  const { config, alphaPath, cleanup } = fixture();
  try {
    reindex(config);
    assert.equal(fetchNote("11111111-1111-1111-1111-111111111111", config).path, alphaPath);
    assert.throws(() => fetchNote("../package.json", config), /escapes/);
    assert.throws(() => fetchNote("/etc/passwd", config), /escapes/);
  } finally {
    cleanup();
  }
});

test("fetch rejects an intermediate symlink that escapes the vault", () => {
  const { config, cleanup } = fixture();
  const outside = mkdtempSync(join(tmpdir(), "vault-context-outside-"));
  try {
    writeFileSync(join(outside, "outside.md"), "# outside\n", "utf8");
    symlinkSync(outside, join(config.vaultRoot, "escape"), "dir");
    symlinkSync(outside, join(config.vaultRoot, "10 Records", "question"), "dir");
    reindex(config);
    assert.throws(() => fetchNote("escape/outside.md", config), /symlink/);
    assert.throws(() => capture({ title: "Escaping write", kind: "question", scopeKeys: ["topic:test"] }, config), /symlink/);
  } finally {
    cleanup();
    rmSync(outside, { recursive: true, force: true });
  }
});

test("reindex rejects a symlinked indexed root", () => {
  const vaultRoot = mkdtempSync(join(tmpdir(), "vault-context-symlink-root-"));
  const outside = mkdtempSync(join(tmpdir(), "vault-context-symlink-source-"));
  const config = { vaultRoot, indexPath: join(vaultRoot, ".vault-context", "index.sqlite"), vaultName: "test" };
  try {
    mkdirSync(join(outside, "note"), { recursive: true });
    writeFileSync(join(outside, "note", "outside.md"), "# Outside marker\n", "utf8");
    symlinkSync(outside, join(vaultRoot, "10 Records"), "dir");
    assert.throws(() => reindex(config), /Indexed root must not be a symlink/);
  } finally {
    rmSync(vaultRoot, { recursive: true, force: true });
    rmSync(outside, { recursive: true, force: true });
  }
});

test("reindex rejects a symlinked index parent without overwriting outside files", () => {
  const { config, cleanup } = fixture();
  const outside = mkdtempSync(join(tmpdir(), "vault-context-index-outside-"));
  const sentinel = join(outside, "index.sqlite");
  try {
    writeFileSync(sentinel, "external sentinel", "utf8");
    symlinkSync(outside, join(config.vaultRoot, ".vault-context"), "dir");
    assert.throws(() => reindex(config), /index path.*symlink/i);
    const report = health(config);
    assert.equal(report.ok, false);
    assert.equal(report.index_path_safe, false);
    assert.equal(readFileSync(sentinel, "utf8"), "external sentinel");
  } finally {
    cleanup();
    rmSync(outside, { recursive: true, force: true });
  }
});

test("health fails closed when an existing index is unreadable", () => {
  const { config, cleanup } = fixture();
  try {
    mkdirSync(dirname(config.indexPath), { recursive: true });
    writeFileSync(config.indexPath, "not a sqlite database", "utf8");
    const report = health(config);
    assert.equal(report.ok, false);
    assert.equal(report.index_path_safe, true);
    assert.equal(report.index_readable, false);
    assert.equal(report.index_read_error, "Vault index could not be read");
  } finally {
    cleanup();
  }
});

test("health and reindex reject an unusable index ancestor", () => {
  const { config, cleanup } = fixture();
  try {
    writeFileSync(dirname(config.indexPath), "not a directory", "utf8");
    assert.throws(() => reindex(config), /index ancestor must be a directory/i);
    const report = health(config);
    assert.equal(report.ok, false);
    assert.equal(report.index_path_safe, false);
  } finally {
    cleanup();
  }
});

test("quality and review queues exclude historical records", () => {
  const { config, cleanup } = fixture();
  const historyPath = "10 Records/handoff/33333333-3333-4333-8333-333333333333.md";
  try {
    mkdirSync(dirname(join(config.vaultRoot, historyPath)), { recursive: true });
    writeFileSync(join(config.vaultRoot, historyPath), serializeMarkdown({
      schema: "vault-note/v2",
      id: "33333333-3333-4333-8333-333333333333",
      title: "Closed historical handoff",
      kind: "handoff",
      lifecycle: "history",
      status: "closed",
      summary: "完了済みの履歴。",
      priority: "P1",
      pinned: false,
      canonical: true,
      needs_curation: true,
      created: "2026-07-01",
      updated: "2026-07-01",
      review_after: "2026-07-02",
      scope_keys: ["topic:test"],
      source_kind: "agent",
      confidence: "high",
    }, "# Closed historical handoff\n\n完了済み。"), "utf8");
    reindex(config);
    const report = quality({ today: "2026-07-23" }, config);
    assert.equal(report.summary.overdue_review, 1);
    assert.equal(report.summary.needs_curation, 0);
    const queue = review({ before: "2026-07-23" }, config);
    assert.equal(queue.total, 1);
    assert.equal(queue.results.some((row) => row.path === historyPath), false);
  } finally {
    cleanup();
  }
});

test("canonical and raw capture reject secret-like input", () => {
  const { config, cleanup } = fixture();
  try {
    reindex(config);
    assert.throws(() => capture({ title: "Unsafe", kind: "note", body: "api_key=FAKE_SECRET_VALUE_123456" }, config), /capture was rejected/);
    assert.throws(() => capture({ title: "Unsafe auth", kind: "note", body: "Authorization: Bearer FAKE_REVIEW_TOKEN_1234567890" }, config), /capture was rejected/);
    assert.throws(() => capture({ title: "Unsafe token auth", kind: "note", body: "Authorization: token 0123456789abcdef0123456789abcdef01234567" }, config), /capture was rejected/);
    assert.throws(() => capture({ title: "Unsafe API key auth", kind: "note", body: "Authorization: ApiKey 0123456789abcdef0123456789abcdef" }, config), /capture was rejected/);
    assert.throws(() => capture({ title: "Unsafe env", kind: "note", body: "STRIPE_SECRET_KEY=FAKE_REVIEW_TOKEN_1234567890" }, config), /capture was rejected/);
    assert.throws(() => capture({ title: "Unsafe JSON", kind: "note", body: "{\"client_secret\":\"FAKE_TEST_CREDENTIAL_1234567890\"}" }, config), /capture was rejected/);
    assert.throws(() => capture({ title: "Unsafe camel JSON", kind: "note", body: "{\"apiKey\":\"FAKE_TEST_CREDENTIAL_1234567890\"}" }, config), /capture was rejected/);
    assert.throws(() => capture({ title: "Unsafe CLI", kind: "note", body: "--token FAKE_TEST_CREDENTIAL_1234567890" }, config), /capture was rejected/);
    for (const credential of [
      "sk_" + "live_" + "1234567890abcdefghijklmnop",
      "glpat-" + "1234567890abcdefghijklmnop",
      "npm_" + "1234567890abcdefghijklmnopqrstuvwxyz",
      "AIza" + "1234567890abcdefghijklmnopqrstuvwxyzABC",
      "https://example.invalid/blob?sv=2024-01-01&sp=r&" + "sig=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef%3D",
      "SG." + "1234567890abcdefghijklmnop." + "1234567890abcdefghijklmnop",
      "hf_" + "1234567890abcdefghijklmnop",
    ]) {
      assert.throws(
        () => capture({ title: "Unsafe provider credential", kind: "note", body: credential }, config),
        /capture was rejected/,
      );
    }
    assert.throws(() => captureRaw({ title: "Unsafe raw", text: "password=FAKE_SECRET_VALUE_123456" }, config), /capture was rejected/);
    assert.throws(() => captureRaw({ title: "Unsafe token auth raw", text: "Authorization: token 0123456789abcdef0123456789abcdef01234567" }, config), /capture was rejected/);
    assert.throws(() => captureRaw({ title: "Unsafe JSON raw", text: "{\"client_secret\":\"FAKE_TEST_CREDENTIAL_1234567890\"}" }, config), /capture was rejected/);
    assert.throws(() => captureRaw({ title: "Unsafe CLI raw", text: "--token FAKE_TEST_CREDENTIAL_1234567890" }, config), /capture was rejected/);
    assert.doesNotThrow(() => capture({
      title: "Safe branch reference",
      kind: "note",
      body: "feature-this-is-a-long-human-readable-branch-name-for-ticket-12345",
      scopeKeys: ["topic:test"],
    }, config));
    assert.doesNotThrow(() => capture({
      title: "Safe durable references",
      kind: "note",
      body: [
        "occurrence_id=2026-07-12_registry-persistence-contract",
        "fix_commit=1a2b3c4d5e6f7081928374655647382910abcdef",
      ].join("\n"),
      scopeKeys: ["topic:test"],
    }, config));
  } finally {
    cleanup();
  }
});

test("capture enforces the same strict schema used by index quality", () => {
  const { config, cleanup } = fixture();
  try {
    reindex(config);
    assert.throws(() => capture({ title: "Bad lifecycle", kind: "note", lifecycle: "garbage", scopeKeys: ["topic:test"] }, config), /Vault schema rejected/);
    assert.throws(() => capture({ title: "Bad source", kind: "note", sourceKind: "arbitrary", scopeKeys: ["topic:test"] }, config), /Vault schema rejected/);
    assert.throws(() => capture({ title: "Bad relation", kind: "note", related: ["not-a-wikilink"], scopeKeys: ["topic:test"] }, config), /Vault schema rejected/);
  } finally {
    cleanup();
  }
});

test("capture, immutable raw processing, receipts, daily, weekly, and context packets are idempotent", () => {
  const { config, cleanup } = fixture();
  try {
    reindex(config);
    const note = capture({ title: "新しいリスク", kind: "risk", summary: "重要なリスク", body: "Risk body", scopeKeys: ["project:test"] }, config);
    assert.equal(search("重要なリスク", {}, config).results[0].path, note.path);
    const raw = captureRaw({ title: "Voice", text: "Raw voice text" }, config);
    assert.equal(inbox({}, config).results.length, 1);
    const processed = processRaw({ target: raw.path, kind: "note", title: "Voice cleaned", summary: "音声メモを整理", body: "Clean body", scopeKeys: ["project:test"] }, config);
    assert.equal(processed.idempotent, false);
    assert.ok(relatedContext(note.path, {}, config).results.some((row) => row.path === processed.output));
    assert.equal(inbox({}, config).results.length, 0);
    const again = processRaw({ target: raw.path, kind: "note", summary: "ignored" }, config);
    assert.equal(again.idempotent, true);
    const rawSource = readFileSync(join(config.vaultRoot, raw.path), "utf8");
    assert.match(rawSource, /Raw voice text/);
    const daily = generateDaily({ date: "2026-07-23" }, config);
    const dailyFirst = readFileSync(join(config.vaultRoot, daily.path), "utf8");
    assert.equal(generateDaily({ date: "2026-07-23" }, config).path, daily.path);
    const dailySecond = readFileSync(join(config.vaultRoot, daily.path), "utf8");
    assert.equal(dailySecond, dailyFirst);
    assert.doesNotMatch(dailySecond, /\[\[20 Synthesis\/daily\//);
    const weekly = generateWeekly({ date: "2026-07-23", narrative: "今週の統合" }, config);
    assert.equal(generateWeekly({ date: "2026-07-23", narrative: "今週の統合" }, config).path, weekly.path);
    const weeklySource = readFileSync(join(config.vaultRoot, weekly.path), "utf8");
    const weeklyPreview = generateWeekly({ date: "2026-07-23" }, config);
    assert.equal(weeklyPreview.preserved_existing, true);
    assert.equal(readFileSync(join(config.vaultRoot, weekly.path), "utf8"), weeklySource);
    const packet = contextForPrompt({ prompt: "検索インデックスを改善", cwd: config.vaultRoot, budget: 1200 }, config);
    assert.ok(packet.text.length <= 1200);
    assert.equal(new Set([...packet.pinned, ...packet.relevant].map((row) => row.path)).size, packet.pinned.length + packet.relevant.length);
    assert.ok(packet.relevant.some((row) => row.path === "10 Records/decision/11111111-1111-1111-1111-111111111111.md"));
  } finally {
    cleanup();
  }
});

test("unknown queries stay empty and long prompts preserve specific tail terms", () => {
  const { config, alphaPath, cleanup } = fixture();
  try {
    reindex(config);
    assert.deepEqual(search("改善して", {}, config).results, []);
    assert.deepEqual(searchChunks("zzzxqvplm 84736291", {}, config).results, []);
    const filler = Array.from({ length: 70 }, (_, index) => `dummyword${index}`).join(" ");
    const prompt = `${filler} Obsidian検索インデックス`;
    const packet = contextForPrompt({ prompt, cwd: "/tmp/unrelated-workspace", budget: 1000 }, config);
    assert.equal(packet.relevant[0].path, alphaPath);
    assert.match(packet.text, new RegExp(alphaPath.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
    assert.ok(packet.serialized_chars < 5_200);
  } finally {
    cleanup();
  }
});

test("context packing is record-aware and keeps the top relevant record at minimum budget", () => {
  const { config, alphaPath, cleanup } = fixture();
  try {
    reindex(config);
    const packet = contextForPrompt({
      prompt: "Obsidian検索インデックス",
      cwd: "/tmp/unrelated-workspace",
      budget: 400,
      limit: 8,
    }, config);
    assert.ok(packet.text.length <= 400);
    assert.equal(packet.relevant[0].path, alphaPath);
    for (const row of [...packet.relevant, ...packet.pinned, ...packet.neighbors]) {
      assert.match(packet.text, new RegExp(row.path.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
    }
    assert.equal(packet.truncated, Object.values(packet.omitted).some((count) => count > 0));
  } finally {
    cleanup();
  }
});

test("automatic graph expansion ignores catch-all high-degree facets", () => {
  const { config, cleanup } = fixture();
  try {
    for (let index = 0; index < 25; index += 1) {
      const suffix = String(index).padStart(12, "0");
      const id = `aaaaaaaa-aaaa-4aaa-8aaa-${suffix}`;
      writeFileSync(join(config.vaultRoot, "10 Records", "note", `${id}.md`), serializeMarkdown({
        schema: "vault-note/v2",
        id,
        title: `Generic project member ${index}`,
        kind: "note",
        lifecycle: "active",
        status: "current",
        summary: "Generic member with no lexical relation to the retrieval query.",
        priority: "P3",
        pinned: false,
        canonical: true,
        needs_curation: false,
        created: "2026-07-23",
        updated: "2026-07-23",
        scope_keys: ["project:codex-context"],
        source_kind: "repository",
        confidence: "medium",
      }, `# Generic project member ${index}`), "utf8");
    }
    reindex(config);
    const packet = contextForPrompt({
      prompt: "Obsidian検索インデックス",
      cwd: "/tmp/unrelated-workspace",
      budget: 1200,
      limit: 8,
    }, config);
    assert.deepEqual(packet.neighbors, []);
  } finally {
    cleanup();
  }
});

test("automatic retrieval quarantines invalid, noncanonical, and sensitive records", () => {
  const { config, betaPath, cleanup } = fixture();
  const invalidId = "33333333-3333-3333-3333-333333333333";
  const noncanonicalId = "44444444-4444-4444-4444-444444444444";
  const sensitiveId = "55555555-5555-5555-5555-555555555555";
  const sensitiveMarker = "FAKE_METADATA_SECRET_1234567890";
  try {
    writeFileSync(join(config.vaultRoot, "10 Records", "note", `${invalidId}.md`), `---
schema: vault-note/v2
id: ${invalidId}
title: Invalid schema zeta marker
kind: note
pinned: true
canonical: true
---

# Invalid schema zeta marker
`, "utf8");
    writeFileSync(join(config.vaultRoot, "10 Records", "note", `${noncanonicalId}.md`), serializeMarkdown({
      schema: "vault-note/v2",
      id: noncanonicalId,
      title: "Noncanonical audit marker",
      kind: "note",
      lifecycle: "active",
      status: "current",
      summary: "Only explicit audit retrieval may return this.",
      priority: "P2",
      pinned: true,
      canonical: false,
      needs_curation: false,
      created: "2026-07-23",
      updated: "2026-07-23",
      scope_keys: ["topic:audit"],
      source_kind: "user",
      confidence: "medium",
    }, "# Noncanonical audit marker"), "utf8");
    writeFileSync(join(config.vaultRoot, "10 Records", "note", `${sensitiveId}.md`), serializeMarkdown({
      schema: "vault-note/v2",
      id: sensitiveId,
      title: "Sensitive quarantine marker",
      kind: "note",
      lifecycle: "active",
      status: `password=${sensitiveMarker}`,
      summary: "token=FAKE_TEST_MARKER_1234567890",
      priority: "P2",
      pinned: true,
      canonical: true,
      needs_curation: false,
      created: "2026-07-23",
      updated: "2026-07-23",
      scope_keys: ["topic:quarantine"],
      source_kind: "user",
      confidence: "medium",
      origin: `token=${sensitiveMarker}`,
    }, "# Sensitive quarantine marker"), "utf8");
    reindex(config);
    const sensitivePath = `10 Records/note/${sensitiveId}.md`;
    const sensitiveHash = sqliteRows(config, `SELECT content_sha256 FROM notes WHERE path='${sensitivePath}'`)[0].content_sha256;
    const legacyEmbeddingMarker = "LEGACY_SECRET_EMBEDDING_MARKER";
    const legacyInsert = spawnSync("sqlite3", [config.indexPath, `INSERT INTO embeddings(path,model,dimensions,vector,source_hash,updated_at) VALUES ('${sensitivePath}','legacy',1,X'${Buffer.from(legacyEmbeddingMarker).toString("hex")}','${sensitiveHash}','2026-07-23T00:00:00')`], { encoding: "utf8" });
    assert.equal(legacyInsert.status, 0, legacyInsert.stderr);
    reindex(config);
    assert.equal(sqliteRows(config, `SELECT COUNT(*) AS count FROM embeddings WHERE path='${sensitivePath}'`)[0].count, 0);
    assert.equal(readFileSync(config.indexPath).includes(Buffer.from(legacyEmbeddingMarker)), false);
    const staleIndexMarker = "STALE_INDEX_REDACTION_MARKER";
    const staleUpdate = spawnSync("sqlite3", [config.indexPath, `UPDATE notes SET status='${staleIndexMarker}' WHERE path='${sensitivePath}'; UPDATE index_meta SET value='obsolete' WHERE key='index_format_revision';`], { encoding: "utf8" });
    assert.equal(staleUpdate.status, 0, staleUpdate.stderr);
    const refreshed = ensureFreshIndex(config);
    assert.equal(refreshed.fresh, undefined);
    assert.equal(sqliteRows(config, `SELECT status FROM notes WHERE path='${sensitivePath}'`)[0].status, null);
    assert.equal(readFileSync(config.indexPath).includes(Buffer.from(staleIndexMarker)), false);
    assert.deepEqual(startup({}, config).results.map((row) => row.path), [betaPath]);
    assert.equal(search("Invalid schema zeta marker", {}, config).results.length, 0);
    assert.equal(search("Invalid schema zeta marker", { includeInvalid: true }, config).results[0].id, invalidId);
    assert.equal(search("Noncanonical audit marker", {}, config).results.length, 0);
    assert.equal(search("Noncanonical audit marker", { includeNoncanonical: true }, config).results[0].id, noncanonicalId);
    assert.equal(
      search("Sensitive quarantine marker", { includeInvalid: true, includeNoncanonical: true }, config).results.some((row) => row.id === sensitiveId),
      false,
    );
    const stored = sqliteRows(config, `SELECT id,title,summary,status,origin,source_kind,confidence,length(body) AS body_length,sensitive_suspected FROM notes WHERE path='10 Records/note/${sensitiveId}.md'`)[0];
    assert.equal(stored.id, null);
    assert.equal(stored.title, "[sensitive note quarantined]");
    assert.equal(stored.status, null);
    assert.equal(stored.origin, null);
    assert.equal(stored.source_kind, null);
    assert.equal(stored.confidence, null);
    assert.equal(stored.body_length, 0);
    assert.equal(stored.sensitive_suspected, 1);
    assert.equal(readFileSync(config.indexPath).includes(Buffer.from(sensitiveMarker)), false);
    const report = quality({}, config);
    assert.equal(report.summary.sensitive_quarantined, 1);
    assert.equal(report.summary.noncanonical_quarantined, 1);
    assert.equal(report.summary.missing_scope_or_project, 0);
  } finally {
    cleanup();
  }
});

test("malformed sensitive frontmatter never leaks through validation output", () => {
  const { config, cleanup } = fixture();
  const marker = "FAKE_SECRET_DO_NOT_USE_1234567890";
  try {
    const path = join(config.vaultRoot, "10 Records", "note", "malformed-sensitive.md");
    writeFileSync(path, `---
title: Malformed sensitive
password: ${marker}
invalid: [unterminated
---

# Malformed sensitive
`, "utf8");
    reindex(config);
    const report = quality({}, config);
    assert.equal(report.summary.sensitive_quarantined, 1);
    assert.equal(report.summary.schema_violations, 0);
    assert.doesNotMatch(JSON.stringify(report), new RegExp(marker));
    assert.doesNotMatch(JSON.stringify(search("Malformed sensitive", { includeInvalid: true }, config)), new RegExp(marker));
  } finally {
    cleanup();
  }
});

test("daily generation rejects invalid dates before resolving any output path", () => {
  const { config, alphaPath, cleanup } = fixture();
  try {
    reindex(config);
    const original = readFileSync(join(config.vaultRoot, alphaPath), "utf8");
    assert.throws(
      () => generateDaily({ date: `2026/../../${alphaPath.replace(/\.md$/, "")}` }, config),
      /valid YYYY-MM-DD/,
    );
    assert.throws(() => generateDaily({ date: "2026-02-30" }, config), /valid YYYY-MM-DD/);
    assert.equal(readFileSync(join(config.vaultRoot, alphaPath), "utf8"), original);
  } finally {
    cleanup();
  }
});

test("raw processing fails closed for missing or changed integrity metadata", () => {
  const { config, cleanup } = fixture();
  const plainPath = "00 Inbox/raw/2026/07/plain.md";
  try {
    mkdirSync(join(config.vaultRoot, "00 Inbox", "raw", "2026", "07"), { recursive: true });
    writeFileSync(join(config.vaultRoot, plainPath), "# Plain external drop\n\nNo seal.", "utf8");
    reindex(config);
    const plain = inbox({ limit: 20 }, config).results.find((row) => row.path === plainPath);
    assert.equal(plain.immutable_ok, false);
    assert.equal(plain.processable, false);
    assert.throws(() => processRaw({ target: plainPath, kind: "note" }, config), /quarantined|integrity|immutable/);

    const captured = captureRaw({ title: "Tamper test", text: "Original voice" }, config);
    writeFileSync(join(config.vaultRoot, captured.path), `${readFileSync(join(config.vaultRoot, captured.path), "utf8")}\n`, "utf8");
    reindex(config);
    const changed = inbox({ limit: 20 }, config).results.find((row) => row.path === captured.path);
    assert.equal(changed.immutable_ok, false);
    assert.throws(() => processRaw({ target: captured.path, kind: "note" }, config), /integrity check failed/);

    const lineEndingCapture = captureRaw({ title: "Line ending tamper", text: "Original LF voice" }, config);
    const lineEndingPath = join(config.vaultRoot, lineEndingCapture.path);
    const originalLf = readFileSync(lineEndingPath, "utf8");
    writeFileSync(lineEndingPath, originalLf.replace(/\n/g, "\r\n"), "utf8");
    reindex(config);
    const lineEndingChanged = inbox({ limit: 20 }, config).results.find((row) => row.path === lineEndingCapture.path);
    assert.equal(lineEndingChanged.immutable_ok, false);
    assert.equal(lineEndingChanged.processable, false);
    assert.throws(() => processRaw({ target: lineEndingCapture.path, kind: "note" }, config), /integrity check failed/);
  } finally {
    cleanup();
  }
});

test("raw processing recovers from a receipt write failure without duplicating output", () => {
  const { config, cleanup } = fixture();
  try {
    reindex(config);
    const raw = captureRaw({ title: "Crash recovery", text: "Safe raw body" }, config);
    const today = todayInZone();
    const yearDir = join(config.vaultRoot, "00 Inbox", "receipts", today.slice(0, 4));
    const blockedMonth = join(yearDir, today.slice(5, 7));
    mkdirSync(yearDir, { recursive: true });
    writeFileSync(blockedMonth, "block directory creation", "utf8");
    const before = readdirSync(join(config.vaultRoot, "10 Records", "note")).length;
    assert.throws(
      () => processRaw({ target: raw.path, kind: "note", title: "Recovered output", summary: "Recovered safely", body: "Clean body", scopeKeys: ["project:test"] }, config),
    );
    const afterFailure = readdirSync(join(config.vaultRoot, "10 Records", "note")).length;
    assert.equal(afterFailure, before + 1);
    rmSync(blockedMonth);
    const recovered = processRaw({ target: raw.path, kind: "risk", title: "Ignored retry title", summary: "Ignored", body: "Ignored", scopeKeys: ["project:test"] }, config);
    assert.equal(recovered.recovered, true);
    assert.equal(readdirSync(join(config.vaultRoot, "10 Records", "note")).length, afterFailure);
    assert.equal(processRaw({ target: raw.path }, config).idempotent, true);
  } finally {
    cleanup();
  }
});

test("typed relations are writable and metadata edits invalidate cached embeddings", () => {
  const { config, alphaPath, cleanup } = fixture();
  try {
    reindex(config);
    const linked = capture({
      title: "Typed relation record",
      kind: "decision",
      summary: "Confirmed typed relation.",
      scopeKeys: ["project:test"],
      supports: [`[[${alphaPath.replace(/\.md$/, "")}]]`],
    }, config);
    assert.deepEqual(fetchNote(linked.path, config).properties.supports, [`[[${alphaPath.replace(/\.md$/, "")}]]`]);

    const chunk = sqliteRows(config, `SELECT chunk_id,embedding_source_sha256 FROM chunks WHERE path='${alphaPath}' ORDER BY ordinal LIMIT 1`)[0];
    spawnSync("sqlite3", [config.indexPath, `INSERT INTO chunk_embeddings(path,chunk_id,model,dimensions,vector,source_hash,updated_at) VALUES ('${alphaPath}','${chunk.chunk_id}','qwen3-embedding:0.6b',1,X'00000000','${chunk.embedding_source_sha256}','2026-07-23T00:00:00')`], { encoding: "utf8" });
    const alphaSource = readFileSync(join(config.vaultRoot, alphaPath), "utf8");
    writeFileSync(join(config.vaultRoot, alphaPath), alphaSource.replace("title: Obsidian検索の設計判断", "title: Obsidian検索の更新判断"), "utf8");
    reindex(config);
    assert.equal(sqliteRows(config, `SELECT COUNT(*) AS count FROM chunk_embeddings WHERE path='${alphaPath}'`)[0].count, 0);
    const summaryChunks = sqliteRows(config, `SELECT COUNT(*) AS count FROM chunks WHERE path='${alphaPath}' AND heading='Summary'`)[0].count;
    assert.equal(summaryChunks, 1);
    assert.equal(health(config).semantic_index.complete, false);
  } finally {
    cleanup();
  }
});

test("semantic search rejects empty evidence without calling the embedding service", async () => {
  const { config, cleanup } = fixture();
  try {
    reindex(config);
    const result = await semanticSearch("", {}, config);
    assert.equal(result.insufficient_evidence, true);
    assert.deepEqual(result.results, []);
    await assert.rejects(
      semanticSearch("query", { minimumSimilarity: 1.01 }, config),
      /minimumSimilarity must be a finite number from 0 to 1/,
    );
    await assert.rejects(
      semanticSearch("query", { minimumSimilarity: Number.NaN }, config),
      /minimumSimilarity must be a finite number from 0 to 1/,
    );
  } finally {
    cleanup();
  }
});

test("weekly synthesis rejects secret-like narrative input", () => {
  const { config, cleanup } = fixture();
  try {
    reindex(config);
    assert.throws(
      () => generateWeekly({ date: "2026-07-23", narrative: "password=FAKE_TEST_MARKER_1234567890" }, config),
      /capture was rejected/,
    );
    assert.throws(
      () => generateWeekly({ date: "2026-07-23", narrative: "Authorization: ApiKey 0123456789abcdef0123456789abcdef" }, config),
      /capture was rejected/,
    );
  } finally {
    cleanup();
  }
});

test("Asia/Tokyo date boundary is stable", () => {
  assert.equal(todayInZone(new Date("2026-07-22T14:59:59Z")), "2026-07-22");
  assert.equal(todayInZone(new Date("2026-07-22T15:00:00Z")), "2026-07-23");
});

test("CLI exposes top-level help without requiring a Vault", () => {
  const cli = new URL("../src/cli.mjs", import.meta.url);
  const result = spawnSync(process.execPath, [cli.pathname, "--help"], { encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /^Usage:/);
  assert.equal(result.stderr, "");
});

test("migration apply refuses an empty legacy source without overwriting its manifest", () => {
  const vaultRoot = mkdtempSync(join(tmpdir(), "vault-context-empty-migration-"));
  const manifestPath = join(vaultRoot, "90 System", "Migrations", `v2-migration-${todayInZone()}.json`);
  const original = '{"sentinel":"preserve-me"}\n';
  try {
    mkdirSync(join(vaultRoot, "90 System", "Migrations"), { recursive: true });
    writeFileSync(manifestPath, original, "utf8");
    const script = new URL("../scripts/migrate-v2.mjs", import.meta.url);
    const result = spawnSync(process.execPath, [script.pathname, "--apply", "--vault", vaultRoot], { encoding: "utf8" });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /no legacy source records/);
    assert.equal(readFileSync(manifestPath, "utf8"), original);
  } finally {
    rmSync(vaultRoot, { recursive: true, force: true });
  }
});

test("migration apply preflights canonical destination collisions without changing either file", () => {
  const vaultRoot = mkdtempSync(join(tmpdir(), "vault-context-migration-collision-"));
  const id = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
  const sourcePath = join(vaultRoot, "10 Context", "Items", "note", "legacy.md");
  const destinationPath = join(vaultRoot, "10 Records", "note", `${id}.md`);
  const source = `---
id: ${id}
title: Legacy migration source
type: note
status: 進行中
---

# Legacy migration source

Body.
`;
  const sentinel = "# existing canonical sentinel\n";
  try {
    mkdirSync(join(vaultRoot, "10 Context", "Items", "note"), { recursive: true });
    mkdirSync(join(vaultRoot, "10 Records", "note"), { recursive: true });
    writeFileSync(sourcePath, source, "utf8");
    writeFileSync(destinationPath, sentinel, "utf8");
    const script = new URL("../scripts/migrate-v2.mjs", import.meta.url);
    const result = spawnSync(process.execPath, [script.pathname, "--apply", "--vault", vaultRoot], { encoding: "utf8" });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /destinations conflict/);
    assert.equal(readFileSync(sourcePath, "utf8"), source);
    assert.equal(readFileSync(destinationPath, "utf8"), sentinel);
    assert.equal(existsSync(join(vaultRoot, "90 System", "Migrations", `v2-migration-${todayInZone()}.json`)), false);
  } finally {
    rmSync(vaultRoot, { recursive: true, force: true });
  }
});

test("migration apply rejects a symlinked legacy root without reading or deleting outside files", () => {
  const vaultRoot = mkdtempSync(join(tmpdir(), "vault-context-migration-symlink-"));
  const outside = mkdtempSync(join(tmpdir(), "vault-context-migration-outside-"));
  const sourcePath = join(outside, "legacy.md");
  const source = `---
id: bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
title: Outside legacy source
type: note
status: 進行中
---

# Outside legacy source
`;
  try {
    mkdirSync(join(vaultRoot, "10 Context"), { recursive: true });
    writeFileSync(sourcePath, source, "utf8");
    symlinkSync(outside, join(vaultRoot, "10 Context", "Items"), "dir");
    const script = new URL("../scripts/migrate-v2.mjs", import.meta.url);
    const result = spawnSync(process.execPath, [script.pathname, "--apply", "--vault", vaultRoot], { encoding: "utf8" });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /symlink|escapes the configured vault/);
    assert.equal(readFileSync(sourcePath, "utf8"), source);
    assert.equal(existsSync(join(vaultRoot, "10 Records", "note", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.md")), false);
  } finally {
    rmSync(vaultRoot, { recursive: true, force: true });
    rmSync(outside, { recursive: true, force: true });
  }
});

test("migration apply still succeeds for a regular in-vault legacy source", () => {
  const vaultRoot = mkdtempSync(join(tmpdir(), "vault-context-migration-success-"));
  const id = "cccccccccccccccccccccccccccccccc";
  const sourcePath = join(vaultRoot, "10 Context", "Items", "legacy.md");
  const destinationPath = join(vaultRoot, "10 Records", "note", `${id}.md`);
  try {
    mkdirSync(dirname(sourcePath), { recursive: true });
    writeFileSync(sourcePath, `---
id: ${id}
title: Safe legacy source
type: note
status: 進行中
---

# Safe legacy source

Body.
`, "utf8");
    const script = new URL("../scripts/migrate-v2.mjs", import.meta.url);
    const result = spawnSync(process.execPath, [script.pathname, "--apply", "--vault", vaultRoot], { encoding: "utf8" });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(existsSync(sourcePath), false);
    assert.equal(existsSync(destinationPath), true);
    assert.equal(existsSync(join(vaultRoot, "90 System", "Migrations", `v2-migration-${todayInZone()}.json`)), true);
  } finally {
    rmSync(vaultRoot, { recursive: true, force: true });
  }
});
