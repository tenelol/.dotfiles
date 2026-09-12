---
name: p0p1-review-fix-loop
description: "P0/P1の修正と、新しい独立レビュアーによる再確認を繰り返す厳密なループの依頼に使う。"
---

# P0/P1 Review Fix Loop

Use this skill only for an explicitly requested strict loop of independent review and fixes. Ordinary bug review does not require this workflow.

1. Establish the requested diff, branch or file scope and its acceptance criteria.
2. Give a fresh read-only reviewer the request, repository instructions and raw evidence. Use the `review` route in `subagent-model-router`. Do not prime the reviewer with an expected finding or a proposed fix.
3. The parent verifies findings and fixes confirmed, in-scope P0/P1 defects, then runs targeted checks.
4. Obtain a fresh review of the updated state. Complete the strict loop when that review finds no confirmed P0/P1 defects.

P0/P1 means concrete high-impact correctness, security, data loss, core-path failure or release-blocking regression. Do not inflate style, speculative risks or mere test absence into severe defects.

Preserve existing authorization for fixes; do not wait for approval after each round. Ask only when fixing a confirmed problem requires an unapproved scope or action. Stop repeated attempts when the same blocker prevents meaningful progress, and report the missing evidence or decision.

If the user excludes subagents, or an independent reviewer is unavailable, perform useful local review and fixes within scope and disclose that the strict independent-review condition is not met. Do not start a CLI reviewer as a workaround for a no-subagent request, create user-owned tasks, or label a parent pass independent.

Report confirmed fixes, rejected false positives when relevant, verification, independent passes actually completed, and remaining limitations.
