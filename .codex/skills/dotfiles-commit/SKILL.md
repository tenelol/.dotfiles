---
name: dotfiles-commit
description: Use when preparing a commit for /home/tener/.dotfiles. It enforces this repo's Semantic Commit Message format, helps choose the correct type and emoji from the actual diff, and reminds the agent to validate the flake before committing.
---

# Dotfiles Commit

Use this skill when the user asks to commit, draft a commit message, or prepare a final commit-ready summary for this repo.

## Commit format

Every commit must use:

`<Type>: <Emoji> <Title>`

Allowed types:

- `chore`
- `docs`
- `feat`
- `fix`
- `refactor`
- `style`
- `test`

Recommended emoji mapping:

- `chore` -> `🧹`
- `docs` -> `📝`
- `feat` -> `✨`
- `fix` -> `🐛`
- `refactor` -> `♻️`
- `style` -> `💄`
- `test` -> `✅`

Title rules:

- imperative present tense
- concise
- no trailing period

## How to choose the type

- `feat`: new end-user or operator capability
- `fix`: behavior correction or bug fix
- `refactor`: internal reshaping without changing intended behavior
- `docs`: README, AGENTS, comments, or skill docs
- `test`: new or updated validation/tests
- `style`: formatting or presentation-only changes
- `chore`: maintenance that does not fit the above cleanly

## Before committing

1. Check the actual diff instead of guessing from the request.
2. Run the smallest relevant validation:
   - always start with `nix flake check --no-build`
   - add `nh os build . -H <host>` or `nh darwin build . -H macbook` when the change touches host/module behavior
3. Make sure the final message reflects the dominant change, not every touched file.

## Examples

- `docs: 📝 Rewrite README around denix and nh`
- `fix: 🐛 Restore macOS Neovim clipboard integration`
- `feat: ✨ Add repo-local dotfiles workflow skills`
