---
name: gh-one-issue-pr
description: Implement GitHub issues with strict one-issue isolation. Use when the user asks to implement assigned issues, use subagents for issue work, create one branch per issue, create one non-draft PR per issue, avoid mega-PRs, or check PR mergeability for issue implementations.
---

# GH One Issue PR

## Overview

Use this workflow to turn assigned GitHub issues into small, reviewable PRs without mixing scope. Each issue gets exactly one owning agent, one branch, one commit series, and one non-draft PR unless the user explicitly changes that constraint.

## Core Rules

- Do not create a combined PR for multiple issues.
- Do not implement an issue that is blocked by an unmerged dependency unless the user explicitly approves a stacked PR or a prerequisite issue implementation.
- Do not take over issues assigned to someone else unless the user explicitly asks.
- Do not merge PRs. Only create PRs and report mergeability.
- Keep each branch scoped to the issue's allowed files and acceptance criteria.
- If the user explicitly asks for subagents, assign one worker agent to one issue. Never assign the same issue to multiple agents.
- If the user does not explicitly ask for subagents, work one issue at a time locally.
- Never let multiple agents share one Git worktree. `git switch`, staging, committing, and conflict checks mutate worktree-local Git state and can interfere across agents.

## Workflow

1. Resolve repository context:
   - Run `git status --short --branch`, `git remote -v`, and `gh repo view --json nameWithOwner,defaultBranchRef`.
   - Fetch the base branch named by each issue body. If absent, use the repository default.
   - Preserve unrelated local changes. Do not revert user work.

2. Collect assigned issues:
   - Prefer `gh issue list --assignee @me --state open --json number,title,body,labels,assignees,url --limit 100`.
   - If GitHub connector tools are available and more reliable, use them for issue metadata.
   - Exclude issues already covered by an open PR unless the user asks to continue that PR.

3. Build an issue plan:
   - Parse `Base branch`, `Dependencies`, `Allowed files`, `Do not touch`, `Tasks`, and `Acceptance criteria` from each issue body.
   - Order issues by dependencies and priority.
   - Mark blocked issues clearly when dependencies are open, missing from the checkout, or assigned to someone else.
   - Ask before implementing unassigned prerequisite issues.

4. Create one work lane per ready issue:
   - Branch name: `codex/issue-<number>-<short-slug>`.
   - Base it on the issue's base branch, usually `origin/develop`.
   - If using subagents, spawn exactly one worker per ready issue. Tell the worker it is not alone in the codebase, owns only that issue, must not revert others' edits, and must list changed files and validation results.
   - Require one isolated workspace per issue: either the subagent's forked workspace or a dedicated `git worktree` path. Do not run parallel issue agents in the same checkout path.
   - If a worker is using the shared checkout path, do not run that worker in parallel with any other branch-changing work.

5. Implement narrowly:
   - Follow repository docs such as `AGENTS.md`, `HANDOFF.md`, and issue-specific prompts.
   - Touch only the issue's allowed files unless a small shared contract change is necessary and documented.
   - Update `HANDOFF.md` only for the issue's status and verification notes.
   - Do not add unrelated cleanup, formatting, renames, or broader architecture changes.

6. Validate before publishing:
   - Run the closest standard validation for the issue: tests, lint, build, or documented checks.
   - For Xcode projects, prefer the repo's documented `xcodebuild` commands.
   - If validation cannot run, record the exact reason in the PR body and final report.
   - Do not create a non-draft PR when validation fails unless the user explicitly accepts that risk.

7. Check merge feasibility before opening the PR:
   - Fetch the base branch.
   - Use a non-mutating local conflict check such as `git merge-tree --write-tree HEAD origin/<base>` when available.
   - If conflicts exist, stop that issue and report conflicting files. Do not open a ready PR.

8. Commit, push, and create the PR:
   - Stage only files for that issue.
   - Commit with a clear issue-scoped message.
   - Push with upstream tracking.
   - Create the PR without `--draft`; include `Closes #<number>` only when the issue acceptance criteria are actually met.
   - Fill the repository PR template, including validation commands, CI status, project-file changes, shared contract changes, and risks.

9. Confirm GitHub mergeability after PR creation:
   - Query `isDraft`, `mergeable`, `mergeStateStatus`, `statusCheckRollup`, `reviewDecision`, and `url`.
   - Poll briefly if mergeability is initially unknown.
   - Report whether the PR is non-draft, locally conflict-free, GitHub-mergeable, and whether checks are pending/failing/passing.

## Worker Prompt Template

Use this shape when spawning a worker:

```text
You own exactly GitHub issue #<number>: <title>.
Base branch: <base>.
Branch: codex/issue-<number>-<slug>.

You are not alone in the codebase. Do not revert edits made by others. Do not work on any other issue.
Use an isolated workspace for this issue. Do not run `git switch`, `git add`, `git commit`, merge checks, or pushes in a shared checkout used by another issue agent.

Allowed files:
<issue allowed files>

Do not touch:
<issue do-not-touch list>

Implement the issue acceptance criteria, run the closest validation, commit, push, and create a non-draft PR if validation and local merge checks pass. Return the PR URL, mergeability status, validation commands, and changed files.
```

## Stop Conditions

- The target repository cannot be authenticated or reached.
- The issue's base branch is ambiguous.
- The issue depends on open work not present in the base branch.
- The only way forward would mix multiple issues in one PR.
- Validation fails.
- Local merge conflict checks fail.
- The PR would have to be draft despite the user's non-draft requirement.
