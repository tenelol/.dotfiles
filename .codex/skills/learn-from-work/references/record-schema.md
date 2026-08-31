# Learning record schema

Use one canonical record per normalized pattern. Store structured fields in the body when the durable-context database does not have dedicated properties.

## Canonical fields

| Field | Purpose |
| --- | --- |
| `pattern_key` | Stable lowercase key, scoped enough to avoid cross-project collisions |
| `kind` | `pain`, `success`, `decision`, `working-value`, or `handoff` |
| `scope` | `global`, `repo`, or `project`, plus the relevant Context Key |
| `summary` | One precise sentence describing the reusable pattern |
| `why` | Consequence or benefit that makes the pattern worth retaining |
| `apply_when` | Conditions under which the learning should be used |
| `next_time` | Smallest concrete behavior that applies the learning |
| `pain_count` | Independent failure or correction occurrences |
| `success_count` | Independently validated successful uses |
| `reinforce_count` | Confirmations after a rule has been promoted |
| `first_seen` | Date of earliest verified evidence |
| `last_seen` | Date of latest verified evidence |
| `evidence` | Independent issue, PR, commit, task, runtime, or live-source identifiers, each with a stable `occurrence_id` for de-duplication |
| `confidence` | High, medium, or low with a short reason |
| `promotion_state` | `observed`, `candidate`, `approved`, `promoted`, or `retired` |
| `promoted_to` | Exact rule, test, skill, hook, automation, or `null` |
| `review_after` | Date for revalidation or pruning |
| `sensitivity` | `none`, `redacted`, or a reason not to persist |

## Durable-context mapping

Map to the existing Context Items schema rather than inventing new database properties:

- **Type**: choose the closest valid existing type such as decision, risk, task, investigation, or handoff.
- **Status**: use a valid workspace status; do not invent an enum value.
- **Priority**: reflect recurrence impact, not how interesting the observation feels.
- **Context Key**: combine stable scope identity with `pattern_key`.
- **Source**: identify the retrospective or promotion audit without copying raw input.
- **Confidence**: match evidence quality.
- **Evidence URL**: prefer a durable issue, PR, commit, documentation, or live-source URL.
- **Review After**: use for unpromoted, time-sensitive, or weakly supported records.
- **Related Items**: link separate but related patterns and independent occurrence records.
- **Pinned**: reserve for globally useful startup context only.

## Identity and counting rules

A candidate matches an existing pattern only when these agree materially:

1. root cause or enabling condition;
2. trigger or situation;
3. intended preventive or repeatable response;
4. scope.

Do not merge merely because symptoms or keywords are similar. Count one underlying event once even if it appears in chat, a diff, a test, and an issue. Count separate tasks or incidents only when each has its own evidence.

## Persistence filter

Persist a candidate only when it is specific, supported, reusable, and safe to retain. Do not persist:

- raw prompts, transcripts, logs, or email bodies;
- secrets, tokens, passwords, private keys, connection strings, or secret values;
- unnecessary names, email addresses, customer identifiers, or other personal data;
- speculative preferences inferred from silence;
- generic advice the model already knows;
- one-off task chronology with no future decision value.

Redact sensitive evidence while preserving enough information to revalidate the claim.
