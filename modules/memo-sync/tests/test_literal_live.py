"""Explicit native regression for literal Markdown fallback and continued editing."""
from pathlib import Path
import argparse
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
    title = 'memo-sync literal test ' + uuid.uuid4().hex[:8]
    with tempfile.TemporaryDirectory(prefix='memo-literal-live-') as temporary:
        workspace = memo.Workspace(Path(temporary) / 'memo', source)
        workspace.markdown(True)
        workspace.discover_local()
        path = workspace.root / 'Literal.md'
        text = ('# ' + title + '\n\n| A | B |\n|---|---|\n|one|two|\n')
        path.write_text(text)
        assert not workspace.discover_local(filenames={path.name})
        note_id = next(k for k, r in workspace.state()['notes'].items() if r['file'] == path.name)
        try:
            text += '\n---\n### Third\n\n> quote\n\n![image](missing.png)\n\n<a href="https://example.com">HTML</a>\n'
            path.write_text(text)
            result = workspace.inspect(path.name, sync=True)[0]
            assert result['status'] == 'in_sync', result.get('error')
            assert source.read(note_id).text == text
            assert workspace.state()['notes'][note_id]['literal']
            source.replace(source.read(note_id), text + 'REMOTE\n', literal=True)
            assert workspace.inspect(path.name, sync=True)[0]['status'] == 'in_sync'
            assert path.read_text() == text + 'REMOTE\n'
            path.write_text(path.read_text() + 'LOCAL\n')
            assert workspace.inspect(path.name, sync=True)[0]['status'] == 'in_sync'
            assert source.read(note_id).text == text + 'REMOTE\nLOCAL\n'
            print('PASS: native table-to-literal fallback, HTML/image syntax retained, bidirectional edits')
        finally:
            current = source.read(note_id)
            if current and title in current.title:
                source.trash(current)


if __name__ == '__main__':
    main()
