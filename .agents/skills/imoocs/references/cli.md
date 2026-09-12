この手順内の `scripts/`・`references/`・`research/` は元のスキルルート基準。明示された作業ディレクトリはその指定に従う。

# INIAD MOOCs

## Overview

Use the local `imoocs` command as the first interface for INIAD MOOCs work. In this dotfiles repo, `imoocs` is an agent-safe CLI for MOOCs operations; it enforces JSON envelopes, URL handling, and submission safety rules. Use it instead of BrowserUse, Playwright, or manual browser operations whenever the requested surface is supported.

Lecture-material collection is implemented in the local `imoocs` CLI. It discovers Google Slides, Drive files, and Drive folders from MOOCs page HTML, uses the stored `imoocs auth login` MOOCs and Google session cookies, and does not require `collect-cli`.

## Core Rules

1. When a `moocs.iniad.org` URL appears, run `imoocs open <url>` first. Do not open a browser or Playwright first.
2. Do not manually parse MOOCs URLs. Treat `imoocs open` as the URL router, even when the backend reports an unsupported envelope.
3. Treat `course`, `lesson`, `assignment`, `slide`, `drive`, and `open` command output as JSON envelopes.
4. Treat `auth *` and `reset` as text output plus exit code, not JSON.
5. Do not search for, print, save, or ask the user to paste passwords, tokens, cookies, or other credentials. `imoocs auth login` stores resulting MOOCs cookies in the local keyring. `imoocs auth import-browser` may import an existing local browser Google session into the same CLI cookie jar, but must never print cookie values. Google session failure does not invalidate a saved MOOCs session for assignment operations. In Codex desktop sessions, when MOOCs auth recovery is needed, try the existing INIAD Keychain credential; this does not require additional user permission. Supported Keychain items are the moocs-collect service `me.yu7400ki.moocs-collect` and, as fallback for the same username, the INIAD 802.1X Wi-Fi service `com.apple.network.eap.user.item.wlan.ssid.iniad`. Keychain reads must use a short timeout; if Keychain auth is unavailable, missing, rejected, or blocked, stop the auth/material operation and report the Keychain blocker instead of automatically using GUI, TTY, browser, or any other password flow.
6. Assignment submit/upload/push operations require explicit user instruction. Never infer permission from a request to inspect a course or assignment.
7. For assignments, enumerate every `assignments[]` entry returned for the target page, then verify each entry's `courseId`, `problemId`, `fields[].pid`, `currentAnswers` / `currentAnswerDetails` keys, current values, files, status, and deadline before any write operation. Treat `data.problem` and `route.problemId` only as backward-compatible aliases for the first entry.
8. Before solving or submitting a lesson assignment, read the lesson's embedded slides, linked slide deck, handouts, PDFs, notebooks, and data files needed to understand the actual questions. Do not rely only on the assignment form body; MOOCs forms often contain only answer fields. If the slide/material content cannot be obtained through supported local/CLI/Keychain-backed paths, stop and report exactly which material is blocked instead of guessing.
9. Do not use BrowserUse, Playwright, or a manual browser fallback unless the user explicitly authorizes that fallback after the CLI reports the operation is unsupported.

## username: s1F102501798

## CLI Health

Start by checking availability when it is not already known:

```bash
command -v imoocs
imoocs --version
imoocs --help
imoocs assignment --help
imoocs auth status
imoocs auth import-browser --help
```

If `imoocs` is missing, stop the MOOCs operation and report that the `imoocs` package is required. Do not silently switch to browser operation.

If auth status reports an expired or missing session in a Codex desktop session, recover with the existing INIAD Keychain credential every time. This path is allowed by default and does not require asking the user for permission. The CLI first checks `me.yu7400ki.moocs-collect`, then falls back to `com.apple.network.eap.user.item.wlan.ssid.iniad` for the same username:

```bash
imoocs auth login --keychain
```

When running this from Codex and `IMOOCS_USERNAME` is not already set, use the `username` value in this skill as `IMOOCS_USERNAME` for the current MOOCs task only.

If Keychain auth reports that no password was found, credentials were rejected, additional verification is required, or the command appears blocked on macOS Keychain access for more than a short wait, stop the MOOCs auth/material operation and report that Keychain auth is blocked. Do not launch the macOS hidden password dialog unless the user explicitly asks for GUI password entry in the current turn:

```bash
imoocs auth login --gui
```

Use the plain TTY prompt only when the user explicitly asks to type in the terminal:

```bash
imoocs auth login
```

`imoocs auth login --gui` opens a macOS hidden-answer dialog, `imoocs auth login` prompts for the password in the user's TTY, and `--keychain` reads an existing supported INIAD Keychain item for the current username without printing it. `imoocs` stores resulting MOOCs cookies in the local keyring and exits without attempting Google Slides or Drive by default. Assignment `open`, `show`, `submit`, and `push` use the MOOCs session. For Google Slides and Google Drive, use `imoocs auth import-browser --browser auto` to import existing local browser Google cookies into the CLI cookie jar; this is a CLI auth recovery path, not browser material inspection. Chrome profile discovery tries INIAD-looking profiles first; if auto-detection picks the wrong profile, use `imoocs auth import-browser --browser chrome --profile 'Profile 2'` or set `IMOOCS_BROWSER_PROFILE`. Normal `open`, `slide collect`, and `assignment` commands try to refresh an expired MOOCs session from the stored SSO cookies before returning `auth_required`; if that refresh fails, run `imoocs auth login` once again. Do not ask the user to paste the password into chat. Do not use GUI or TTY password flows as an automatic fallback from Keychain failure. `imoocs auth logout` removes those stored session cookies.

Never ask the user to paste credentials into chat. If the user wants to avoid typing a username repeatedly, tell them to set `IMOOCS_USERNAME` in their own shell. Use the `username` value in this skill only for `imoocs` commands in the current task; do not copy it into unrelated repo files or final-output command examples unless the user asks.
