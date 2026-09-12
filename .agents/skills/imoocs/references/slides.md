# スライド・講義資料

この手順内の `scripts/`・`references/`・`research/` は元のスキルルート基準。明示された作業ディレクトリはその指定に従う。

## Slides

Use the native lecture-material collector:

```bash
imoocs slide collect --path /path/to/download-dir --year 2025
```

This command uses stored `imoocs auth login` MOOCs and Google session cookies. It collects linked Google presentations as PDF, downloads linked Drive files directly, and recursively collects linked Drive folders. It never prompts for a password and never calls `collect-cli`. If no valid MOOCs session is stored, it returns an `auth_required` JSON envelope with `data.authScope: "moocs"`; recover with `imoocs auth login --keychain` in Codex desktop sessions, then retry only if auth succeeds. If it returns `data.authScope: "google_slides"` or `data.cookieStore: "google_expired"`, do not retry Keychain or `imoocs auth login` automatically because the MOOCs session is already usable and the blocker is Google Docs access. Instead, run `imoocs auth import-browser --browser auto`, then retry `slide collect`. To discard stale stored Google cookies and import the configured local browser profile in the same collection run, pass `--refresh-google`.

In an interactive TTY, missing `--course`, `--lecture`, or `--page` selectors are prompted as numbered menus. In non-interactive shells, pass selectors or explicit `--all`:

```bash
imoocs slide collect --path /path/to/download-dir --year 2025 --course COS101 --lecture all --page all
imoocs slide collect --path /path/to/download-dir --year 2025 --all
imoocs slide collect --path /path/to/download-dir --year 2025 --all --refresh-google
```

Selectors accept ids/slugs, names, 1-based indexes, or `all`; exact ids such as lessonId `13` or pageId `03` are preferred over menu indexes. Avoid `--all` for read-only inspection unless the user explicitly asks to collect broad materials.

If Google material export/download fails after browser-cookie import, or no Google material link is found, treat that JSON envelope as authoritative. Do not fall back to BrowserUse, Playwright, manual URL parsing, manual slide inspection, or `collect-cli` unless the user explicitly authorizes a fallback in the current turn.

If the user only asks to read, inspect, summarize, or verify PDFs, use a temporary directory from `mktemp -d` for `imoocs slide collect`, read the PDFs from there, and remove that directory in the same turn after extracting the needed information. Do not leave PDFs in `Downloads`, the repo, or another stable local directory for read-only tasks.

If the user explicitly asks to download, save, keep, organize, or reuse the PDFs later, choose a stable local directory for the task and report it.
