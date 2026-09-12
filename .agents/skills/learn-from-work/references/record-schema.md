# Learning record schema

Use one canonical record per normalized pattern. Store only the fields required for the current audit in the existing Markdown record.

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

Use the resolved project's existing `canonical/<responsibility>/` Markdown records. Keep one topic per record, and put the fields needed for recurrence analysis in that record rather than a new database. A stable pattern key and explicit project scope identify matches.

Map accepted decisions to `decisions`, repeated procedures to `workflows`, verified facts to `facts`, unresolved risks to `risks`, and missing decisions to `open_questions`. Keep supporting evidence as concise source references. Only legacy migration requests need the old Notion Context Items properties.

Do not pin records into every task's startup context. Read a record when its application condition matches the task. For a global learning, use the existing central protocol only when the global scope and destination are established; do not guess a new store.

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
