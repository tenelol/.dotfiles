#!/usr/bin/env python3
"""Deny Git worktree mutations outside the canonical macbook layout."""

from __future__ import annotations

import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
from typing import Callable, NamedTuple, Sequence


PROJECTS_ROOT = Path.home() / "projects"
SHELL_OPERATORS = {"&&", "||", ";", "|", "&", "(", ")"}
SHELL_EXECUTABLES = {"bash", "sh", "zsh"}
MAX_NESTING = 4
ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
WORKTREE_MUTATION = re.compile(r"(?:^|\s)worktree\s+(?:add|move)(?:\s|$)")
GIT_GLOBAL_FLAGS = {
    "--bare",
    "--help",
    "--html-path",
    "--info-path",
    "--literal-pathspecs",
    "--man-path",
    "--no-optional-locks",
    "--no-pager",
    "--no-replace-objects",
    "--paginate",
    "--version",
    "-p",
}
ADD_FLAGS = {
    "--checkout",
    "--detach",
    "--force",
    "--guess-remote",
    "--lock",
    "--no-checkout",
    "--no-guess-remote",
    "--no-relative-paths",
    "--no-track",
    "--orphan",
    "--relative-paths",
    "--track",
    "-f",
}
ADD_OPTIONS_WITH_VALUE = {"--reason", "-B", "-b"}
MOVE_FLAGS = {"--force", "-f"}

GitCommonDirResolver = Callable[[Path], Path]
GitAliasResolver = Callable[[Path, str], str | None]


class CommandPrefix(NamedTuple):
    executable_index: int | None
    cwd_uncertain: bool = False
    repository_environment_uncertain: bool = False
    alias_environment_uncertain: bool = False
    split_command: str | None = None


class WorktreeCommandError(ValueError):
    """A worktree mutation was found but could not be validated safely."""


def _shell_tokens(command: str) -> list[str]:
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|()")
    lexer.whitespace_split = True
    lexer.commenters = ""
    return list(lexer)


def _command_segments(tokens: Sequence[str]) -> list[list[str]]:
    segments: list[list[str]] = []
    current: list[str] = []
    for token in tokens:
        if token in SHELL_OPERATORS:
            if current:
                segments.append(current)
                current = []
            continue
        current.append(token)
    if current:
        segments.append(current)
    return segments


def _environment_effect(name: str) -> tuple[bool, bool]:
    normalized = name.casefold()
    repository_environment = normalized in {
        "git_common_dir",
        "git_ceiling_directories",
        "git_dir",
        "git_discovery_across_filesystem",
        "git_work_tree",
    }
    alias_environment = (
        normalized in {"home", "xdg_config_home", "git_config"}
        or normalized.startswith("git_config_")
    )
    return repository_environment, alias_environment


def _record_environment_effect(
    token: str,
    repository_environment_uncertain: bool,
    alias_environment_uncertain: bool,
) -> tuple[bool, bool]:
    name = token.split("=", 1)[0]
    repository_effect, alias_effect = _environment_effect(name)
    return (
        repository_environment_uncertain or repository_effect,
        alias_environment_uncertain or alias_effect,
    )


def _command_prefix(segment: Sequence[str]) -> CommandPrefix:
    index = 0
    cwd_uncertain = False
    repository_environment_uncertain = False
    alias_environment_uncertain = False
    while index < len(segment) and ASSIGNMENT.match(segment[index]):
        repository_environment_uncertain, alias_environment_uncertain = _record_environment_effect(
            segment[index],
            repository_environment_uncertain,
            alias_environment_uncertain,
        )
        index += 1
    while index < len(segment):
        while index < len(segment) and ASSIGNMENT.match(segment[index]):
            repository_environment_uncertain, alias_environment_uncertain = _record_environment_effect(
                segment[index],
                repository_environment_uncertain,
                alias_environment_uncertain,
            )
            index += 1
        if index >= len(segment):
            break
        executable = Path(segment[index]).name
        if executable in {"if", "then", "while", "until", "do", "!", "noglob", "nocorrect"}:
            index += 1
            continue
        if executable == "command":
            index += 1
            while index < len(segment) and segment[index] in {"--", "-p"}:
                index += 1
            continue
        if executable == "builtin":
            index += 1
            while index < len(segment) and segment[index] == "--":
                index += 1
            continue
        if executable == "exec":
            index += 1
            while index < len(segment):
                token = segment[index]
                if token == "--":
                    index += 1
                    break
                if token == "-a":
                    index += 2
                    continue
                if token in {"-c", "-l"} or (
                    token.startswith("-") and not token.startswith("--")
                ):
                    index += 1
                    continue
                break
            continue
        if executable in {"time", "nohup"}:
            index += 1
            while index < len(segment):
                token = segment[index]
                if token == "--":
                    index += 1
                    break
                if executable == "time" and token in {"-f", "-o", "--format", "--output"}:
                    index += 2
                    continue
                if token.startswith("-"):
                    index += 1
                    continue
                break
            continue
        if executable == "nice":
            index += 1
            while index < len(segment):
                token = segment[index]
                if token == "--":
                    index += 1
                    break
                if token in {"-n", "--adjustment"}:
                    index += 2
                    continue
                if token.startswith("--adjustment=") or token.startswith("-"):
                    index += 1
                    continue
                break
            continue
        if executable == "env":
            index += 1
            while index < len(segment):
                token = segment[index]
                if token == "--":
                    index += 1
                    break
                if token in {"-C", "--chdir"}:
                    cwd_uncertain = True
                    index += 2
                    continue
                if token.startswith("--chdir=") or (token.startswith("-C") and token != "-C"):
                    cwd_uncertain = True
                    index += 1
                    continue
                if token in {"-u", "--unset"}:
                    if index + 1 < len(segment):
                        repository_environment_uncertain, alias_environment_uncertain = _record_environment_effect(
                            segment[index + 1],
                            repository_environment_uncertain,
                            alias_environment_uncertain,
                        )
                    index += 2
                    continue
                if token in {"-P", "--path"}:
                    index += 2
                    continue
                if token.startswith("--path=") or (token.startswith("-P") and token != "-P"):
                    index += 1
                    continue
                if token.startswith("--unset="):
                    repository_environment_uncertain, alias_environment_uncertain = _record_environment_effect(
                        token.split("=", 1)[1],
                        repository_environment_uncertain,
                        alias_environment_uncertain,
                    )
                    index += 1
                    continue
                if token in {"-i", "--ignore-environment"}:
                    repository_environment_uncertain = True
                    alias_environment_uncertain = True
                    index += 1
                    continue
                if token in {"-S", "--split-string"}:
                    if index + 1 >= len(segment):
                        return CommandPrefix(
                            executable_index=None,
                            cwd_uncertain=cwd_uncertain,
                            repository_environment_uncertain=repository_environment_uncertain,
                            alias_environment_uncertain=alias_environment_uncertain,
                        )
                    split_command = segment[index + 1]
                    if index + 2 < len(segment):
                        split_command = f"{split_command} {shlex.join(segment[index + 2 :])}"
                    return CommandPrefix(
                        executable_index=None,
                        cwd_uncertain=cwd_uncertain,
                        repository_environment_uncertain=repository_environment_uncertain,
                        alias_environment_uncertain=alias_environment_uncertain,
                        split_command=split_command,
                    )
                if token.startswith("--split-string="):
                    split_command = token.split("=", 1)[1]
                    if index + 1 < len(segment):
                        split_command = f"{split_command} {shlex.join(segment[index + 1 :])}"
                    return CommandPrefix(
                        executable_index=None,
                        cwd_uncertain=cwd_uncertain,
                        repository_environment_uncertain=repository_environment_uncertain,
                        alias_environment_uncertain=alias_environment_uncertain,
                        split_command=split_command,
                    )
                if token.startswith("-S") and token != "-S":
                    split_command = token[2:]
                    if index + 1 < len(segment):
                        split_command = f"{split_command} {shlex.join(segment[index + 1 :])}"
                    return CommandPrefix(
                        executable_index=None,
                        cwd_uncertain=cwd_uncertain,
                        repository_environment_uncertain=repository_environment_uncertain,
                        alias_environment_uncertain=alias_environment_uncertain,
                        split_command=split_command,
                    )
                if ASSIGNMENT.match(token):
                    repository_environment_uncertain, alias_environment_uncertain = _record_environment_effect(
                        token,
                        repository_environment_uncertain,
                        alias_environment_uncertain,
                    )
                    index += 1
                    continue
                if token.startswith("-"):
                    index += 1
                    continue
                break
            continue
        if executable == "sudo":
            alias_environment_uncertain = True
            index += 1
            while index < len(segment):
                token = segment[index]
                if token == "--":
                    index += 1
                    break
                if token in {"-D", "--chdir"}:
                    cwd_uncertain = True
                    index += 2
                    continue
                if token.startswith("--chdir=") or (token.startswith("-D") and token != "-D"):
                    cwd_uncertain = True
                    index += 1
                    continue
                if token in {"-C", "-g", "-h", "-p", "-R", "-r", "-t", "-u", "--group", "--host", "--prompt", "--role", "--type", "--user"}:
                    index += 2
                    continue
                if token in {"-H", "-i", "--login", "--set-home"}:
                    alias_environment_uncertain = True
                    index += 1
                    continue
                if token.startswith("-"):
                    index += 1
                    continue
                break
            continue
        break
    return CommandPrefix(
        executable_index=index if index < len(segment) else None,
        cwd_uncertain=cwd_uncertain,
        repository_environment_uncertain=repository_environment_uncertain,
        alias_environment_uncertain=alias_environment_uncertain,
    )


def _persistent_environment_effect(
    executable: str,
    arguments: Sequence[str],
) -> tuple[bool, bool]:
    if executable not in {"export", "unset", "typeset", "declare"}:
        return False, False
    repository_environment_uncertain = False
    alias_environment_uncertain = False
    options_done = False
    for token in arguments:
        if not options_done and token == "--":
            options_done = True
            continue
        if not options_done and token.startswith("-"):
            continue
        repository_environment_uncertain, alias_environment_uncertain = _record_environment_effect(
            token,
            repository_environment_uncertain,
            alias_environment_uncertain,
        )
    return repository_environment_uncertain, alias_environment_uncertain


def _shell_inline_command(segment: Sequence[str], executable_index: int) -> str | None:
    index = executable_index + 1
    while index < len(segment):
        token = segment[index]
        if token == "--":
            return None
        if token in {"-O", "-o", "--init-file", "--rcfile"}:
            index += 2
            continue
        if token == "-c" or (token.startswith("-") and not token.startswith("--") and "c" in token[1:]):
            if index + 1 >= len(segment):
                raise WorktreeCommandError("shell -c requires a command")
            return segment[index + 1]
        if token.startswith("-"):
            index += 1
            continue
        return None
    return None


def _git_context_and_arguments(
    segment: Sequence[str], cwd: Path
) -> tuple[Path, list[str], bool, dict[str, str], bool]:
    context = cwd
    context_independent_of_cwd = False
    temporary_aliases: dict[str, str] = {}
    alias_configuration_uncertain = False
    index = 1
    while index < len(segment):
        token = segment[index]
        if token == "-C":
            if index + 1 >= len(segment):
                raise WorktreeCommandError("git -C requires a directory")
            requested_context = Path(segment[index + 1]).expanduser()
            if requested_context.is_absolute():
                context = requested_context
                context_independent_of_cwd = True
            else:
                context = context / requested_context
            index += 2
            continue
        if token.startswith("-C") and token != "-C":
            requested_context = Path(token[2:]).expanduser()
            if requested_context.is_absolute():
                context = requested_context
                context_independent_of_cwd = True
            else:
                context = context / requested_context
            index += 1
            continue
        if token == "-c":
            if index + 1 >= len(segment):
                raise WorktreeCommandError("git -c requires a value")
            alias_configuration_uncertain = (
                _record_temporary_alias(segment[index + 1], temporary_aliases)
                or alias_configuration_uncertain
            )
            index += 2
            continue
        if token.startswith("-c") and token != "-c":
            alias_configuration_uncertain = (
                _record_temporary_alias(token[2:], temporary_aliases)
                or alias_configuration_uncertain
            )
            index += 1
            continue
        if token == "--config-env":
            if index + 1 >= len(segment):
                raise WorktreeCommandError("git --config-env requires a name")
            alias_configuration_uncertain = (
                _config_key_may_change_aliases(segment[index + 1].split("=", 1)[0])
                or alias_configuration_uncertain
            )
            index += 2
            continue
        if token.startswith("--config-env="):
            config_name = token.split("=", 1)[1].split("=", 1)[0]
            alias_configuration_uncertain = (
                _config_key_may_change_aliases(config_name) or alias_configuration_uncertain
            )
            index += 1
            continue
        if token in {"--git-dir", "--work-tree"}:
            if index + 1 >= len(segment):
                raise WorktreeCommandError(f"git {token} requires a directory")
            alias_configuration_uncertain = True
            index += 2
            continue
        if token.startswith("--git-dir=") or token.startswith("--work-tree="):
            alias_configuration_uncertain = True
            index += 1
            continue
        if token == "--bare":
            alias_configuration_uncertain = True
            index += 1
            continue
        if token in GIT_GLOBAL_FLAGS:
            index += 1
            continue
        if token.startswith("-"):
            if "worktree" in segment[index + 1 :]:
                raise WorktreeCommandError(f"unsupported git option before worktree: {token}")
            return (
                context.resolve(strict=False),
                [],
                context_independent_of_cwd,
                temporary_aliases,
                alias_configuration_uncertain,
            )
        break
    return (
        context.resolve(strict=False),
        list(segment[index:]),
        context_independent_of_cwd,
        temporary_aliases,
        alias_configuration_uncertain,
    )


def _config_key_may_change_aliases(key: str) -> bool:
    normalized = key.casefold()
    return (
        normalized.startswith("alias.")
        or normalized == "include.path"
        or normalized.startswith("includeif.")
    )


def _record_temporary_alias(value: str, aliases: dict[str, str]) -> bool:
    if "=" not in value:
        return False
    key, alias_value = value.split("=", 1)
    normalized = key.casefold()
    if normalized.startswith("alias.") and len(normalized) > len("alias."):
        aliases[normalized[len("alias.") :]] = alias_value
        return False
    return _config_key_may_change_aliases(normalized)


def _add_destination(arguments: Sequence[str]) -> str:
    positionals: list[str] = []
    index = 1
    options_done = False
    while index < len(arguments):
        token = arguments[index]
        if not options_done and token == "--":
            options_done = True
            index += 1
            continue
        if not options_done and token in ADD_FLAGS:
            index += 1
            continue
        if not options_done and token in ADD_OPTIONS_WITH_VALUE:
            if index + 1 >= len(arguments):
                raise WorktreeCommandError(f"{token} requires a value")
            index += 2
            continue
        if not options_done and any(
            token.startswith(f"{option}=") for option in ADD_OPTIONS_WITH_VALUE if option.startswith("--")
        ):
            index += 1
            continue
        if not options_done and token.startswith("-"):
            raise WorktreeCommandError(f"unsupported git worktree add option: {token}")
        positionals.append(token)
        index += 1
    if not positionals:
        raise WorktreeCommandError("git worktree add destination is missing")
    return positionals[0]


def _move_destination(arguments: Sequence[str]) -> str:
    positionals: list[str] = []
    options_done = False
    for token in arguments[1:]:
        if not options_done and token == "--":
            options_done = True
            continue
        if not options_done and token in MOVE_FLAGS:
            continue
        if not options_done and token.startswith("-"):
            raise WorktreeCommandError(f"unsupported git worktree move option: {token}")
        positionals.append(token)
    if len(positionals) != 2:
        raise WorktreeCommandError("git worktree move requires source and destination")
    return positionals[1]


def _default_git_common_dir(context: Path) -> Path:
    result = subprocess.run(
        ["git", "-C", os.fspath(context), "rev-parse", "--git-common-dir"],
        check=True,
        capture_output=True,
        text=True,
        timeout=2,
    )
    value = result.stdout.strip()
    if not value:
        raise WorktreeCommandError("git common dir is empty")
    common_dir = Path(value).expanduser()
    if not common_dir.is_absolute():
        common_dir = context / common_dir
    return common_dir.resolve(strict=False)


def _default_git_alias(context: Path, command: str) -> str | None:
    result = subprocess.run(
        ["git", "-C", os.fspath(context), "config", "--get", f"alias.{command}"],
        check=False,
        capture_output=True,
        text=True,
        timeout=1,
    )
    if result.returncode == 1:
        return None
    if result.returncode != 0:
        raise WorktreeCommandError(f"cannot resolve git alias {command}")
    value = result.stdout.strip()
    return value or None


def _canonical_repository(context: Path, resolver: GitCommonDirResolver) -> Path:
    try:
        common_dir = resolver(context)
    except (OSError, subprocess.SubprocessError) as error:
        raise WorktreeCommandError(f"cannot resolve git common dir: {error}") from error
    if common_dir.name != ".git":
        raise WorktreeCommandError(f"unsupported git common dir: {common_dir}")
    return common_dir.parent.resolve(strict=False)


def _validate_destination(
    destination: str,
    context: Path,
    projects_root: Path,
    resolver: GitCommonDirResolver,
) -> str | None:
    canonical = _canonical_repository(context, resolver)
    resolved_projects = projects_root.expanduser().resolve(strict=False)
    if canonical.parent != resolved_projects or canonical.name == ".worktrees":
        return (
            "canonical repository must be an immediate child of "
            f"{resolved_projects}; current repository resolves to {canonical}"
        )

    raw_target = Path(destination).expanduser()
    if not raw_target.is_absolute():
        raw_target = context / raw_target
    target = raw_target.resolve(strict=False)
    worktrees_root = (resolved_projects / ".worktrees").resolve(strict=False)
    expected_parent = (worktrees_root / canonical.name).resolve(strict=False)
    if expected_parent.parent != worktrees_root:
        return f"worktree group escapes the managed root: {expected_parent}"
    if target.parent != expected_parent or not target.name:
        return (
            "worktree destination must be "
            f"{resolved_projects}/.worktrees/{canonical.name}/<worktree>; got {target}"
        )
    return None


def _worktree_destination(arguments: Sequence[str]) -> str | None:
    if len(arguments) < 2 or arguments[0] != "worktree":
        return None
    action = arguments[1]
    if action == "add":
        return _add_destination(arguments[1:])
    if action == "move":
        return _move_destination(arguments[1:])
    return None


def _expand_git_alias(
    arguments: Sequence[str],
    context: Path,
    temporary_aliases: dict[str, str],
    alias_resolver: GitAliasResolver,
) -> tuple[list[str] | None, str | None]:
    expanded = list(arguments)
    seen: set[str] = set()
    for _ in range(MAX_NESTING):
        if not expanded or expanded[0] == "worktree":
            return expanded, None
        command = expanded[0].casefold()
        if command in seen:
            raise WorktreeCommandError(f"recursive git alias: {command}")
        seen.add(command)
        alias = temporary_aliases.get(command)
        if alias is None:
            alias = alias_resolver(context, command)
        if alias is None:
            return None, None
        remainder = expanded[1:]
        if alias.startswith("!"):
            shell_command = alias[1:]
            if remainder:
                shell_command = f"{shell_command} {shlex.join(remainder)}"
            return None, shell_command
        try:
            expanded = shlex.split(alias, posix=True) + remainder
        except ValueError as error:
            if WORKTREE_MUTATION.search(alias):
                raise WorktreeCommandError(f"cannot parse worktree git alias {command}: {error}") from error
            return None, None
    if any(token == "worktree" for token in expanded):
        raise WorktreeCommandError("git alias expansion depth exceeded")
    return None, None


def _evaluate_git_segment(
    git_segment: Sequence[str],
    cwd: Path,
    *,
    projects_root: Path,
    resolver: GitCommonDirResolver,
    alias_resolver: GitAliasResolver,
    cwd_uncertain: bool,
    repository_environment_uncertain: bool,
    alias_environment_uncertain: bool,
    depth: int,
) -> str | None:
    (
        context,
        arguments,
        context_independent_of_cwd,
        temporary_aliases,
        alias_configuration_uncertain,
    ) = _git_context_and_arguments(git_segment, cwd)
    alias_environment_uncertain = alias_environment_uncertain or alias_configuration_uncertain
    expanded, shell_alias = _expand_git_alias(arguments, context, temporary_aliases, alias_resolver)
    if shell_alias is not None:
        nested_reason = _deny_reason_for_command(
            shell_alias,
            context,
            projects_root=projects_root,
            resolver=resolver,
            alias_resolver=alias_resolver,
            cwd_uncertain=cwd_uncertain and not context_independent_of_cwd,
            repository_environment_uncertain=repository_environment_uncertain,
            alias_environment_uncertain=alias_environment_uncertain,
            depth=depth + 1,
        )
        if nested_reason is not None:
            return nested_reason
        if WORKTREE_MUTATION.search(shell_alias):
            return "cannot safely validate worktree mutation inside shell git alias"
        return None
    if expanded is None:
        if (repository_environment_uncertain or alias_environment_uncertain) and arguments:
            return "cannot safely resolve git subcommand with overridden repository or Git configuration environment"
        return None
    destination = _worktree_destination(expanded)
    if destination is None:
        return None
    if repository_environment_uncertain or alias_environment_uncertain:
        return "git worktree mutation must not override repository or Git configuration environment"
    if cwd_uncertain and not context_independent_of_cwd:
        return "git worktree mutation after cwd change must use an absolute git -C <canonical-repository>"
    return _validate_destination(destination, context, projects_root, resolver)


def _deny_reason_for_command(
    command: str,
    cwd: Path,
    *,
    projects_root: Path,
    resolver: GitCommonDirResolver,
    alias_resolver: GitAliasResolver,
    cwd_uncertain: bool,
    repository_environment_uncertain: bool,
    alias_environment_uncertain: bool,
    depth: int,
) -> str | None:
    if depth > MAX_NESTING:
        if WORKTREE_MUTATION.search(command):
            return "cannot safely validate nested git worktree mutation"
        return None
    try:
        tokens = _shell_tokens(command)
    except ValueError as error:
        if WORKTREE_MUTATION.search(command):
            return f"cannot safely parse git worktree mutation: {error}"
        return None

    saw_cd = cwd_uncertain
    saw_repository_environment_override = repository_environment_uncertain
    saw_alias_environment_override = alias_environment_uncertain
    for segment in _command_segments(tokens):
        prefix = _command_prefix(segment)
        executable_index = prefix.executable_index
        segment_cwd_uncertain = saw_cd or prefix.cwd_uncertain
        segment_repository_environment_uncertain = (
            saw_repository_environment_override or prefix.repository_environment_uncertain
        )
        segment_alias_environment_uncertain = (
            saw_alias_environment_override or prefix.alias_environment_uncertain
        )
        if prefix.split_command is not None:
            reason = _deny_reason_for_command(
                prefix.split_command,
                cwd,
                projects_root=projects_root,
                resolver=resolver,
                alias_resolver=alias_resolver,
                cwd_uncertain=segment_cwd_uncertain,
                repository_environment_uncertain=segment_repository_environment_uncertain,
                alias_environment_uncertain=segment_alias_environment_uncertain,
                depth=depth + 1,
            )
            if reason is not None:
                return reason
            if WORKTREE_MUTATION.search(prefix.split_command):
                return "cannot safely validate worktree mutation inside env split-string"
            continue
        if executable_index is None:
            continue
        executable = Path(segment[executable_index]).name
        raw_executable = segment[executable_index]
        if executable in {"cd", "pushd", "popd"}:
            saw_cd = True
            continue
        if executable in {"source", "."} or raw_executable == ".":
            saw_cd = True
            saw_repository_environment_override = True
            saw_alias_environment_override = True
            continue
        persistent_repository_effect, persistent_alias_effect = _persistent_environment_effect(
            executable,
            segment[executable_index + 1 :],
        )
        if persistent_repository_effect or persistent_alias_effect:
            saw_repository_environment_override = (
                saw_repository_environment_override or persistent_repository_effect
            )
            saw_alias_environment_override = saw_alias_environment_override or persistent_alias_effect
            continue
        if executable in SHELL_EXECUTABLES:
            try:
                nested_command = _shell_inline_command(segment, executable_index)
            except WorktreeCommandError as error:
                if WORKTREE_MUTATION.search(command):
                    return f"cannot safely validate nested worktree mutation: {error}"
                continue
            if nested_command is not None:
                reason = _deny_reason_for_command(
                    nested_command,
                    cwd,
                    projects_root=projects_root,
                    resolver=resolver,
                    alias_resolver=alias_resolver,
                    cwd_uncertain=segment_cwd_uncertain,
                    repository_environment_uncertain=segment_repository_environment_uncertain,
                    alias_environment_uncertain=segment_alias_environment_uncertain,
                    depth=depth + 1,
                )
                if reason is not None:
                    return reason
            continue
        if executable == "eval":
            nested_command = shlex.join(segment[executable_index + 1 :])
            reason = _deny_reason_for_command(
                nested_command,
                cwd,
                projects_root=projects_root,
                resolver=resolver,
                alias_resolver=alias_resolver,
                cwd_uncertain=segment_cwd_uncertain,
                repository_environment_uncertain=segment_repository_environment_uncertain,
                alias_environment_uncertain=segment_alias_environment_uncertain,
                depth=depth + 1,
            )
            if reason is not None:
                return reason
            saw_cd = True
            saw_repository_environment_override = True
            saw_alias_environment_override = True
            continue
        if executable != "git":
            continue
        try:
            reason = _evaluate_git_segment(
                segment[executable_index:],
                cwd.resolve(strict=False),
                projects_root=projects_root,
                resolver=resolver,
                alias_resolver=alias_resolver,
                cwd_uncertain=segment_cwd_uncertain,
                repository_environment_uncertain=segment_repository_environment_uncertain,
                alias_environment_uncertain=segment_alias_environment_uncertain,
                depth=depth,
            )
        except (OSError, subprocess.SubprocessError, WorktreeCommandError) as error:
            return f"cannot safely validate git worktree mutation: {error}"
        if reason is not None:
            return reason
    return None


def deny_reason_for_command(
    command: str,
    cwd: Path,
    *,
    projects_root: Path = PROJECTS_ROOT,
    resolver: GitCommonDirResolver = _default_git_common_dir,
    alias_resolver: GitAliasResolver = _default_git_alias,
) -> str | None:
    return _deny_reason_for_command(
        command,
        cwd.resolve(strict=False),
        projects_root=projects_root,
        resolver=resolver,
        alias_resolver=alias_resolver,
        cwd_uncertain=False,
        repository_environment_uncertain=False,
        alias_environment_uncertain=False,
        depth=0,
    )


def _deny(reason: str) -> None:
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": reason,
                }
            },
            ensure_ascii=False,
        )
    )


def main(*, projects_root: Path = PROJECTS_ROOT) -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return 0
    if not isinstance(payload, dict):
        return 0
    if payload.get("hook_event_name") != "PreToolUse" or payload.get("tool_name") != "Bash":
        return 0
    tool_input = payload.get("tool_input")
    if not isinstance(tool_input, dict):
        return 0
    command = tool_input.get("command")
    cwd_value = payload.get("cwd")
    if not isinstance(command, str) or not isinstance(cwd_value, str):
        return 0
    reason = deny_reason_for_command(command, Path(cwd_value), projects_root=projects_root)
    if reason is not None:
        _deny(reason)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
