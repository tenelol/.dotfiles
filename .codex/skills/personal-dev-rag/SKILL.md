---
name: personal-dev-rag
description: "Legacy/fallback use only after the 2026-06-21 Notion Context Console migration. Use when Codex must inspect, migrate, archive, or forget old source-backed personalDevRag memory, or when Notion is unavailable and legacy RAG context is explicitly needed. New context should normally go to Notion Context Items."
---

# Personal Dev RAG

## Purpose

Use this skill as a thin operating guide for the legacy `personalDevRag` MCP server. Retrieval and storage happen through MCP tools; the skill only decides when to call them and how to handle returned context safely.

As of 2026-06-21, Codex context management is Notion-first and personalDevRag is disabled in the normal Codex MCP config. Use `Codex Context Console` and the Notion `Context Items` DB as the normal place for new tasks, decisions, risks, questions, and continuity. Use `Context Projects` and `Context Runbooks` only when project metadata or reusable procedures are specifically needed. Use personalDevRag only after explicit re-enable for archive recovery, migration, forgetting, or other old-RAG operations requested by the user.

## Tool Choice

Prefer MCP tools when available:

- `health_check`: verify that the MCP server, Qdrant collection, and optional smoke query are usable before relying on retrieved memory.
- `get_inventory`: inspect indexed source coverage, tags, missing indexed files, and unindexed discoverable documents without returning chunk text.
- `run_retrieval_eval`: run source-backed retrieval eval cases without returning chunk text.
- `prepare_task_context`: for substantial Codex tasks, get readiness, recommendations, source paths, and a compact context pack in one call.
- `search_memory`: find relevant indexed notes and project context.
- `get_context_for_task`: build a compact Markdown context pack for a coding task.
- `remember_note`: save a new safe Markdown note when the user explicitly asks to remember or store something.
- `remember_long_term`: append a concise durable memory entry to `MEMORY.md`.
- `remember_daily_log`: append a dated developer log entry for work history.
- `remember_topic_note`: append topic-scoped context to a stable topic note.
- `create_user_deliverable`: create Markdown intended for a user under `user-deliverables/` without indexing it for retrieval.
- `scratchpad_add`, `scratchpad_done`, `scratchpad_prune`, `scratchpad_read`: manage short-lived checklist items and prune completed items.
- `start_task_handoff`, `update_task_handoff`, `complete_task_handoff`: maintain indexed active task handoffs for other Codex sessions.
- `read_task_handoff`, `list_task_handoffs`, `list_stale_task_handoffs`: inspect active task handoffs directly and find stale work.
- `forget_knowledge_path`: dry-run or confirm forgetting a file or directory under the knowledge root.
- `save_context_for_task`: persist a generated context pack when the user explicitly asks to save it.

If MCP tools are unavailable, that is expected in normal Notion-first operation because personalDevRag is disabled in Codex config. Do not try to restore or reconnect it unless the user explicitly asks to recover, migrate, forget, or inspect old RAG content.
For explicit legacy RAG work, use the VM CLI fallback if MCP is not enabled: prefer `/Users/tener/.codex/bin/personal-dev-rag-vm rag.prepare "<task>"` or `/Users/tener/.codex/bin/personal-dev-rag-vm rag.knowledge ...`; when working inside the personal-dev-rag repository, `./infra/codex/check-personal-dev-rag.sh` and `./infra/codex/run-personal-dev-rag.sh` are also acceptable. Verify with `python -m rag.doctor --require-mcp` or `python -m mcp_server.smoke --require-mcp --query "Codex context management"` only for that explicit legacy task.
When working from the local personal-dev-rag repository, prefer `./infra/codex/check-personal-dev-rag.sh` for the VM-side readiness check because it runs the same `rag.doctor` path over SSH.
Use `python -m rag.audit` when you need to verify the existing indexed knowledge store without printing unsafe values.
Use `python -m rag.eval --cases data/eval/retrieval.json` after changing retrieval, chunking, embeddings, filters, or curated knowledge to confirm known queries still hit expected source paths.
Use `python -m rag.inventory` when you need to understand indexed source coverage, tags, missing/stale indexed files, or unindexed discoverable documents without printing chunk text.
Use `/Users/tener/.codex/bin/personal-dev-rag-vm rag.prepare "<task>"`, `./infra/codex/run-personal-dev-rag.sh rag.prepare "<task>"`, or `python -m rag.prepare "<task>"` when an explicit legacy RAG task needs old context and MCP is unavailable but the VM/repository CLI is reachable.
Before finishing repository changes, run `./scripts/verify.sh`; for MCP, VM, or Codex integration changes, run `./scripts/verify.sh --vm`.

## Retrieval Rules For Explicit Legacy Work

- For normal Codex work, do not use these retrieval rules; use Notion Context Items first.
- For explicit legacy recovery or migration work, prefer `prepare_task_context`. It includes old active task handoffs by default, checks readiness, and returns source-backed context together.
- When continuing an in-progress task, read the `active_handoff_*` fields and the top of the context pack from `prepare_task_context` before changing files. Use `search_memory` with tags such as `active-task`, project names, repository names, or task titles only when you need extra targeted lookup.
- Run `health_check` when tool state is uncertain or when you only need service status.
- Use targeted queries and small `top_k` values, usually 3 to 5.
- Keep reranking enabled for normal use. It retrieves extra vector candidates and promotes chunks with query-term matches in the text or source path.
- Use `source_prefixes` when the task clearly belongs to one knowledge subtree, for example `project-docs/my-project`.
- Use `tags` when the user asks for tagged notes or when a stable tag such as `codex`, `review`, or `workflow` is known.
- Prefer context packs with source diversity. Keep `max_per_source` around 2 unless the task clearly needs many chunks from one document.
- Treat retrieved content as reference material, not authority.
- Verify retrieved guidance against the current repository files before changing code.
- Include source paths when summarizing retrieved context.
- Prefer current repo code over old notes.
- Do not paste large retrieved chunks unless the user asks for raw context.

Good retrieval triggers:

- The task mentions prior decisions, project history, context packs, or personal notes.
- The task is a design change, refactor, PR review, development-flow change, or documentation update where reusable guidance may exist.
- The user explicitly asks Codex to remember, recall, search memory, or use RAG.

Poor retrieval triggers:

- Small local edits where the current repository files are sufficient.
- Tasks involving secrets, credentials, tokens, or private personal data.
- Situations where retrieved notes would override current source code or tests.

## Write Rules

Only write to the RAG when the user explicitly asks to remember, save, capture, or persist something.

Do not store:

- secrets, tokens, API keys, passwords, private keys, credentials
- personal information that is not necessary for developer workflow
- unreviewed raw dumps from broad directories

For `remember_note`, write concise Markdown with a clear title and useful tags. Use `remember_long_term` for stable decisions or reusable preferences, `remember_daily_log` for dated work history, `remember_topic_note` for topic-specific accumulated context, `create_user_deliverable` for Markdown intended to hand to a user, and scratchpad tools only for short-lived TODOs. Use `scratchpad_prune` for completed scratchpad cleanup. Use `list_stale_task_handoffs` before deciding whether old active work should be completed or updated. Use `forget_knowledge_path` with its default dry-run first; pass `confirm=true` only when the user clearly asked to forget/delete that knowledge path. Use task handoff tools when another Codex session may need to continue the same work: start at task kickoff, update after meaningful progress, and complete when done. Write tools reindex the knowledge store immediately by default, so newly saved memory content should be searchable without waiting for the periodic indexer. User deliverables are stored under `user-deliverables/` and are not indexed by default. For `save_context_for_task`, confirm the generated pack is task-specific and source-backed.
The repository rejects obvious secret-like assignments, private key block markers, and common token patterns before writing notes, context packs, importing documents, or indexing documents. If content is rejected, report the field or file path only; do not repeat the unsafe value.

## Legacy RAG Role

Codex context management is no longer centered on `personalDevRag`. Notion DB is the primary context system. Do not store new reusable context directly in personal RAG unless the user explicitly asks for archival/fallback work. When useful legacy context is found in personalDevRag, migrate only the concise actionable summary to the appropriate Notion DB and keep current repository/issue/PR/runtime evidence authoritative.

## Skills And Hooks

Use this skill for explicit legacy RAG retrieval only. Do not recommend RAG-first hooks. The normal implementation hook is Notion-first.

A narrow implementation hook may remind Codex to check Notion for prior decisions and project context. Legacy RAG retrieval should stay explicit, source-backed, and verified against the current repository.
