import importlib.util
import os
import subprocess
import sys
import tempfile
import unicodedata
import unittest
from pathlib import Path


REPOSITORY = Path(
    os.environ.get("DOTFILES_REPOSITORY", Path(__file__).resolve().parents[3])
)
SCRIPT = REPOSITORY / "modules/vault-context/files/project-context-init.py"
SPEC = importlib.util.spec_from_file_location("project_context_init", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def run(*args: str, cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=cwd, check=True, capture_output=True, text=True)


def record_text(
    summary: str = "One-line summary",
    sources: tuple[str, ...] = (),
    status: str = "unverified",
    promoted_to: str = "null",
    body: str = "Body.\n",
) -> str:
    source_lines = "".join(f"  - {source}\n" for source in sources)
    return (
        "---\n"
        "title: Example record\n"
        f"summary: {summary}\n"
        "created: 2026-11-11\n"
        + (f"sources:\n{source_lines}" if sources else "sources: []\n")
        + f"status: {status}\n"
        f"promoted_to: {promoted_to}\n"
        "---\n\n"
        + body
    )


class ProjectContextInitTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name) / "project"
        self.root.mkdir()

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def test_non_git_project_uses_root_context_and_agent_entrypoint(self) -> None:
        changes = MODULE.initialize(self.root, "Example")

        self.assertTrue(changes)
        self.assertFalse((self.root / "context").is_symlink())
        self.assertIn("非Git project", (self.root / "context/README.md").read_text())
        self.assertIn(MODULE.TEMPLATE_VERSION, (self.root / "context/README.md").read_text())
        self.assertTrue((self.root / "context/canonical").is_dir())
        self.assertFalse((self.root / "context/canonical/facts").exists())
        self.assertTrue((self.root / "context/canonical/user").is_dir())
        self.assertTrue((self.root / "context/canonical/sources/internal").is_dir())
        self.assertTrue((self.root / "context/canonical/sources/external").is_dir())
        self.assertFalse((self.root / "context/sources").exists())
        for responsibility in MODULE.RESPONSIBILITIES:
            self.assertTrue((self.root / "context/ai_output" / responsibility).is_dir())
        self.assertFalse((self.root / "context/ai_output/index.html").exists())
        self.assertEqual((self.root / "context/ai_output/README.md").read_text(), MODULE.AI_OUTPUT_README)
        self.assertIn(MODULE.INDEX_HEADER, (self.root / "context/INDEX.md").read_text())
        self.assertFalse((self.root / "context/.gitignore").exists())
        self.assertIn(MODULE.MARKER, (self.root / "AGENTS.md").read_text())
        self.assertIn("context/INDEX.md", (self.root / "AGENTS.md").read_text())
        self.assertIn(MODULE.TEMPLATE_VERSION, (self.root / "AGENTS.md").read_text())
        self.assertEqual(MODULE.initialize(self.root, "Example"), [])

    def test_git_project_moves_context_to_common_dir_without_dirtying_tree(self) -> None:
        run("git", "init", "--initial-branch=main", cwd=self.root)
        run("git", "config", "user.name", "Context Test", cwd=self.root)
        run("git", "config", "user.email", "context@example.invalid", cwd=self.root)
        seed = self.root / "seed"
        seed.write_text("seed\n", encoding="utf-8")
        run("git", "add", "seed", cwd=self.root)
        run("git", "commit", "-m", "seed", cwd=self.root)
        context = self.root / "context"
        context.mkdir()
        (context / "README.md").write_text(MODULE.legacy_context_readme("Example"), encoding="utf-8")
        (context / ".gitignore").write_text(MODULE.LEGACY_CONTEXT_GITIGNORE, encoding="utf-8")
        (self.root / "AGENTS.md").write_text(
            f"<INSTRUCTIONS>\n{MODULE.LEGACY_AGENT_BLOCK}</INSTRUCTIONS>\n",
            encoding="utf-8",
        )

        MODULE.initialize(self.root, "Example")

        target = self.root / ".git/project-context"
        self.assertTrue((self.root / "context").is_symlink())
        self.assertEqual((self.root / "context").resolve(), target.resolve())
        self.assertTrue((target / "canonical").is_dir())
        self.assertFalse((target / "canonical/facts").exists())
        for responsibility in MODULE.RESPONSIBILITIES:
            self.assertTrue((target / "ai_output" / responsibility).is_dir())
        self.assertTrue((target / "ai_output/README.md").is_file())
        self.assertFalse((target / "ai_output/index.html").exists())
        self.assertTrue((target / "INDEX.md").is_file())
        self.assertFalse((target / ".gitignore").exists())
        self.assertFalse((self.root / "AGENTS.md").exists())
        self.assertIn("/context", (self.root / ".git/info/exclude").read_text())
        self.assertEqual(run("git", "status", "--short", cwd=self.root).stdout, "")
        self.assertEqual(MODULE.initialize(self.root, "Example"), [])

        worktree = self.root.parent / "linked"
        run("git", "worktree", "add", "--detach", str(worktree), "HEAD", cwd=self.root)
        linked_common = run(
            "git", "rev-parse", "--path-format=absolute", "--git-common-dir", cwd=worktree
        ).stdout.strip()
        self.assertEqual(Path(linked_common).resolve(), (self.root / ".git").resolve())
        self.assertTrue((Path(linked_common) / "project-context/README.md").is_file())

    def test_git_migration_preserves_existing_agent_content(self) -> None:
        run("git", "init", "--initial-branch=main", cwd=self.root)
        agents = self.root / "AGENTS.md"
        agents.write_text(
            f"<INSTRUCTIONS>\nexisting\n\n{MODULE.LEGACY_AGENT_BLOCK}</INSTRUCTIONS>\n",
            encoding="utf-8",
        )

        MODULE.initialize(self.root, "Example")

        self.assertEqual(agents.read_text(encoding="utf-8"), "<INSTRUCTIONS>\nexisting\n</INSTRUCTIONS>\n")

    def test_custom_existing_context_file_is_not_overwritten(self) -> None:
        readme = self.root / "context/README.md"
        readme.parent.mkdir()
        readme.write_text("custom\n", encoding="utf-8")

        MODULE.initialize(self.root, "Example")

        self.assertEqual(readme.read_text(encoding="utf-8"), "custom\n")

    def test_previous_ai_output_readme_migrates_to_markdown_policy(self) -> None:
        markdown = self.root / "context/ai_output/README.md"
        markdown.parent.mkdir(parents=True)
        markdown.write_text(MODULE.PREVIOUS_AI_OUTPUT_README, encoding="utf-8")

        MODULE.initialize(self.root, "Example")

        self.assertEqual(markdown.read_text(encoding="utf-8"), MODULE.AI_OUTPUT_README)
        self.assertFalse((self.root / "context/ai_output/index.html").exists())

    def test_every_previous_html_index_is_replaced_by_markdown_policy(self) -> None:
        for previous in MODULE.PREVIOUS_AI_OUTPUT_INDEXES:
            with self.subTest(previous=previous[:80]):
                html = self.root / "context/ai_output/index.html"
                html.parent.mkdir(parents=True, exist_ok=True)
                html.write_text(previous, encoding="utf-8")

                MODULE.initialize(self.root, "Example")

                self.assertFalse(html.exists())
                self.assertEqual((html.parent / "README.md").read_text(), MODULE.AI_OUTPUT_README)
                for responsibility in MODULE.RESPONSIBILITIES:
                    self.assertTrue((html.parent / responsibility).is_dir())

    def test_previous_html_context_and_agent_block_upgrade_to_current_template(self) -> None:
        context = self.root / "context"
        context.mkdir()
        readme = context / "README.md"
        readme.write_text(MODULE.previous_html_context_readme("Example", False), encoding="utf-8")
        agents = self.root / "AGENTS.md"
        agents.write_text(
            f"<INSTRUCTIONS>\n{MODULE.PREVIOUS_HTML_AGENT_BLOCK}</INSTRUCTIONS>\n",
            encoding="utf-8",
        )

        MODULE.initialize(self.root, "Example")

        self.assertEqual(readme.read_text(encoding="utf-8"), MODULE.context_readme("Example", False))
        self.assertEqual(agents.read_text(encoding="utf-8").count(MODULE.MARKER), 1)
        self.assertIn(MODULE.TEMPLATE_VERSION, agents.read_text(encoding="utf-8"))

    def test_previous_v2_upgrades_without_changing_records_or_custom_agent_text(self) -> None:
        context = self.root / "context"
        record = context / "canonical/decisions/choice.md"
        record.parent.mkdir(parents=True)
        record.write_text("# Approved choice\nKeep this decision.\n", encoding="utf-8")
        (context / "README.md").write_text(
            MODULE.previous_v2_context_readme("Example", False), encoding="utf-8"
        )
        agents = self.root / "AGENTS.md"
        agents.write_text(
            f"Custom before\n\n{MODULE.PREVIOUS_V2_AGENT_BLOCK}\nCustom after\n",
            encoding="utf-8",
        )

        MODULE.initialize(self.root, "Example")

        self.assertEqual(record.read_text(), "# Approved choice\nKeep this decision.\n")
        self.assertEqual((context / "README.md").read_text(), MODULE.context_readme("Example", False))
        self.assertEqual(
            agents.read_text(), f"Custom before\n\n{MODULE.AGENT_BLOCK}\nCustom after\n"
        )
        self.assertEqual(MODULE.initialize(self.root, "Example"), [])

    def test_empty_v2_canonical_directories_are_removed_and_others_kept(self) -> None:
        context = self.root / "context"
        for name in ("facts", "risks", "workflows"):
            (context / "canonical" / name).mkdir(parents=True)
        record = context / "canonical/decisions/choice.md"
        record.parent.mkdir(parents=True)
        record.write_text("# Choice\n", encoding="utf-8")
        (context / "canonical/open_questions/nested").mkdir(parents=True)

        changes = MODULE.initialize(self.root, "Example")

        for name in ("facts", "risks", "workflows"):
            self.assertFalse((context / "canonical" / name).exists())
            self.assertIn(str(context / "canonical" / name), changes)
        self.assertEqual(record.read_text(), "# Choice\n")
        self.assertTrue((context / "canonical/open_questions/nested").is_dir())
        self.assertEqual(MODULE.initialize(self.root, "Example"), [])

    def test_customized_v2_readme_is_preserved(self) -> None:
        context = self.root / "context"
        context.mkdir()
        readme = context / "README.md"
        custom = MODULE.previous_v2_context_readme("Example", False) + "\nCustom project policy\n"
        readme.write_text(custom, encoding="utf-8")

        MODULE.initialize(self.root, "Example")

        self.assertEqual(readme.read_text(), custom)

    def test_git_v2_upgrade_keeps_shared_context_and_records(self) -> None:
        run("git", "init", "--initial-branch=main", cwd=self.root)
        MODULE.initialize(self.root, "Example")
        context = self.root / ".git/project-context"
        (context / "README.md").write_text(
            MODULE.previous_v2_context_readme("Example", True), encoding="utf-8"
        )
        record = context / "canonical/decisions/choice.md"
        record.parent.mkdir(parents=True, exist_ok=True)
        record.write_text("shared decision\n", encoding="utf-8")

        MODULE.initialize(self.root, "Example")

        self.assertEqual((self.root / "context").resolve(), context.resolve())
        self.assertEqual(record.read_text(), "shared decision\n")
        self.assertEqual((context / "README.md").read_text(), MODULE.context_readme("Example", True))
        self.assertEqual(MODULE.initialize(self.root, "Example"), [])

    def test_provenance_upgrade_preserves_raw_and_legacy_records(self) -> None:
        context = self.root / "context"
        (context / "canonical/risks").mkdir(parents=True)
        (context / "sources/internal").mkdir(parents=True)
        (context / "sources/external").mkdir(parents=True)
        (context / "ai_output/risks").mkdir(parents=True)
        previous = {
            "README.md": MODULE.previous_on_demand_context_readme("Example", False),
            "canonical/README.md": MODULE.PREVIOUS_CANONICAL_README,
            "sources/internal/README.md": MODULE.PREVIOUS_INTERNAL_README,
            "sources/external/README.md": MODULE.PREVIOUS_EXTERNAL_README,
            "ai_output/index.html": MODULE.PREVIOUS_V2_AI_OUTPUT_INDEX,
        }
        for name, content in previous.items():
            (context / name).write_text(content, encoding="utf-8")
        attachment = context / "sources/internal/original.pdf"
        attachment.write_bytes(b"%PDF-1.7\n\x00\xfforiginal bytes\n")
        records = {
            "canonical/raw-user.md": "---\nsource_kind: user\n---\n\naiのautoputは、  別に。\n",
            "canonical/risks/legacy.md": "# AI analysis under v2\nPreserve for origin review.\n",
            "ai_output/risks/current.md": record_text(summary="Preserve."),
        }
        for name, content in records.items():
            (context / name).write_text(content, encoding="utf-8")
        agents = self.root / "AGENTS.md"
        agents.write_text("Custom before\n" + MODULE.PREVIOUS_ON_DEMAND_AGENT_BLOCK + "Custom after\n")

        MODULE.initialize(self.root, "Example")

        self.assertEqual((context / "README.md").read_text(), MODULE.context_readme("Example", False))
        self.assertEqual((context / "canonical/README.md").read_text(), MODULE.CANONICAL_README)
        self.assertEqual((context / "canonical/sources/internal/README.md").read_text(), MODULE.INTERNAL_README)
        self.assertEqual((context / "canonical/sources/external/README.md").read_text(), MODULE.EXTERNAL_README)
        self.assertEqual((context / "canonical/sources/internal/original.pdf").read_bytes(), b"%PDF-1.7\n\x00\xfforiginal bytes\n")
        self.assertFalse((context / "sources").exists())
        self.assertEqual((context / "ai_output/README.md").read_text(), MODULE.AI_OUTPUT_README)
        self.assertFalse((context / "ai_output/index.html").exists())
        self.assertEqual(agents.read_text(), "Custom before\n" + MODULE.AGENT_BLOCK + "Custom after\n")
        for name, content in records.items():
            self.assertEqual((context / name).read_text(), content)
        self.assertEqual(MODULE.initialize(self.root, "Example"), [])

    def test_initialization_policy_upgrade_preserves_records_and_custom_instructions(self) -> None:
        MODULE.initialize(self.root, "Example")
        context = self.root / "context"
        readme = context / "README.md"
        readme.write_text(MODULE.previous_manual_capture_context_readme("Example", False))
        agents = self.root / "AGENTS.md"
        agents.write_text("Custom before\n" + MODULE.PREVIOUS_MANUAL_CAPTURE_AGENT_BLOCK + "Custom after\n")
        record = context / "canonical/user/original.md"
        record.write_bytes("ユーザーの原文をそのまま。\n".encode())
        contents = record.read_bytes()

        MODULE.initialize(self.root, "Example")

        self.assertEqual(readme.read_text(), MODULE.context_readme("Example", False))
        self.assertEqual(agents.read_text(), "Custom before\n" + MODULE.AGENT_BLOCK + "Custom after\n")
        self.assertEqual(record.read_bytes(), contents)
        self.assertEqual(list((context / "canonical/user").iterdir()), [record])
        self.assertEqual(MODULE.initialize(self.root, "Example"), [])

    def test_sources_collision_preserves_both_trees_before_git_migration(self) -> None:
        run("git", "init", "--initial-branch=main", cwd=self.root)
        context = self.root / "context"
        legacy = context / "sources/internal/source.md"
        destination = context / "canonical/sources/internal/source.md"
        for path, text in [(legacy, "legacy"), (destination, "existing")]:
            path.parent.mkdir(parents=True)
            path.write_text(text)

        with self.assertRaisesRegex(ValueError, "both legacy sources and canonical/sources"):
            MODULE.initialize(self.root, "Example")

        self.assertEqual(legacy.read_text(), "legacy")
        self.assertEqual(destination.read_text(), "existing")
        self.assertFalse(context.is_symlink())
        self.assertFalse((self.root / ".git/project-context").exists())

    def test_sources_symlink_is_rejected_before_initialization(self) -> None:
        context = self.root / "context"
        context.mkdir()
        external = self.root.parent / "external"
        external.mkdir()
        (context / "sources").symlink_to(external, target_is_directory=True)

        with self.assertRaisesRegex(ValueError, "managed directory must not be a symlink"):
            MODULE.initialize(self.root, "Example")

        self.assertEqual(list(external.iterdir()), [])
        self.assertFalse((context / "canonical").exists())
        self.assertFalse((self.root / "AGENTS.md").exists())

    def test_custom_ai_output_markdown_fails_closed(self) -> None:
        markdown = self.root / "context/ai_output/README.md"
        markdown.parent.mkdir(parents=True)
        markdown.write_text("custom output\n", encoding="utf-8")

        with self.assertRaisesRegex(ValueError, "custom AI output Markdown exists"):
            MODULE.initialize(self.root, "Example")

        self.assertEqual(markdown.read_text(encoding="utf-8"), "custom output\n")
        self.assertFalse((self.root / "context/ai_output/index.html").exists())
        self.assertFalse((self.root / "AGENTS.md").exists())

    def test_custom_ai_output_index_fails_closed(self) -> None:
        html = self.root / "context/ai_output/index.html"
        html.parent.mkdir(parents=True)
        html.write_text("<!doctype html><title>custom</title>\n", encoding="utf-8")

        with self.assertRaisesRegex(ValueError, "custom AI output index exists"):
            MODULE.initialize(self.root, "Example")

        self.assertEqual(html.read_text(encoding="utf-8"), "<!doctype html><title>custom</title>\n")
        self.assertFalse((self.root / "AGENTS.md").exists())

    def test_ai_output_root_markdown_artifact_requires_manual_classification(self) -> None:
        artifact = self.root / "context/ai_output/report.md"
        artifact.parent.mkdir(parents=True)
        artifact.write_text("# Report\n", encoding="utf-8")

        with self.assertRaisesRegex(ValueError, "requires manual classification"):
            MODULE.initialize(self.root, "Example")

        self.assertEqual(artifact.read_text(encoding="utf-8"), "# Report\n")
        self.assertFalse((self.root / "context/ai_output/README.md").exists())

    def test_ai_output_root_html_artifact_requires_manual_classification(self) -> None:
        artifact = self.root / "context/ai_output/report.html"
        artifact.parent.mkdir(parents=True)
        artifact.write_text("<!doctype html><title>Report</title>\n", encoding="utf-8")

        with self.assertRaisesRegex(ValueError, "requires manual classification"):
            MODULE.initialize(self.root, "Example")

        self.assertTrue(artifact.is_file())
        self.assertFalse((self.root / "AGENTS.md").exists())

    def test_custom_ai_output_responsibility_directory_fails_closed(self) -> None:
        custom = self.root / "context/ai_output/reports"
        custom.mkdir(parents=True)

        with self.assertRaisesRegex(ValueError, "requires manual classification"):
            MODULE.initialize(self.root, "Example")

        self.assertTrue(custom.is_dir())
        self.assertFalse((self.root / "AGENTS.md").exists())

    def test_non_markdown_artifact_in_responsibility_directory_fails_closed(self) -> None:
        artifact = self.root / "context/ai_output/facts/report.txt"
        artifact.parent.mkdir(parents=True)
        artifact.write_text("report\n", encoding="utf-8")

        with self.assertRaisesRegex(ValueError, "artifact must be Markdown"):
            MODULE.initialize(self.root, "Example")

        self.assertEqual(artifact.read_text(encoding="utf-8"), "report\n")
        self.assertFalse((self.root / "AGENTS.md").exists())

    def test_interrupted_ai_output_policy_migration_resumes(self) -> None:
        ai_output = self.root / "context/ai_output"
        ai_output.mkdir(parents=True)
        markdown = ai_output / "README.md"
        html = ai_output / "index.html"
        markdown.write_text(MODULE.AI_OUTPUT_README, encoding="utf-8")
        html.write_text(MODULE.PREVIOUS_V3_AI_OUTPUT_INDEX, encoding="utf-8")

        MODULE.initialize(self.root, "Example")

        self.assertFalse(html.exists())
        self.assertEqual(markdown.read_text(encoding="utf-8"), MODULE.AI_OUTPUT_README)

    def test_git_migration_fails_closed_on_target_collision(self) -> None:
        run("git", "init", "--initial-branch=main", cwd=self.root)
        (self.root / "context").mkdir()
        (self.root / ".git/project-context").mkdir()

        with self.assertRaisesRegex(ValueError, "both context source and target exist"):
            MODULE.initialize(self.root, "Example")

    def test_git_migration_rejects_common_dir_context_symlink(self) -> None:
        run("git", "init", "--initial-branch=main", cwd=self.root)
        external = self.root.parent / "external"
        external.mkdir()
        (self.root / ".git/project-context").symlink_to(external, target_is_directory=True)

        with self.assertRaisesRegex(ValueError, "Git common-dir context must not be a symlink"):
            MODULE.initialize(self.root, "Example")

        self.assertEqual(list(external.iterdir()), [])

    def test_non_git_project_rejects_context_symlink(self) -> None:
        external = self.root.parent / "external"
        external.mkdir()
        (self.root / "context").symlink_to(external, target_is_directory=True)

        with self.assertRaisesRegex(ValueError, "context root must not be a symlink"):
            MODULE.initialize(self.root, "Example")

        self.assertEqual(list(external.iterdir()), [])

    def test_git_project_normalizes_relative_context_symlink(self) -> None:
        run("git", "init", "--initial-branch=main", cwd=self.root)
        (self.root / ".git/project-context").mkdir()
        context = self.root / "context"
        context.symlink_to(".git/project-context", target_is_directory=True)

        MODULE.initialize(self.root, "Example")

        self.assertTrue(context.readlink().is_absolute())
        self.assertEqual(context.resolve(), (self.root / ".git/project-context").resolve())

    def test_git_project_repairs_dangling_expected_context_symlink(self) -> None:
        run("git", "init", "--initial-branch=main", cwd=self.root)
        target = self.root / ".git/project-context"
        context = self.root / "context"
        context.symlink_to(target, target_is_directory=True)
        (self.root / "AGENTS.md").write_text(
            f"<INSTRUCTIONS>\n{MODULE.LEGACY_AGENT_BLOCK}</INSTRUCTIONS>\n",
            encoding="utf-8",
        )

        MODULE.initialize(self.root, "Example")

        self.assertTrue(context.is_symlink())
        self.assertTrue(context.readlink().is_absolute())
        self.assertTrue((target / "canonical").is_dir())
        self.assertFalse((self.root / "AGENTS.md").exists())
        self.assertIn("/context", (self.root / ".git/info/exclude").read_text())

    def test_project_rejects_nested_managed_directory_symlink(self) -> None:
        external = self.root.parent / "external"
        external.mkdir()
        context = self.root / "context"
        context.mkdir()
        (context / "canonical").symlink_to(external, target_is_directory=True)

        with self.assertRaisesRegex(ValueError, "managed directory must not be a symlink"):
            MODULE.initialize(self.root, "Example")

        self.assertEqual(list(external.iterdir()), [])

    def test_git_preflight_preserves_source_on_nested_symlink(self) -> None:
        run("git", "init", "--initial-branch=main", cwd=self.root)
        external = self.root.parent / "external"
        external.mkdir()
        context = self.root / "context"
        context.mkdir()
        (context / "canonical").symlink_to(external, target_is_directory=True)

        with self.assertRaisesRegex(ValueError, "managed directory must not be a symlink"):
            MODULE.initialize(self.root, "Example")

        self.assertTrue(context.is_dir())
        self.assertFalse(context.is_symlink())
        self.assertFalse((self.root / ".git/project-context").exists())
        self.assertEqual(list(external.iterdir()), [])

    def test_git_preflight_preserves_source_on_managed_file_symlink(self) -> None:
        run("git", "init", "--initial-branch=main", cwd=self.root)
        external = self.root.parent / "external.md"
        external.write_text("external\n", encoding="utf-8")
        context = self.root / "context"
        context.mkdir()
        (context / "README.md").symlink_to(external)

        with self.assertRaisesRegex(ValueError, "managed file must not be a symlink"):
            MODULE.initialize(self.root, "Example")

        self.assertTrue(context.is_dir())
        self.assertFalse(context.is_symlink())
        self.assertFalse((self.root / ".git/project-context").exists())
        self.assertEqual(external.read_text(encoding="utf-8"), "external\n")

    def test_git_preflight_preserves_source_when_agent_marker_was_edited(self) -> None:
        run("git", "init", "--initial-branch=main", cwd=self.root)
        context = self.root / "context"
        context.mkdir()
        agents = self.root / "AGENTS.md"
        agents.write_text(f"{MODULE.MARKER}\nedited\n", encoding="utf-8")

        with self.assertRaisesRegex(ValueError, "managed AGENTS block was edited"):
            MODULE.initialize(self.root, "Example")

        self.assertTrue(context.is_dir())
        self.assertFalse(context.is_symlink())
        self.assertFalse((self.root / ".git/project-context").exists())
        self.assertEqual(agents.read_text(encoding="utf-8"), f"{MODULE.MARKER}\nedited\n")

    def test_non_git_preflight_rejects_edited_managed_agent_block(self) -> None:
        agents = self.root / "AGENTS.md"
        agents.write_text(f"{MODULE.MARKER}\nedited\n", encoding="utf-8")

        with self.assertRaisesRegex(ValueError, "managed AGENTS block was edited"):
            MODULE.initialize(self.root, "Example")

        self.assertFalse((self.root / "context").exists())
        self.assertEqual(agents.read_text(encoding="utf-8"), f"{MODULE.MARKER}\nedited\n")

    def test_v3_store_with_html_artifact_fails_closed_until_converted(self) -> None:
        context = self.root / "context"
        MODULE.initialize(self.root, "Example")
        readme = context / "README.md"
        readme.write_text(MODULE.previous_v3_context_readme("Example", False))
        (context / "INDEX.md").unlink()
        artifact = context / "ai_output/decisions/choice.html"
        artifact.write_text("<!doctype html><title>Choice</title>\n")

        with self.assertRaisesRegex(ValueError, "requires Markdown conversion"):
            MODULE.initialize(self.root, "Example")

        self.assertEqual(readme.read_text(), MODULE.previous_v3_context_readme("Example", False))
        self.assertTrue(artifact.is_file())
        self.assertFalse((context / "INDEX.md").exists())

    def test_v3_upgrade_indexes_markdown_records_without_changing_them(self) -> None:
        run("git", "init", "--initial-branch=main", cwd=self.root)
        MODULE.initialize(self.root, "Example")
        context = self.root / ".git/project-context"
        (context / "README.md").write_text(MODULE.previous_v3_context_readme("Example", True))
        (context / "ai_output/README.md").unlink()
        (context / "ai_output/index.html").write_text(MODULE.PREVIOUS_V3_AI_OUTPUT_INDEX)
        (context / "INDEX.md").unlink()
        original = context / "canonical/user/2026-11-11-request.md"
        original.write_text("ユーザーの原文。\n")
        unreferenced = context / "canonical/sources/external/spec.pdf"
        unreferenced.write_bytes(b"%PDF\x00")
        record = context / "ai_output/decisions/choice.md"
        contents = record_text(
            summary="Keep the store outside Git",
            sources=("../../canonical/user/2026-11-11-request.md", "https://example.com/spec"),
        )
        record.write_text(contents)
        promoted = context / "ai_output/workflows/release.md"
        promoted.write_text(record_text(status="approved", promoted_to="docs/release.md", body=""))

        MODULE.initialize(self.root, "Example")

        self.assertEqual(record.read_text(), contents)
        self.assertEqual((context / "README.md").read_text(), MODULE.context_readme("Example", True))
        index = (context / "INDEX.md").read_text()
        self.assertIn(
            "- [Example record](ai_output/decisions/choice.md) — Keep the store outside Git `unverified`",
            index,
        )
        self.assertIn("`approved` → `docs/release.md`", index)
        self.assertIn(
            "- [canonical/user/2026-11-11-request.md](canonical/user/2026-11-11-request.md)"
            " ← ai_output/decisions/choice.md",
            index,
        )
        self.assertIn("- [canonical/sources/external/spec.pdf](canonical/sources/external/spec.pdf)\n", index)
        self.assertNotIn("README.md", index)
        self.assertEqual(run("git", "status", "--short", cwd=self.root).stdout, "")
        self.assertEqual(MODULE.initialize(self.root, "Example"), [])

    def test_invalid_frontmatter_fails_closed(self) -> None:
        MODULE.initialize(self.root, "Example")
        context = self.root / "context"
        index = (context / "INDEX.md").read_text()
        cases = {
            "missing summary": "---\ntitle: T\ncreated: 2026-11-11\nsources: []\nstatus: unverified\npromoted_to: null\n---\n",
            "status must be": record_text(status="done"),
            "source is not a file": record_text(sources=("../../canonical/user/missing.md",)),
            "missing frontmatter": "# No frontmatter\n",
            "unknown key": record_text().replace("status:", "owner: me\nstatus:"),
            "repository-relative": record_text(promoted_to="/Users/me/docs/a.md"),
        }
        record = context / "ai_output/facts/bad.md"
        for message, text in cases.items():
            with self.subTest(message=message):
                record.write_text(text)
                with self.assertRaisesRegex(ValueError, message):
                    MODULE.initialize(self.root, "Example")
                with self.assertRaisesRegex(ValueError, message):
                    MODULE.reindex(self.root)
                self.assertEqual((context / "INDEX.md").read_text(), index)

    def test_reindex_regenerates_only_existing_v4_index(self) -> None:
        with self.assertRaisesRegex(ValueError, "INDEX.md not found"):
            MODULE.reindex(self.root)
        MODULE.initialize(self.root, "Example")
        context = self.root / "context"
        (context / "ai_output/risks/leak.md").write_text(record_text(summary="Token may leak"))
        (context / "canonical/sources/internal/spec (1).docx").write_bytes(b"spec")

        self.assertEqual(MODULE.reindex(self.root), [str(context / "INDEX.md")])
        self.assertIn("Token may leak", (context / "INDEX.md").read_text())
        self.assertIn(
            "- [canonical/sources/internal/spec (1).docx](<canonical/sources/internal/spec (1).docx>)",
            (context / "INDEX.md").read_text(),
        )
        self.assertEqual(MODULE.reindex(self.root), [])

        (context / "INDEX.md").write_text("hand written\n")
        with self.assertRaisesRegex(ValueError, "not generated by --reindex"):
            MODULE.reindex(self.root)
        self.assertEqual((context / "INDEX.md").read_text(), "hand written\n")

    def test_git_backup_creates_nested_repository_without_touching_project(self) -> None:
        run("git", "init", "--initial-branch=main", cwd=self.root)
        (self.root / "seed").write_text("seed\n")
        run("git", "add", "seed", cwd=self.root)
        run("git", "-c", "user.name=T", "-c", "user.email=t@example.invalid", "commit", "-m", "seed", cwd=self.root)
        remote = "git@example.invalid:me/context.git"

        changes = MODULE.initialize(self.root, "Example", git_backup=True, remote=remote)

        context = self.root / ".git/project-context"
        self.assertIn((context / ".git").resolve(), [Path(change).resolve() for change in changes])
        self.assertEqual(run("git", "remote", "get-url", "origin", cwd=context).stdout.strip(), remote)
        self.assertEqual(
            Path(run("git", "rev-parse", "--show-toplevel", cwd=self.root / "context/canonical").stdout.strip()).resolve(),
            context.resolve(),
        )
        self.assertNotEqual(subprocess.run(["git", "rev-parse", "HEAD"], cwd=context, capture_output=True).returncode, 0)
        self.assertEqual(run("git", "status", "--short", cwd=self.root).stdout, "")
        self.assertEqual(
            Path(run("git", "rev-parse", "--path-format=absolute", "--git-common-dir", cwd=self.root).stdout.strip()).resolve(),
            (self.root / ".git").resolve(),
        )
        self.assertEqual(MODULE.initialize(self.root, "Example", git_backup=True, remote=remote), [])

        with self.assertRaisesRegex(ValueError, "origin differs"):
            MODULE.initialize(self.root, "Example", git_backup=True, remote="git@example.invalid:other.git")
        self.assertEqual(run("git", "remote", "get-url", "origin", cwd=context).stdout.strip(), remote)

    @unittest.skipUnless(sys.platform == "darwin", "APFS treats NFC and NFD names as the same path")
    def test_git_backup_accepts_nfd_directory_given_as_nfc(self) -> None:
        name = "エグゼクティブ"
        (self.root / unicodedata.normalize("NFD", name)).mkdir()
        root = self.root / unicodedata.normalize("NFC", name)

        MODULE.initialize(root, "Example", git_backup=True)

        self.assertTrue((root / "context/.git").is_dir())
        self.assertEqual(MODULE.initialize(root, "Example", git_backup=True), [])

    def test_git_backup_without_remote_and_remote_without_backup(self) -> None:
        with self.assertRaisesRegex(ValueError, "--remote requires --git-backup"):
            MODULE.initialize(self.root, "Example", remote="git@example.invalid:me/context.git")
        self.assertFalse((self.root / "context").exists())

        MODULE.initialize(self.root, "Example", git_backup=True)

        context = self.root / "context"
        self.assertTrue((context / ".git").is_dir())
        self.assertNotEqual(
            subprocess.run(["git", "remote", "get-url", "origin"], cwd=context, capture_output=True).returncode, 0
        )
        self.assertEqual(MODULE.initialize(self.root, "Example"), [])


if __name__ == "__main__":
    unittest.main()
