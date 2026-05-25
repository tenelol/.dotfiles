---
name: imoocs
description: Use when working with INIAD MOOCs slides or lecture pages through the local `collect-cli` from yu7400ki/moocs-collect. Trigger on INIAD, MOOCs, moocs.iniad.org, スライド, 授業資料, lecture material, course slides, or requests to download/organize INIAD MOOCs PDFs; prefer the CLI over browser or Playwright workflows.
---

# INIAD MOOCs Slide Collection

## Overview

Use the unofficial Rust CLI `collect-cli` from `yu7400ki/moocs-collect` to download INIAD MOOCs slides as PDFs. This tool is interactive and is for slide/material retrieval, not assignment submission.

## Core Rules

1. Use `collect-cli` before browser or Playwright workflows for INIAD MOOCs slide downloads.
2. Do not manually parse MOOCs URLs. `collect-cli` is interactive and does not accept direct MOOCs URLs; if a URL is provided, explain that the CLI needs course selection instead of URL parsing.
3. Do not search for, print, save, or ask the user to paste passwords, tokens, cookies, or other credentials. Login should happen through the CLI prompt in the user's TTY.
4. Treat this skill as read-only slide/material retrieval. `moocs-collect` does not provide assignment submit/upload/push, attendance, Drive, `open`, or JSON-envelope commands.

## CLI Health

Start by checking availability when it is not already known:

```bash
command -v collect-cli
collect-cli --help
```

If `collect-cli` is missing, stop the MOOCs operation and report that the `moocs-collect-cli` package is required. Do not switch to browser operation silently.

Known install paths from upstream documentation:

```bash
cargo install --git https://github.com/yu7400ki/moocs-collect.git collect-cli
```

In this dotfiles repo, `collect-cli` is packaged through Home Manager as `moocs-collect-cli`.

## Usage

Basic invocation:

```bash
collect-cli --path /path/to/download-dir --year 2025
```

The CLI then prompts interactively for:

- INIAD username
- password, stored via OS keyring by upstream tool
- course
- lecture
- page

Use a concrete download directory. If the user does not specify one, choose a stable local directory for the current task and report it.

`collect-cli` does not emit stable JSON. Judge success by exit code and generated PDF files.

## Workflow

1. Confirm the user wants slides/material PDFs, not assignment or Drive operations.
2. Check `collect-cli --help`.
3. Run `collect-cli --path <dir> --year <year>` only when interactive TTY operation is appropriate.
4. After completion, inspect the output directory and report generated PDF paths or counts.
5. If the user asks for assignment submission, attendance, Drive files, or direct URL routing, say that `moocs-collect` does not support that surface.

## URL Handling

When a `moocs.iniad.org` URL appears:

- Do not parse the URL manually.
- Do not use browser automation just to inspect it.
- Explain that `collect-cli` selects by year/course/lecture/page and ask for the target year or let the user select interactively.

## Unsupported Surfaces

`moocs-collect` is not an assignment automation CLI. Do not claim it can:

- submit assignments
- stage drafts
- push final submissions
- mark attendance
- fetch Google Drive handouts
- return JSON envelopes
- route arbitrary URLs with an `open` subcommand

## Final Report

Always state one of these outcomes clearly:

- `何もしていない`: no submission/stage/push was performed.
- `stage だけした`: not applicable to `moocs-collect`; only use this if another explicit submission tool was used.
- `push で確定した`: not applicable to `moocs-collect`; do not report this for `collect-cli`.

For normal `collect-cli` work, report downloaded slide/material paths and state that no assignment submission was performed.
