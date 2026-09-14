# Pi Delegation

Use the installed `pi-subagents` extension and its skill for launch, status, cancellation, and result handling. This document supplies personal model policy; it does not replace the extension's API contract.

## Model Selection

| Responsibility | Default Pi model selector |
| --- | --- |
| Research, summaries, document analysis, independent review | `openai-codex/gpt-5.6-sol:xhigh` |
| Implementation, debugging, multi-file changes, test fixes | `openai-codex/gpt-5.6-terra:xhigh` |

These preserve the existing responsibility-based model policy. Follow an explicit user model override. Check available models with `subagent({ action: "models" })` before launching; `pi --offline --list-models` is also available for local inspection.

Pass the thinking level in the `model` suffix. In the installed extension, a separate top-level `thinking` field is ignored for dispatch.

```javascript
subagent({
  agent: "reviewer",
  model: "openai-codex/gpt-5.6-sol:xhigh",
  context: "fresh",
  task: "Review the specified diff. Include the repository/ref, scope, constraints, evidence, acceptance criteria, and expected report here."
})
```

Use a fresh context with a self-contained task when isolation is useful. Prefer native async execution and completion notifications; do useful parent work while a child runs.

Do not silently substitute providers, lower reasoning, or escalate to `max`. Pi's current core CLI does not expose `--fallback-models`; use the extension's supported `fallbackModels` configuration only for an explicitly authorized candidate list. Check availability before use and report exhaustion or infrastructure failures with the retained run state.

If an explicit CLI child is required, use the documented `pi --model 'provider/model:effort' -p 'instructions'` form. A required skill can be included in its prompt as `/skill:skill-name instructions`. Keep shell quoting intact, preserve failure output, and manage background CLI children through the chosen process manager.
