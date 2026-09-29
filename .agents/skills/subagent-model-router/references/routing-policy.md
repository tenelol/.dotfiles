# Model routing and backends

Every tier defaults to `gpt-6-sol` with `xhigh`. `max` requires an explicit override; there is no automatic effort escalation.

## Native first

When native `spawn_agent` exposes the selected model and effort, use it directly with `model`, `reasoning_effort` and `fork_turns: "none"`. Pass a bounded self-contained packet. Parent planning, permission decisions and integration are not delegated.

Only check the CLI catalog if the required native route is absent or the user explicitly asks for a CLI leaf. Do not run a second model lookup when the native schema already establishes availability.

## CLI leaf

The bundled `scripts/run_model_agent.py` uses `codex debug models` to filter picker-visible models. It only permits `gpt-6-sol`, with `xhigh` by default or explicitly requested `max`. It fails on unavailable or excluded models instead of silently inheriting another model.

```sh
python3 /path/to/subagent-model-router/scripts/run_model_agent.py \
  --tier fast --sandbox read-only --cwd /path/to/project \
  --prompt-file /path/to/packet.md
```

Existing CLI flags and tier names remain supported. `--model` overrides the tier environment variable (`CODEX_SUBAGENT_MODEL_FAST`, `STANDARD`, `DEEP`, `REVIEW`), which overrides the bundled default. `--reasoning-effort` overrides the tier effort. A configured model override must still be `gpt-6-sol`.

For writes, assign a disjoint write set or isolated worktree and pass both `--sandbox workspace-write` and `--allow-write`. Prompt files or stdin avoid shell interpolation. The CLI child is a leaf: it cannot delegate again or use native parent coordination tools. Do not bypass a no-subagent request through CLI.

## Failures

Add missing context or split an oversized packet before retrying. Keep the selected route unless the user explicitly changes it. If no allowed backend supports the requested model, report the limitation and continue useful parent work; an unavailable independent review remains unverified.
