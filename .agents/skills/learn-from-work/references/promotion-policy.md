# Promotion policy

Promotion moves a proven learning to the narrowest place that can reliably change future behavior. It is always proposed first and requires explicit user approval before mutation.

## Evidence thresholds

| Evidence | State | Default action |
| --- | --- | --- |
| One or two independent occurrences | Observed | Keep scoped and review later; do not create an always-loaded rule |
| `pain_count >= 3` | Candidate | Propose a preventive control or narrow rule |
| `success_count >= 3` | Candidate | Propose stable guidance or a repeatable procedure |
| Promoted rule still violated, or `reinforce_count >= 3` | Automation candidate | Consider a test, skill, hook, or automation after revalidation |

The number three controls when to review a pattern. It is not proof, and it never authorizes automatic promotion. Increase the evidence bar for broad, costly, irreversible, or security-sensitive changes.

## Choose the destination

| Pattern | Preferred destination |
| --- | --- |
| Mechanically detectable invariant or recurring bug | Test, type constraint, schema validation, linter, or CI check |
| Stable repository-specific convention | Repository `AGENTS.md` or focused versioned documentation |
| Cross-project rule worth loading every task | Minimal user-level instruction or a genuinely startup-worthy Pinned Context Item |
| Multi-step procedure used on demand | Codex skill |
| Mandatory pre/post action tied to an event | Hook, CI job, or Codex automation when supported and explicitly approved |
| Time-sensitive fact or unresolved judgment | Context Item with Review After; do not promote |

Prefer deterministic enforcement over prose when a machine can check the invariant. Prefer a skill over an always-loaded rule when the procedure is only relevant to some tasks.

## Promotion checklist

Before proposing promotion, verify:

- evidence is independent and still current;
- the root cause and applicability conditions are specific;
- the destination scope is no broader than the evidence;
- no existing rule, test, or skill already covers it;
- the proposed wording describes behavior, not task history;
- the change does not encode secrets, private data, or stale personal details;
- validation and rollback are practical;
- an owner or review date exists for rules likely to age.

After approved promotion, validate the destination and record the exact evidence and location. Retire or narrow rules that stop helping, conflict with current evidence, or add more context cost than value.

## Design sources

This policy is an original Codex-oriented adaptation inspired by:

- bik, “Claude Codeに同じバグを3回出すと、自動でルール化される話”: https://zenn.dev/nexta_/articles/858e92ee22b4a4
- echolimitless, `cc-retrospective-learner`: https://github.com/echolimitless/cc-retrospective-learner

The source article is not copied into this skill. The linked repository declares MIT in its README, but this skill does not copy its scripts or templates.
