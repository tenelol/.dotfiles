---
name: subagent-model-router
description: Route delegated Codex work to explicit models and reasoning levels. Use when a user asks for subagents, parallel agents, a swarm, model selection, cheaper or faster workers, stronger review agents, or per-task model control. Prefer native spawn_agent with context-isolated packets; use bounded Codex CLI workers only when the user or packet explicitly requires a CLI-only model.
---

# Subagent Model Router

Route only work that benefits from isolated context or parallelism. Keep small critical-path tasks in the parent agent.

## Route the packet

Classify every delegated packet before dispatch:

- `fast`: read-heavy discovery, deterministic checks, or mechanical one-to-two-file work with a complete specification.
- `standard`: normal implementation, multi-file integration, debugging, tests, or ordinary review.
- `deep`: architecture, ambiguous failures, security, concurrency, migrations, broad synthesis, or final review.
- `review`: independent correctness, security, or release review. Treat this as `deep` unless the review is narrowly mechanical.

Read [references/routing-policy.md](references/routing-policy.md) for current model defaults, escalation, and write-isolation rules. Resolve the live catalog before dispatch; never silently inherit or silently downgrade when an explicit model was requested.

## Prepare a self-contained packet

Include:

```text
Objective:
Context and authoritative sources:
Files or directories in scope:
Allowed writes:
Do not:
Expected output:
Verification:
```

Do not rely on parent history when overriding a child model. Pass only the context needed for that packet.

## Choose the backend

Inspect the visible `spawn_agent` schema.

### Native backend

If the schema exposes `model` and `reasoning_effort`, pass both actual arguments. When overriding either value, use `fork_turns: "none"`; full-history forks inherit the parent configuration and reject overrides.

```json
{
  "task_name": "scan_api",
  "message": "<self-contained packet>",
  "fork_turns": "none",
  "model": "gpt-5.6-terra",
  "reasoning_effort": "low"
}
```

Default to the native backend whenever its visible schema advertises a suitable model. For `fast`, use native `gpt-5.6-terra/low` with `fork_turns: "none"`; this offloads parent context while preserving agent-tree coordination, follow-ups, waiting, and UI visibility. Do not pass a CLI-only model such as Luna to `spawn_agent`.

### CLI backend

Use the CLI backend only when the user explicitly requests CLI/Luna, or when the parent explicitly selects a fully isolated read-only one-shot whose required model is picker-visible in the filtered CLI catalog but absent from the native catalog. CLI Luna is an exception, not the `fast` default. Do not silently move an explicit native-model request to CLI. The bundled leaf worker invokes `codex exec --model <resolved-model>` with an explicit reasoning override:

```bash
python3 "$HOME/.codex/skills/subagent-model-router/scripts/run_model_agent.py" \
  --tier fast \
  --sandbox read-only \
  --cwd "$PWD" \
  --prompt-file work/packets/scan-api.md
```

For writes, assign a disjoint write set or separate worktree, then pass both `--sandbox workspace-write` and `--allow-write`. Prefer prompt files or stdin; do not interpolate untrusted prompt text into a shell command.

The CLI backend is an independent process. It cannot use native `wait_agent`, `send_message`, `followup_task`, or thread UI. Launch at most the useful concurrency for the task, normally two to four workers, then integrate their final outputs explicitly.

## Integrate and escalate

- Retry at the same tier when the worker only lacked context.
- Split the packet when it was too broad.
- Escalate one tier when reasoning or capability was insufficient.
- Verify worker claims against repository or runtime evidence.
- Run final review at `deep` for risky or broad changes.
- Never use `ultra` for CLI leaf workers; it can trigger recursive delegation.

When using `codex-dynamic-workflows`, let that skill own packet planning, integration, and verification. Use this skill only to attach `tier`, `model`, `reasoning_effort`, and backend to each packet.
