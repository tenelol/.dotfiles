"""Explicit native rename regression, including a real Neovim save before renaming."""
from pathlib import Path
import argparse
import json
import subprocess
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
    token = uuid.uuid4().hex[:8]
    title = 'memo-sync rename test ' + token
    with tempfile.TemporaryDirectory(prefix='memo-rename-live-') as temporary:
        workspace = memo.Workspace(Path(temporary) / 'memo', source)
        workspace.markdown(True)
        workspace.discover_local()
        path = workspace.root / (title + '.md')
        original = '# ' + title + '\n\n| A | B |\n|---|---|\n|one|日本語|\n\nBODY\n'
        path.write_text(original)
        assert not workspace.discover_local(filenames={path.name})
        note_id = next(k for k,r in workspace.state()['notes'].items() if r['file'] == path.name)
        try:
            before = path.stat().st_ino
            setup = 'dofile(' + json.dumps(str(FILES/'neovim.lua')) + ').setup(' + json.dumps(str(workspace.root)) + ')'
            subprocess.run(['nvim','--headless','-u','NONE',str(path),'+lua '+setup,
                            '+lua vim.api.nvim_buf_set_lines(0,-1,-1,false,{"SAVED BEFORE RENAME"})',
                            '+write','+qa'],check=True,capture_output=True,text=True,timeout=15)
            assert path.stat().st_ino == before
            body = path.read_text().partition('\n')[2]
            for name in (title.upper(), '日本語 [title] & ' + token):
                previous = path
                path = path.with_name(name + '.md')
                previous.rename(path)
                assert workspace.local_work()[0]['move:'+previous.name] == path.name
                workspace.move_local(previous.name,path.name)
                result = workspace.inspect(path.name,sync=True)[0]
                assert result['status'] == 'in_sync', result.get('error')
                current = source.read(note_id)
                assert current.id == note_id and current.title == name, current.title
                assert path.read_text().partition('\n')[2] == body
                memo.verify_markdown(current,path.read_text())
            print('PASS: Neovim save then case-only/Japanese rename, linked title, table/body and ID preserved')
        finally:
            current = source.read(note_id)
            if current and token in current.title.lower():
                source.trash(current)


if __name__ == '__main__':
    main()
