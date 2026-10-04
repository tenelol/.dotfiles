"""Run with Neovim's bundled pynvim interpreter from the repository root."""

import logging
import msgpack
from pathlib import Path
from tempfile import TemporaryDirectory

import pynvim

logging.getLogger("pynvim").setLevel(logging.CRITICAL)
root = Path(__file__).resolve().parents[3]
nvim = pynvim.attach("child", argv=["nvim", "--embed", "--headless", "-u", "NONE", "-i", "NONE"])
positions = {}
grids = {}


def window_id(value):
    return msgpack.unpackb(value.data) if isinstance(value, msgpack.ExtType) else value


def frames_for(milliseconds):
    frames = []
    nvim.exec_lua(
        "local channel, ms = ...; vim.defer_fn(function() vim.rpcnotify(channel, 'picker-test-done') end, ms)",
        nvim.channel_id,
        milliseconds,
    )
    while True:
        kind, name, args = nvim.next_message()
        if name == "picker-test-done":
            return frames
        if kind != "notification" or name != "redraw":
            continue
        for event, *updates in args:
            for update in updates:
                if event == "win_float_pos":
                    grid, win, _, _, row, col, *_ = update
                    grids[grid] = window_id(win)
                    positions[grids[grid]] = (row, col)
                elif event in ("win_hide", "win_close"):
                    win = grids.pop(update[0], None)
                    positions.pop(win, None)
                elif event == "flush":
                    frames.append(positions.copy())


try:
    nvim.ui_attach(140, 50, rgb=True, ext_linegrid=True, ext_multigrid=True)
    with TemporaryDirectory(prefix="dotfiles-picker-") as directory:
        target = Path(directory) / "animated-picker-example.txt"
        target.write_text("preview is visible\n")
        nvim.exec_lua(
            """
              local config_path, directory = ...
              vim.opt.runtimepath:prepend(config_path)
              vim.cmd('tcd ' .. vim.fn.fnameescape(directory))
              require('plugins.telescope')[1].config()
              _G.picker_test_main = vim.api.nvim_get_current_win()
            """,
            str(root / "modules/nvim/files"),
            directory,
        )
        frames_for(30)
        nvim.input("\x10")  # Ctrl-P
        frames = frames_for(30)
        assert nvim.eval("mode()") == "i", "Picker did not accept input while opening"
        nvim.input("anim")
        frames.extend(frames_for(370))
        picker = nvim.exec_lua(
            """
              local p = require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())
              assert(p)
              local windows = {}
              for _, part in ipairs({'prompt', 'results', 'preview'}) do
                if p[part .. '_win'] then windows[#windows + 1] = p[part .. '_win'] end
                local border = p[part .. '_border']
                if border and border.winid then windows[#windows + 1] = border.winid end
              end
              return { windows = windows, prompt = p.prompt_win, results = p.results_bufnr,
                       preview = p.preview_win, bufnr = p.prompt_bufnr }
            """
        )
        assert len(picker["windows"]) == 6, "Picker did not create all content and border windows"
        visible = [frame for frame in frames if picker["prompt"] in frame]
        assert len(visible) > 2, "Picker did not render opening frames"
        first, last = visible[0], visible[-1]
        movement = first[picker["prompt"]][0] - last[picker["prompt"]][0]
        assert movement > 0, ("Picker appeared at its final position before animation", first, last)
        for win in picker["windows"]:
            assert win in first and win in last, ("Picker border/content appeared late", win)
            assert first[win][0] - last[win][0] == movement, "Picker windows moved out of sync"
            assert nvim.exec_lua("return vim.wo[...].winblend", win) == 0, "Picker stayed faded"
        results = nvim.exec_lua("return vim.api.nvim_buf_get_lines(..., 0, -1, false)", picker["results"])
        assert any(target.name in line for line in results), "File names were missing after animation"
        prompt = nvim.exec_lua("return vim.api.nvim_buf_get_lines(..., 0, -1, false)", picker["bufnr"])
        assert any("anim" in line for line in prompt), "Typing during animation was lost"
        if picker["preview"]:
            preview = nvim.exec_lua("return vim.api.nvim_win_get_buf(...)", picker["preview"])
            preview_lines = nvim.exec_lua("return vim.api.nvim_buf_get_lines(..., 0, -1, false)", preview)
            assert any("preview is visible" in line for line in preview_lines), "Preview was not drawn"

        nvim.exec_lua(
            """
              require('telescope.actions').select_default:enhance({
                pre = function(bufnr)
                  local current = require('telescope.actions.state').get_current_picker(bufnr)
                  vim.g.picker_blend_at_select = vim.wo[current.prompt_win].winblend
                end,
              })
            """
        )
        nvim.input("\r")
        frames_for(35)
        nvim.input("zzz")  # Results can change while the chosen file is fading out.
        closing_frames = frames_for(65)
        assert nvim.exec_lua("return #vim.api.nvim_list_wins()") > 1, "File selection skipped closing animation"
        assert nvim.exec_lua("return vim.wo[...].winblend", picker["prompt"]) > 0, "Picker did not fade closed"
        changed_prompt = nvim.exec_lua("return vim.api.nvim_buf_get_lines(..., 0, -1, false)", picker["bufnr"])
        assert any("animzzz" in line for line in changed_prompt), "Results did not change during closing"
        closing_frames.extend(frames_for(140))
        closing_visible = [frame for frame in closing_frames if picker["prompt"] in frame]
        assert len(closing_visible) > 2, "Closing animation did not render"
        assert closing_visible[-1][picker["prompt"]][0] > closing_visible[0][picker["prompt"]][0], (
            "Picker did not slide closed",
            closing_visible,
        )
        assert nvim.exec_lua("return #vim.api.nvim_list_wins()") == 1, "Selecting a file left picker windows open"
        assert nvim.exec_lua("return vim.g.picker_blend_at_select") > 14, "Picker flashed opaque before closing"
        opened = nvim.exec_lua("return vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())")
        assert Path(opened).resolve() == target.resolve(), "Selecting a file opened the wrong buffer"
        assert nvim.eval("mode()") == "n", "Selecting a file left terminal in picker input mode"

        nvim.input("\x10")
        frames_for(30)
        nvim.input("\x03")  # Ctrl-C during opening
        frames_for(60)
        assert nvim.exec_lua("return #vim.api.nvim_list_wins()") > 1, "Early close skipped animation"
        frames_for(170)
        assert nvim.exec_lua("return #vim.api.nvim_list_wins()") == 1, "Interrupted animation left windows open"
        assert nvim.exec_lua("return vim.api.nvim_get_current_win()") == nvim.exec_lua(
            "return picker_test_main"
        )

        nvim.ui_try_resize(80, 24)
        nvim.input("\x10")
        frames_for(35)
        compact = nvim.exec_lua(
            "return require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())"
            ".prompt_win"
        )
        assert nvim.exec_lua("return vim.wo[...].winblend", compact) > 0, "Compact picker skipped fade"
        frames_for(250)
        assert nvim.exec_lua("return vim.wo[...].winblend", compact) == 0, "Compact picker stayed faded"
        nvim.input("\x10")  # Ctrl-P toggles the open picker.
        frames_for(65)
        assert nvim.exec_lua("return vim.wo[...].winblend", compact) > 0, "Ctrl-P did not start closing animation"
        frames_for(160)
        assert nvim.exec_lua("return #vim.api.nvim_list_wins()") == 1, "Compact picker leaked windows"

        nvim.ui_try_resize(140, 50)
        nvim.input("\x10")
        frames_for(35)
        nvim.ui_try_resize(120, 35)
        frames_for(270)
        resized = nvim.exec_lua(
            "return require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())"
            ".prompt_win"
        )
        assert nvim.exec_lua("return vim.api.nvim_win_is_valid(...)", resized), "Resize closed the picker"
        assert nvim.exec_lua("return vim.wo[...].winblend", resized) == 0, "Resize left the picker faded"
        nvim.input("\x1b")  # Leave insert mode as Telescope normally does.
        frames_for(20)
        assert nvim.eval("mode()") == "n", "Esc did not enter picker normal mode"
        nvim.input("\x1b")
        frames_for(35)
        assert nvim.exec_lua("return #vim.api.nvim_list_wins()") > 1, "Esc skipped closing animation"
        nvim.ui_try_resize(105, 31)
        frames_for(190)
        assert nvim.exec_lua("return #vim.api.nvim_list_wins()") == 1, "Resized picker leaked windows"

        nvim.input("\x10")
        frames_for(220)
        nvim.input("\x1b")
        frames_for(20)
        assert nvim.eval("mode()") == "n", "Picker did not enter normal mode"
        nvim.input("\x10")
        frames_for(220)
        assert nvim.exec_lua("return #vim.api.nvim_list_wins()") == 1, "Ctrl-P did not close in picker normal mode"

        nvim.input("\x10")
        frames_for(220)
        nvim.input("\x1b")
        frames_for(20)
        assert nvim.eval("mode()") == "n", "Picker did not enter normal mode before Ctrl-C"
        nvim.input("\x03")
        frames_for(220)
        assert nvim.exec_lua("return #vim.api.nvim_list_wins()") == 1, "Ctrl-C did not close in picker normal mode"
        print("Ctrl-P open/close, Esc, input, file selection, compact layout, and resize: OK")
finally:
    try:
        nvim.command("qa!")
    except EOFError:
        pass
    nvim.close()
