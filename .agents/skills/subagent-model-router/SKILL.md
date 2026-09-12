---
name: subagent-model-router
description: "委譲する作業の責務に応じ、SolまたはTerraと推論強度を明示して子エージェントを起動するときに使う。"
---

# Subagent Model Router

Apply this policy only to a concrete bounded task whose parallel execution, independent review or context isolation will help. Model distribution alone is not a reason to delegate. Respect a no-subagent request.

The parent owns the overall plan, packet split, model assignment, permissions, integration and final verification. The skill is a policy applied through `spawn_agent`, not a separately callable router tool.

## Choose a responsibility

| Tier (existing CLI name) | Responsibility | Model | Default effort |
| --- | --- | --- | --- |
| `fast` | Research, summaries, document analysis, deterministic inspection | `gpt-5.6-sol` | `xhigh` |
| `standard` | Implementation, debugging, integration, test fixes | `gpt-5.6-terra` | `xhigh` |
| `deep` | Bounded complex implementation or failure investigation | `gpt-5.6-terra` | `xhigh` |
| `review` | Independent correctness or release review | `gpt-5.6-sol` | `xhigh` |

Luna is excluded. Use `max` only when explicitly requested; risk alone does not raise effort automatically.

## Dispatch and integrate

- Prefer native `spawn_agent` when its visible schema supports the chosen model and effort. Pass both arguments and `fork_turns: "none"` with a self-contained packet.
- Include the objective, current evidence, scope, allowed writes, constraints, expected result and verification. Do not delegate overall planning or rely on hidden parent history.
- Give editing workers disjoint write sets. Isolate Git branch/staging/commit operations in separate worktrees.
- Inspect worker claims against primary evidence and run the checks required by the changed artifact. Do not launch a duplicate review merely because another worker was used.
- If a selected model is unavailable, disclose it; do not silently substitute another model. Continue useful parent work. Claim independent review only when it actually occurred.

Read [backend and override details](references/routing-policy.md) only for CLI fallback, explicit overrides or availability failures. Read it before running the bundled CLI leaf. Native model availability is established by the visible schema; it does not require an extra CLI catalog call.
