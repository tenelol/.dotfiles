# Vault automations

Codex app owns the live automation TOML files. Apply or update them only through
the app automation API; do not symlink generated IDs, project IDs, timestamps, or
runtime state from Home Manager.

- 06:30 daily: process immutable raw notes, rebuild the semantic index, run quality checks, and report through LINE.
- 07:30 daily: run `/Users/tener/.local/bin/vault-git-sync` and report the safe result through LINE.
- Sunday 10:00: generate the weekly synthesis, rebuild the semantic index, run quality checks, and report through LINE.

The morning and weekly prompt contracts live in the Vault under
`90 System/Prompts/`. The Git synchronization prompt is
`vault-git-sync.md` in this directory.
