# Routing policy

## Native-first defaults

Use native delegation whenever the visible `spawn_agent` schema advertises the required model and effort.

| Tier | Default backend | Preferred model | Effort | Use |
| --- | --- | --- | --- | --- |
| `fast` | native | `gpt-5.6-terra` | `low` | Scans, deterministic checks, tightly specified small work |
| `standard` | native | `gpt-5.6-terra` | `medium` | Normal implementation, integration, debugging, tests |
| `deep` | native | `gpt-5.6-sol` | `xhigh` | Architecture, ambiguity, security, concurrency, migrations |
| `review` | native | `gpt-5.6-sol` | `max` | Independent final or high-risk review |

Use `fork_turns: "none"` for every model/effort override and for context offload. Pass a self-contained packet instead of parent history.

The CLI runner remains available for an explicitly selected bounded leaf. It queries `codex debug models`, resolves CLI `fast -> gpt-5.6-luna/low`, and validates all fallback candidates. CLI Luna is explicit/exceptional; it is not selected merely to reduce parent context. Record backend, model, and effort in the packet. An explicit unavailable backend/model combination fails instead of falling back.

Override precedence:

1. `--model`
2. `CODEX_SUBAGENT_MODEL_FAST`, `CODEX_SUBAGENT_MODEL_STANDARD`, `CODEX_SUBAGENT_MODEL_DEEP`, or `CODEX_SUBAGENT_MODEL_REVIEW`
3. The preferred candidates bundled in the runner

`--reasoning-effort` overrides the tier default. The runner verifies that the resolved model supports it.

## Backend rules

- Prefer native `spawn_agent` whenever its visible schema exposes a suitable resolved model and reasoning effort.
- Set `fork_turns` to `none` whenever model or reasoning is overridden.
- Also set `fork_turns` to `none` when delegation is intended to offload parent context; provide a self-contained packet instead of inheriting the conversation.
- Use the CLI runner only for an explicit CLI/Luna request or an explicitly selected, isolated read-only one-shot whose required model is absent from the native schema. It disables nested multi-agent features and creates a leaf worker with an actual `codex exec --model` argument.
- Never print raw `codex debug models` JSON into the parent context; inspect only filtered slugs/capabilities or let the runner parse the catalog inside its subprocess.
- Do not enable experimental multi-agent features or edit global Codex configuration merely to reveal hidden tool fields.

## Write isolation

- Default to `read-only`.
- Allow `workspace-write` only with `--allow-write` and an explicit, disjoint write set.
- Do not run parallel writers against overlapping files.
- Use separate worktrees for broad implementation packets.
- Never bypass approvals or use a danger-full-access sandbox from the runner.

## Escalation

- Missing context: add evidence and retry the same tier.
- Excessive scope: split the packet before spending a stronger model.
- Reasoning failure: `fast` -> `standard` -> `deep`.
- Review disagreement: inspect the authoritative source locally, then use `deep` only if uncertainty remains.
