---
name: gh-ready-pr
description: Non-draft GitHub PR publishing workflow with preflight validation, local merge conflict checks against the base branch, PR creation without draft mode, and post-create GitHub mergeability/status checks. Use when the user asks to draftなしでmerge可否を確認し、PRを投げてください, 非draft PRを作成, open a ready PR, check mergeability and create PR, or similar.
---

# GH Ready PR

## Overview

Create a GitHub pull request as ready for review, not draft, only after practical preflight and mergeability checks. If the repository is not in a state where a non-draft PR is appropriate, stop and report the blocker instead of silently creating a draft PR.

## Workflow

1. Orient in the repository.
   - Inspect `git status --short`, current branch, remotes, upstream, and base branch.
   - Detect an existing PR for the branch with `gh pr view` or the GitHub connector when available.
   - If on the base branch (`main`, `master`, `trunk`, or the repository default), create or ask for a feature branch before publishing.

2. Preserve user work.
   - Do not revert unrelated local changes.
   - If dirty files are unrelated to the PR scope, leave them out of commits and mention them.
   - If needed changes are uncommitted, stage only the intended files and create a clear commit.

3. Run preflight checks.
   - Use the repository's standard validation commands first: CI scripts, tests, lint, typecheck, build, or documented checks.
   - If validation cannot be run, record the reason and continue only when the remaining risk is acceptable for a non-draft PR.

4. Check merge feasibility before opening the PR.
   - Fetch the base branch from the canonical remote, usually `origin`.
   - Prefer a non-mutating merge check such as `git merge-tree --write-tree HEAD origin/<base>` when supported.
   - If the local Git version cannot do a reliable non-mutating check, use a temporary worktree under `/tmp` and attempt a no-commit merge there, then remove the worktree.
   - If conflicts are detected, do not open a non-draft PR. Report the conflicting files and the exact check used.

5. Push the branch.
   - Push the current branch to its remote with upstream tracking if needed.
   - Avoid force-push unless the user explicitly requested it or it is clearly part of an accepted branch update.

6. Create or update a non-draft PR.
   - Use the existing PR if one already exists for the branch.
   - If an existing PR is draft and the user requested non-draft, mark it ready with `gh pr ready` after preflight succeeds.
   - For a new PR, use `gh pr create` or the GitHub connector without passing `--draft`. Do not create a draft PR as a fallback.
   - Build the title and body from the actual diff, commits, PR template, and validation results.

7. Confirm GitHub mergeability after the PR exists.
   - Query `isDraft`, `mergeable`, `mergeStateStatus`, `statusCheckRollup`, review decision, and URL with `gh pr view --json ...` or the GitHub connector.
   - GitHub may initially return an unknown mergeability state. Poll briefly with bounded retries, then report `UNKNOWN` if it does not settle.
   - Report whether the PR is non-draft, mergeable/conflicting/unknown, and which checks are passing, failing, or pending.

## Practical Defaults

- Default base branch: repository default from GitHub; otherwise `origin/main`, then `origin/master`.
- Default remote: the upstream remote for the current branch; otherwise `origin`.
- Non-draft means a ready-for-review PR. Omit draft flags and explicitly verify `isDraft: false`.
- "Mergeable" means both local conflict preflight and GitHub's PR mergeability/status have been checked. If CI is pending, say mergeability is not fully proven yet.

## Stop Conditions

- Stop before PR creation when tests fail, merge conflicts exist, required commits are missing, the target branch is ambiguous, or repository authentication is unavailable.
- Stop before marking a draft PR ready if the diff has unresolved work, failing validation, or the user did not ask to convert that existing draft.
- Never merge the PR unless the user explicitly asks for merging.
