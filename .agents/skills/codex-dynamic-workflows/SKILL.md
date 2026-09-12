---
name: codex-dynamic-workflows
description: "複数の作業系統を持つ長期作業で、明示的な進行管理や委譲の調整が必要なときに使う。"
---

# AI Agent Dynamic Workflows

Use explicit orchestration for a task with independent work streams or continuity needs that benefit from it. Keep ordinary work local without a workflow scaffold.

- Keep the full objective, acceptance criteria and integration decisions in the parent.
- Delegate only useful bounded work through `subagent-model-router`. When delegation is unavailable or unwanted, do the work locally; do not create simulated agents or claim independent review.
- Use goal tools only when the user explicitly requests a goal. Long or difficult work alone is not a goal-mode request.
- Continue authorized implementation and targeted verification until the agreed outcome is complete. Reuse existing authorization; ask only about unresolved scope or external/destructive operations not already authorized.
- Use a small progress artifact when work must survive handoff or compaction. Do not scaffold a directory tree for every task.

## Optional workflow artifacts

When durable orchestration is useful, use the existing `scripts/new_workflow.py` scaffold and [plan schema](references/plan-schema.md). Its `.workflow/<slug>/` layout contains a plan, state, packets and results. Keep only artifacts with a concrete continuation or verification purpose.

`collect_results.py` prepares a checklist from result files; `verify_workflow.py` checks scaffold completeness. They do not prove the implementation correct. Validate the actual changed behavior separately.

Read [risk boundaries](references/risk-gates.md) only when the authorization boundary is unclear, and [validation examples](references/validation-examples.md) only when developing this workflow. Save reusable context through the project's configured context protocol rather than a parallel memory store.
