"""Explicit native table and folder-to-folder note move regression."""
import argparse
from pathlib import Path
import sys
import tempfile
import uuid

FILES = Path(__file__).resolve().parents[1] / 'files'
sys.path.insert(0, str(FILES))
import memo_sync as memo


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--create', action='store_true', required=True)
    parser.parse_args()
    source = memo.Notes(FILES / 'notes.js')
    title = 'memo-sync tables moves test ' + uuid.uuid4().hex[:8]
    text = ('# ' + title + '\n\n## Heading\n\n**bold** and *italic* 日本語 🌱 & < >\n\n'
            '- first\n  - nested\n- second\n\n`inline`\n\n```\n  indented\tcode\n```\n\n'
            '| A | B | C |\n|:---|:---:|---:|\n|one|日本語|three|\n|aa||cc|\n\nTAIL\n')
    original_folder = source.ensure_folder([])
    note = source.create(original_folder, text, markdown=True)
    created_folders = []
    try:
        try:
            memo.verify_markdown(note, text)
        except ValueError as error:
            raise AssertionError((str(error), note.html)) from error
        with tempfile.TemporaryDirectory(prefix='memo-tables-moves-live-') as temporary:
            workspace = memo.Workspace(Path(temporary)/'memo', source)
            workspace.markdown(True)
            path = workspace.register(note.id, sync=True)
            text = text.replace('one', 'EDITED')
            path.write_text(text)
            assert workspace.inspect(path.name, sync=True)[0]['status'] == 'in_sync'
            before = source.read(note.id)
            target = workspace.root / (title + ' destination') / path.name
            target.parent.mkdir()
            path.rename(target)
            workspace.move_local(path.name, target.relative_to(workspace.root).as_posix())
            moved = source.read(note.id)
            assert moved.id == note.id and moved.fingerprint == before.fingerprint
            created_folders.append(source.ensure_folder(list(moved.folder)))
            source.move(moved, original_folder)
            workspace.discover_local(filenames=set())
            assert path.read_text() == text and not target.exists()
            assert workspace.inspect(path.name)[0]['status'] == 'in_sync'
            memo.verify_markdown(source.read(note.id), text)
            source.replace(source.read(note.id), text.replace('EDITED', 'REMOTE CELL'), markdown=True)
            assert workspace.inspect(path.name, sync=True)[0]['status'] == 'in_sync'
            assert 'REMOTE CELL' in path.read_text()
            memo.verify_markdown(source.read(note.id), path.read_text())
            print('PASS: native table create/edit/pull, both move directions, stable ID and content')
    finally:
        current = source.read(note.id)
        if current and current.title == title:
            source.trash(current)
        for folder in created_folders:
            source.delete_folder(folder)


if __name__ == '__main__':
    main()
