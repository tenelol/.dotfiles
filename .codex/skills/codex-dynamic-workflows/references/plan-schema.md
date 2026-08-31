# Plan Schema

Use this schema when a machine-readable workflow plan helps coordination. Keep `plan.md` as the human source of truth.

```json
{
  "goal": "string",
  "success_criteria": ["string"],
  "constraints": ["string"],
  "risks": [
    {
      "risk": "string",
      "approval_required": true,
      "mitigation": "string"
    }
  ],
  "max_concurrent_agents": 4,
  "max_total_agents": 12,
  "packets": [
    {
      "id": "01-discovery",
      "objective": "string",
      "context": "string",
      "files_or_sources": ["string"],
      "ownership": "string",
      "routing": {
        "tier": "fast | standard | deep | review",
        "model": "resolved model slug or null",
        "reasoning_effort": "resolved effort or null",
        "backend": "native | cli | inherited | simulated"
      },
      "do": ["string"],
      "do_not": ["string"],
      "expected_output": "string",
      "verification": ["string"],
      "status": "pending"
    }
  ],
  "integration_policy": {
    "owner": "parent",
    "conflict_resolution": "Inspect authoritative sources before choosing.",
    "final_output": "string"
  },
  "verification": [
    {
      "check": "string",
      "command": "string or null",
      "required": true,
      "status": "pending"
    }
  ],
  "reusable_artifacts": ["string"]
}
```

Suggested defaults:

- `max_concurrent_agents`: 2-4 for normal work.
- `max_total_agents`: 6-12 unless the user approves a larger run.
- Packet IDs: prefix with two digits so files sort naturally.
- Resolve `routing.model`, `routing.reasoning_effort`, and `routing.backend` immediately before dispatch; keep them `null` only while the packet is still being planned.
- Status values: `pending`, `in_progress`, `complete`, `blocked`, `skipped`.
