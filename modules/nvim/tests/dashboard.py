"""Run with Neovim's bundled pynvim interpreter from the repository root."""

import logging
from pathlib import Path

import pynvim

logging.getLogger("pynvim").setLevel(logging.CRITICAL)
root = Path(__file__).resolve().parents[3]


def settle(nvim, milliseconds):
    nvim.exec_lua(
        "local channel, ms = ...; vim.defer_fn(function() vim.rpcnotify(channel, 'dashboard-test-done') end, ms)",
        nvim.channel_id,
        milliseconds,
    )
    while True:
        _, name, _ = nvim.next_message()
        if name == "dashboard-test-done":
            return


def view(nvim):
    return nvim.exec_lua(
        """
          local info = vim.fn.getwininfo(_G.dashboard_test_win)[1]
          return { info.topline, info.botline, vim.api.nvim_win_get_cursor(_G.dashboard_test_win)[1] }
        """
    )


def check(rows):
    nvim = pynvim.attach("child", argv=["nvim", "--embed", "--headless", "-u", "NONE", "-i", "NONE"])
    try:
        nvim.ui_attach(160, rows, rgb=True, ext_linegrid=True)
        nvim.exec_lua(
            """
              vim.opt.runtimepath:prepend(...)
              require("core.options")
              local edgy = require("plugins.edgy")[1]
              edgy.init()
              edgy.config()
              require("plugins.dashboard")[1].config()
              require("plugins.toggleterm")[1].config()
              require("dashboard"):instance()
              _G.dashboard_test_win = vim.api.nvim_get_current_win()
            """,
            str(root / "modules/nvim/files"),
        )
        settle(nvim, 100)
        top, _, menu = view(nvim)

        nvim.exec_lua("_G.dashboard_test_term = require('core.terminal').toggle(0)")
        settle(nvim, 600)
        assert nvim.eval("&buftype") == "terminal", "Terminal did not take focus"
        current, visible, _ = view(nvim)
        assert current == top, f"{rows} rows: opening the terminal scrolled the dashboard: {top} -> {current}"

        nvim.command("wincmd k")
        settle(nvim, 100)
        current, bottom, cursor = view(nvim)
        assert cursor == menu, f"{rows} rows: focusing the dashboard moved its cursor: {menu} -> {cursor}"
        if menu <= visible:
            # The selected entry is still visible above the terminal, so nothing should move.
            assert current == top, f"{rows} rows: focusing the dashboard scrolled it: {top} -> {current}"
        else:
            assert current <= cursor <= bottom, "Focused dashboard hid its cursor"

        nvim.command("wincmd j")
        settle(nvim, 100)
        assert view(nvim)[0] == top, f"{rows} rows: dashboard stayed scrolled after leaving it: {view(nvim)}"

        nvim.exec_lua("require('core.terminal').close(_G.dashboard_test_term)")
        settle(nvim, 600)
        assert nvim.eval("&filetype") == "dashboard", "Closing the terminal did not return to the dashboard"
        assert view(nvim)[0] == top, f"{rows} rows: closing the terminal left the dashboard scrolled: {view(nvim)}"
    finally:
        try:
            nvim.command("qa!")
        except EOFError:
            pass
        nvim.close()


# 50 rows keeps the menu above the terminal; 38 rows hides it behind the terminal.
for rows in (50, 38):
    check(rows)
print("Dashboard keeps its position around the bottom terminal: OK")
