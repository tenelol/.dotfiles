---
name: subagent-model-router
description: Route packets from a parent-owned plan to explicit gpt-5.6-terra or gpt-5.6-luna workers at xhigh or max effort. Use for subagents, parallel work, model distribution, independent review, or per-task model control. This is a routing policy applied through spawn_agent, not a separately callable router tool.
---

# Subagent Model Router

This skill is the routing policy the parent applies; it is not a tool named `subagent-model-router`. Do not report the skill as unavailable merely because no same-named callable tool exists. Inspect the visible `spawn_agent` schema and pass the selected model and effort directly.

The parent owns the task plan, packet split, model assignment, permissions, integration, verification, and final answer. Route only bounded work that benefits from isolated context or parallelism. Keep small critical-path tasks and planning in the parent.

## Route the packet

Classify every delegated packet before dispatch:

- `fast`: read-heavy discovery, deterministic checks, or mechanical one-to-two-file work with a complete specification.
- `standard`: normal implementation, multi-file integration, debugging, tests, or ordinary review.
- `deep`: bounded high-risk implementation, ambiguous failure investigation, security, concurrency, or migrations after the parent has set the plan.
- `review`: independent correctness, security, or release review.

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

Do not ask the child to create the overall plan and do not rely on parent history. Pass only the context needed for that packet.

## Choose the backend

Inspect the visible `spawn_agent` schema.

### Native backend

If the schema exposes `model` and `reasoning_effort`, pass both actual arguments. Use these routes:

- `fast`: `gpt-5.6-luna` / `xhigh`
- `standard`: `gpt-5.6-terra` / `xhigh`
- `deep`: `gpt-5.6-terra` / `max`
- `review`: `gpt-5.6-luna` / `max`

Do not use Sol for a child and do not silently lower effort. When overriding either value, use `fork_turns: "none"`; full-history forks inherit the parent configuration and reject overrides.

```json
{
  "task_name": "scan_api",
  "message": "<self-contained packet>",
  "fork_turns": "none",
  "model": "gpt-5.6-luna",
  "reasoning_effort": "xhigh"
}
```

Default to the native backend whenever its visible schema advertises the selected Terra or Luna route. Native Luna is valid when the schema exposes it. This preserves agent-tree coordination, follow-ups, waiting, and UI visibility.

### CLI backend

Use the CLI backend only when the selected Terra or Luna route is absent from the native schema but picker-visible in the filtered CLI catalog, or when the user explicitly requests a CLI leaf. Check both backends before reporting the requested route unavailable. Do not silently move an explicit native-model request to CLI. The bundled leaf worker invokes `codex exec --model <resolved-model>` with an explicit reasoning override:

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
- Run an independent `review` packet at Luna/max for risky or broad changes when review is warranted.
- Never use `ultra` for CLI leaf workers; it can trigger recursive delegation.

When using `codex-dynamic-workflows`, let that skill own packet planning, integration, and verification. Use this skill only to attach `tier`, `model`, `reasoning_effort`, and backend to each packet.
