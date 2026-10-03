"""Run with Neovim's python3_host_prog interpreter (pynvim is already included)."""
import logging
import os
from pathlib import Path

import pynvim

logging.getLogger("pynvim").setLevel(logging.CRITICAL)
root = Path(__file__).resolve().parents[3]
argv = ["nvim", "--embed", "--headless", "-u", "NONE", "-i", "NONE"]
nvim = pynvim.attach("child", argv=argv)
cells = {}


def settle():
    frames = []
    nvim.exec_lua("local channel = ...; vim.defer_fn(function() vim.rpcnotify(channel, 'scope-test-done') end, Snacks.config.indent.animate.duration.total + 100)", nvim.channel_id)
    while True:
        kind, name, args = nvim.next_message()
        if name == "scope-test-done":
            return frames
        if kind != "notification" or name != "redraw":
            continue
        for event, *updates in args:
            if event == "flush":
                frames.append(guides())
            for update in updates:
                if event == "grid_clear":
                    cells.clear()
                elif event == "grid_line":
                    grid, row, col, chunks, *_ = update
                    highlight = 0
                    for chunk in chunks:
                        text = chunk[0]
                        highlight = chunk[1] if len(chunk) > 1 else highlight
                        for _ in range(chunk[2] if len(chunk) > 2 else 1):
                            cells[grid, row, col] = (text, highlight)
                            col += 1


def guides():
    return sorted((row, col) for (_, row, col), (text, _) in cells.items() if text == "┃")


try:
    nvim.ui_attach(100, 28, rgb=True, ext_linegrid=True)
    if runtime := os.environ.get("NVIM_SNACKS_TEST_RUNTIME"):
        nvim.exec_lua("vim.opt.runtimepath:append(...)", runtime)
    nvim.exec_lua("""
      vim.opt.runtimepath:prepend(...)
      local paths = require('nix-managed-plugins')
      paths['snacks-nvim'] = paths['snacks-nvim'] or
        vim.fn.fnamemodify(vim.api.nvim_get_runtime_file('lua/snacks/init.lua', false)[1], ':h:h:h')
      require('plugins.indentscope')[1].config()
      assert(not Snacks.config.indent.indent.enabled)
      assert(Snacks.config.indent.scope.only_current)
      assert(not Snacks.config.indent.scope.treesitter.enabled)
      local values, done = {}, false
      Snacks.animate(0, 4, function(value, ctx)
        values[#values + 1] = value
        done = ctx.done
      end, vim.tbl_extend('keep', { int = true }, Snacks.config.indent.animate))
      assert(vim.wait(1000, function() return done end))
      assert(vim.deep_equal(values, { 1, 2, 3, 4 }), 'Indent animation pauses on repeated rows: ' .. vim.inspect(values))
      vim.o.shiftwidth = 2
      vim.o.number = false
      vim.o.relativenumber = false
    """, str(root / "modules/nvim/files"))

    cases = [
        ("astro", ["---", "interface Props {", "  title: string;", "  description: string;", "  image?: ImageMetadata;", "}", "---"], 4, [(2, 0), (3, 0), (4, 0)]),
        ("astro", ["<style>", "  ul {", "    display: flex;", "    gap: 2rem;", "  }", "</style>"], 4, [(2, 2), (3, 2)]),
        ("text", ["section", "  first", "  second", "outside"], 3, [(1, 0), (2, 0)]),
        ("text", ["root", "  outer", "    first", "    second", "  sibling", "    other", "outside"], 4, [(2, 2), (3, 2)]),
    ]
    for index, (filetype, lines, line, expected) in enumerate(cases):
        nvim.current.buffer[:] = lines
        nvim.current.buffer.options["filetype"] = filetype
        nvim.current.window.cursor = (line, 0)
        nvim.command("doautocmd CursorMoved")
        nvim.command("redraw!")
        frames = settle()
        assert guides() == expected, (filetype, "wrong active scope", guides(), expected)
        if index == 0:
            partial = [frame for frame in frames if 0 < len(frame) < len(expected)]
            assert partial and all(frame == expected[:len(frame)] for frame in partial), ("Animation must reveal from the top", frames)

    nvim.command("vsplit")
    nvim.command("doautocmd CursorMoved")
    nvim.command("redraw!")
    settle()
    assert len(guides()) == 2, ("Inactive window still shows guides", guides())
    nvim.command("close")
    nvim.current.buffer.options["filetype"] = "dashboard"
    nvim.current.buffer[:] = ["NEOVIM", "    Find File", "    Recent Files", "footer"]
    nvim.current.window.cursor = (2, 4)
    nvim.command("doautocmd CursorMoved")
    nvim.command("redraw!")
    settle()
    assert not guides(), ("Dashboard must not show indent scopes", guides())
    nvim.current.buffer.options["filetype"] = "text"
    nvim.current.buffer[:] = ["plain", "unindented", "text"]
    nvim.command("doautocmd CursorMoved")
    nvim.command("redraw!")
    settle()
    assert not guides(), ("Background guides remain", guides())
    print("Astro interfaces, CSS, parser-free scopes, and active-only UI rendering: OK")
finally:
    try:
        nvim.command("qa!")
    except EOFError:
        pass
    nvim.close()
