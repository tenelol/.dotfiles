---
name: diagnosing-bugs
description: Diagnose a reported failure or slowdown in Pi using a repeatable reproduction, primary evidence, and a focused regression check.
compatibility: Pi read, bash, and browser tools; interactive human steps run in a separate terminal.
metadata:
  adapted-from: mattpocock/skills/diagnosing-bugs
---

1. Establish the observed behavior, expected behavior, and a repeatable failing check. Use the existing test runner, a small script, a local API request, or `playwright_cli` for browser behavior. Keep credentials and personal data out of commands, logs, and captured evidence.
2. Run the reproduction and verify that it fails for the reported reason. Minimize it while retaining the failure. If evidence is insufficient, state the missing prerequisite and continue independent inspection; do not describe a hypothetical reproduction as confirmed.
3. Trace the entry point, callers, and data flow. Read relevant `CONTEXT.md` and ADRs if present. Rank falsifiable explanations and test the strongest one first, changing one variable at a time.
4. Fix the cause where the affected callers meet. Add the smallest regression check that exercises the original failure, then rerun it and the checks required by the changed artifact. For performance, compare the same workload and conditions before and after.
5. Remove temporary instrumentation. Report the confirmed cause, change, validation result, and remaining uncertainty.

When reproduction needs human interaction, provide the exact command or a script for the user to run in a **separate Herdr terminal** and request only the relevant redacted result. Pi's `bash` tool has no interactive stdin; do not launch an interactive wizard there and expect the user to answer inside Pi. Use the `wizard` skill when a guided script is needed.

Use the existing `subagent` tool only for a bounded independent investigation or review. Keep the overall diagnosis and integration in the parent.
