# Routing policy

## Native-first defaults

Use native delegation whenever the visible `spawn_agent` schema advertises the required model and effort.

| Tier | Default backend | Preferred model | Effort | Use |
| --- | --- | --- | --- | --- |
| `fast` | native | `gpt-5.6-luna` | `xhigh` | Scans, deterministic checks, tightly specified small work |
| `standard` | native | `gpt-5.6-terra` | `xhigh` | Normal implementation, integration, debugging, tests |
| `deep` | native | `gpt-5.6-terra` | `max` | Bounded high-risk implementation or ambiguous failure investigation |
| `review` | native | `gpt-5.6-luna` | `max` | Independent final or high-risk review |

Use `fork_turns: "none"` for every model/effort override and for context offload. Pass a self-contained packet instead of parent history.

`subagent-model-router` is an instruction skill, not a callable router tool. Its presence is established by loading `SKILL.md`; runtime route availability is established from the visible native schema and, only when needed, the filtered CLI catalog. Do not call the policy unavailable merely because there is no same-named tool.

The CLI runner remains available for a bounded leaf when the required Terra or Luna route is absent from the native schema or the user explicitly requests CLI. It queries `codex debug models`, permits only Terra/Luna with `xhigh` or `max`, and fails instead of falling back to Sol or a lower effort. Record backend, model, and effort in the packet.

Override precedence:

1. `--model`
2. `CODEX_SUBAGENT_MODEL_FAST`, `CODEX_SUBAGENT_MODEL_STANDARD`, `CODEX_SUBAGENT_MODEL_DEEP`, or `CODEX_SUBAGENT_MODEL_REVIEW`
3. The preferred candidates bundled in the runner

`--reasoning-effort` overrides the tier default but must remain `xhigh` or `max`. The runner verifies that the resolved model supports it.

## Backend rules

- Prefer native `spawn_agent` whenever its visible schema exposes a suitable resolved model and reasoning effort.
- Set `fork_turns` to `none` whenever model or reasoning is overridden.
- Also set `fork_turns` to `none` when delegation is intended to offload parent context; provide a self-contained packet instead of inheriting the conversation.
- Use the CLI runner only for an explicit CLI request or an isolated leaf whose selected Terra/Luna model is absent from the native schema. It disables nested multi-agent features and creates a leaf worker with an actual `codex exec --model` argument.
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
- Reasoning failure: `fast` Luna/xhigh -> `standard` Terra/xhigh -> `deep` Terra/max.
- Review disagreement: inspect the authoritative source in the parent, then retry the bounded review at Luna/max only if uncertainty remains.
