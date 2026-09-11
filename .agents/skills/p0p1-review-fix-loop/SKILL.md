---
name: p0p1-review-fix-loop
description: "Run a strict review-and-fix loop that creates a fresh subagent for every review pass, fixes actionable P0/P1 issues, and repeats until a fresh pass reports no P0/P1 findings. Use when the user asks to review and fix important bugs, eliminate P0/P1 findings, perform repeated independent reviews, harden a branch before PR/merge, or turn review feedback into code changes."
---

# P0/P1 Review Fix Loop

## Overview

Use this skill to separate independent review from implementation. A fresh subagent reviews the current code state for P0/P1 issues, the main agent triages and fixes confirmed actionable findings, and the cycle repeats until a new reviewer finds no P0/P1.

## Workflow

1. Read the repository instructions and current task context before changing files.
2. Establish the review target: current diff, branch versus base, issue scope, or explicit file set.
3. Run a fresh subagent review pass.
4. Triage findings in the main agent.
5. Fix confirmed actionable P0/P1 findings with the smallest coherent change.
6. Run targeted verification after each fix batch.
7. Repeat from step 3 with a new subagent until the latest pass reports no P0/P1.
8. Report iterations, fixed findings, verification, and remaining non-P0/P1 risks.

## Review Pass

Create a new subagent for every review pass. Do not reuse an earlier subagent, and do not ask the main agent to serve as the independent reviewer.

If multi-agent tools are not already visible, search for them with `tool_search`. If no multi-agent subagent mechanism is available, state that strict mode cannot be satisfied and ask for permission before using a fallback review. Do not create user-owned Codex threads unless the user explicitly asks for them.

Give the reviewer raw, task-local context:

- The repository path and review target.
- The user request and relevant repo instructions.
- Base branch or diff range when known.
- Expected verification commands when known.

Avoid leaking the intended fix, previous conclusions, or severity opinions unless the reviewer needs a prior unresolved finding to re-check.

Use this prompt shape:

```text
Review the current code for P0/P1 issues only.

Target: <repo/path, branch/diff/files>.
User request: <brief request>.
Instructions: follow repository instructions and focus on correctness, safety, data loss, security, release blockers, and high-impact regressions.

Return findings first, ordered by severity. For each finding include severity, file/line, concrete failure mode, why it is P0/P1, and a minimal fix direction. Do not modify files.
If there are no P0/P1 findings, say that clearly and mention any lower-severity risks separately.
```

## Severity

Treat P0/P1 narrowly. The loop is only complete when there are no confirmed P0/P1 findings.

P0 examples:

- Data loss, destructive migration, or irreversible corruption.
- Security vulnerability that exposes credentials, auth bypass, or broad unauthorized access.
- Build, startup, or core workflow failure that blocks release for normal environments.
- Runtime crash or incorrect behavior in the primary path with no practical workaround.

P1 examples:

- High-impact regression in a common workflow.
- Incorrect persistence, permissions, money, scheduling, migration, or external API behavior.
- Missing compatibility or error handling that will predictably fail in CI or production-like environments.
- Test gap that hides a confirmed P0/P1 behavior change.

Do not inflate style issues, small refactors, naming, minor performance, or speculative edge cases to P0/P1. Record them as lower-severity only when useful.

## Fix Policy

Fix confirmed P0/P1 findings when the change is safe and in scope. Keep edits small, follow existing patterns, and avoid unrelated refactors.

Before editing, inspect the relevant files yourself. Do not apply a subagent's recommendation blindly. If a finding is false-positive or not P0/P1, document the reason. Before declaring the loop clean, always run a fresh pass against the latest code state.

Preserve user changes and dirty worktree state. Do not revert unrelated files. For risky production, database, migration, or destructive changes, stop and get explicit user approval unless the user already authorized that exact operation.

## Verification

After each fix batch, run the narrowest meaningful verification first, then broader checks when the blast radius justifies them:

- Existing unit or integration tests covering the touched code.
- Lint/typecheck/build commands used by the repository.
- Migration dry-runs or generated SQL checks for data changes.
- Browser or simulator checks only when the user-facing surface requires them.

If a verification command cannot run, report the concrete reason and use the next best local check. Do not declare the loop clean solely because tests pass; a fresh subagent pass is still required.

## Stop Conditions

Stop only when a newly created subagent reviews the latest code state and reports no P0/P1 findings.

If the same confirmed P0/P1 cannot be fixed after repeated attempts because of missing credentials, unavailable services, ambiguous product requirements, or external state, report the blocker, the attempted fixes, and the safest next step instead of hiding or downgrading it.

Do not use a fixed maximum pass count while fixes are still making progress. If two consecutive cycles make no code or test progress on the same confirmed P0/P1, pause the loop, explain the repeated blocker, and ask for the missing decision or access.

## Final Response

Keep the final response concise:

- Number of fresh review passes.
- P0/P1 findings fixed or explicitly rejected as false positives.
- Verification commands and results.
- Remaining lower-severity findings or blocked items, if any.
