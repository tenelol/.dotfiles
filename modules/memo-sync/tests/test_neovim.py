"""Exercise real Neovim saves against the CLI's fixture workspace."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[1]


class NeovimTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('nvim'), 'Neovim is required')
    def test_save_status_readonly_and_unsaved_edit_protection(self):
        with tempfile.TemporaryDirectory(prefix='memo-nvim-') as temporary:
            root=Path(temporary)/'memo';fixtures=Path(temporary)/'fixtures';fixtures.mkdir()
            for note_id, title, shared in [('plain','Plain',False),('shared','Shared',True)]:
                note=dict(id=note_id,title=title,html=f'<div>{title}</div><div>BODY</div>',
                          text=title+'\nBODY\n',modified='initial',attachments=0,shared=shared,
                          folder_id='fixture-root',account='fixture-account')
                (fixtures/(hashlib.sha256(note_id.encode()).hexdigest()+'.json')).write_text(json.dumps(note))
            command=[sys.executable,str(MODULE/'files/memo_sync.py'),'--root',str(root),'--fixture-dir',str(fixtures)]
            subprocess.run(command+['import-all'],check=True,capture_output=True)
            subprocess.run(command+['status','--json'],check=True,capture_output=True)
            plain=root/'Plain.md';inode=plain.stat().st_ino
            setup='dofile('+json.dumps(str(MODULE/'files/neovim.lua'))+').setup('+json.dumps(str(root))+')'
            saved=subprocess.run(['nvim','--headless','-u','NONE',str(plain),'+lua '+setup,
                                  '+lua vim.api.nvim_buf_set_lines(0,0,-1,false,{"Plain","BODY"})',
                                  '+write','+qa'],capture_output=True,text=True,timeout=15)
            self.assertEqual(saved.returncode,0,saved.stderr)
            self.assertEqual(plain.stat().st_ino,inode,'A regular Neovim save changed the tracked file identity')
            result=subprocess.run(['nvim','--headless','-u','NONE','-l',str(MODULE/'tests/neovim.lua'),
                                   str(root),str(MODULE/'files/neovim.lua'),sys.executable,
                                   str(MODULE/'files/memo_sync.py'),str(fixtures)],capture_output=True,text=True,timeout=15)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
