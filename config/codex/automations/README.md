# Vault automations

Codex app owns the live automation TOML files. Apply or update them only through
the app automation API; do not symlink generated IDs, project IDs, timestamps, or
runtime state from Home Manager.

- 06:30 daily: process immutable raw notes, rebuild the semantic index, record the KPI snapshot, and alert through LINE only on blocked/warn/fail.
- 09:00 daily: run `/Users/tener/.local/bin/vault-git-sync`; success and no-op stay silent, while blocked/push-pending/failure alert through LINE.
- Sunday 10:00: generate the weekly synthesis, record and compare KPI history, and send one combined weekly LINE report.

The morning and weekly prompt contracts live in the Vault under
`90 System/Prompts/`, including `kpi-observability.md`. The Git synchronization prompt is
`vault-git-sync.md` in this directory.
