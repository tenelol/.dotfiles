import { basename } from "node:path";
import { spawnSync } from "node:child_process";

const STOPWORDS = new Set([
  "feature", "feat", "fix", "bugfix", "hotfix", "chore", "docs", "doc",
  "test", "tests", "refactor", "wip", "main", "master", "develop", "dev",
  "issue", "issues", "pull", "pr",
]);

function runGit(cwd, args) {
  const result = spawnSync("git", args, { cwd, encoding: "utf8" });
  return result.status === 0 ? result.stdout.trim() : "";
}

export function tokenize(value, { keepStopwords = false, maxTokens = 12 } = {}) {
  const words = String(value || "").normalize("NFKC").toLowerCase().match(/[\p{L}\p{N}]+/gu) || [];
  const out = [];
  for (const word of words) {
    if (word.length < 2 || (!keepStopwords && STOPWORDS.has(word))) continue;
    if (!out.includes(word)) out.push(word);
    if (out.length >= maxTokens) break;
  }
  return out;
}

export function parseRemoteUrl(remoteUrl) {
  const raw = String(remoteUrl || "").trim();
  if (!raw) return {};
  const scpLike = raw.match(/^(?:[^@]+@)?([^:]+):(.+)$/);
  if (scpLike && !raw.includes("://")) {
    const parts = scpLike[2].replace(/\.git$/, "").split("/").filter(Boolean);
    return { host: scpLike[1], owner: parts.at(-2) || "", repo: parts.at(-1) || "" };
  }
  try {
    const url = new URL(raw);
    const parts = url.pathname.replace(/^\/+/, "").replace(/\.git$/, "").split("/").filter(Boolean);
    return { host: url.hostname, owner: parts.at(-2) || "", repo: parts.at(-1) || "" };
  } catch {
    const parts = raw.replace(/\.git$/, "").split(/[/:]/).filter(Boolean);
    return { owner: parts.at(-2) || "", repo: parts.at(-1) || basename(raw) };
  }
}

function issueTokens(...values) {
  const found = [];
  for (const match of values.filter(Boolean).join(" ").matchAll(/(?:^|[^a-z0-9])(?:gh|issue|pr|pull)?[-_#/]?(\d{2,7})(?=$|[^a-z0-9])/gi)) {
    const token = `issue-${match[1]}`;
    if (!found.includes(token)) found.push(token);
  }
  return found.slice(0, 5);
}

function unique(values) {
  return values.filter((value, index) => value && values.indexOf(value) === index);
}

export function deriveContextKey({ cwd = process.cwd(), task = "", extra = "" } = {}) {
  const gitRoot = runGit(cwd, ["rev-parse", "--show-toplevel"]);
  const gitCwd = gitRoot || cwd;
  const branch = runGit(gitCwd, ["branch", "--show-current"]);
  const remoteUrl = runGit(gitCwd, ["remote", "get-url", "origin"]) || runGit(gitCwd, ["config", "--get", "remote.origin.url"]);
  const remote = parseRemoteUrl(remoteUrl);
  const repoName = remote.repo || (gitRoot ? basename(gitRoot) : basename(cwd || process.cwd()));
  const issues = issueTokens(branch, task, extra);
  const components = unique([
    ...tokenize(remote.owner, { keepStopwords: true, maxTokens: 3 }),
    ...tokenize(repoName, { keepStopwords: true, maxTokens: 5 }),
    ...issues,
    ...tokenize(branch, { maxTokens: 8 }),
    ...tokenize(`${task} ${extra}`, { maxTokens: 8 }),
  ]);
  const key = components.join(" ").slice(0, 240);
  return {
    key,
    components,
    repo: repoName || "",
    owner: remote.owner || "",
    host: remote.host || "",
    branch: branch || "",
    issue_tokens: issues,
    task_terms: tokenize(`${task} ${extra}`, { maxTokens: 8 }),
    git_root: gitRoot || "",
    warnings: key ? [] : ["Could not derive a useful key; pass --task or --extra."],
  };
}
