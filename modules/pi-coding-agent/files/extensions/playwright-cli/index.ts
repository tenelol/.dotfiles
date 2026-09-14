import { createHash } from "node:crypto";
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { Type } from "typebox";
import { truncateTail, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

const cli = fileURLToPath(new URL("./node_modules/@playwright/cli/playwright-cli.js", import.meta.url));

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "playwright_cli",
    label: "Playwright CLI",
    description: "Control a browser using the official Playwright CLI. command examples: open, goto, snapshot, click, fill, screenshot, run-code, close, --help. Pass arguments as separate strings, not a shell command. Browser state persists across calls in this Pi session; calls for one browser must be sequential. Read snapshot/screenshot files with read. Use open --headed to show the browser. Run close when finished. Never submit forms, upload private data, or perform consequential actions without user authorization. Session selection and JSON output are managed by this tool; close-all/kill-all are disabled.",
    parameters: Type.Object({
      command: Type.String({ pattern: "^(?:[a-z][a-z0-9-]*|--help|--version)$" }),
      args: Type.Optional(Type.Array(Type.String({ maxLength: 32768 }), { maxItems: 64 })),
      timeout: Type.Optional(Type.Integer({ minimum: 1, maximum: 300, description: "Timeout in seconds, default 60" })),
    }),
    async execute(_id, { command, args = [], timeout = 60 }, signal, _update, ctx) {
      if (["close-all", "kill-all"].includes(command)) throw new Error("Use close to stop only this session's browser.");
      if (args.some(arg => /\x00/.test(arg) || /^(?:-s(?:=|$)|--(?:session|json|raw)(?:=|$))/.test(arg))) {
        throw new Error("NUL bytes and session/output-format overrides are not supported.");
      }
      const session = "pi-" + createHash("sha256").update(ctx.sessionManager.getSessionId()).digest("hex").slice(0, 20);
      const result = await pi.exec(process.execPath, [cli, `-s=${session}`, command, ...args, "--json"], {
        cwd: ctx.cwd, signal, timeout: timeout * 1000,
      });
      const output = [result.stdout, result.stderr].filter(Boolean).join("\n") || "(no output)";
      let cliError = false;
      try { cliError = JSON.parse(result.stdout).isError === true; } catch { /* Help/version are plain text. */ }
      const preview = truncateTail(output, { maxLines: 200, maxBytes: 20000 });
      let outputPath: string | undefined;
      if (preview.truncated) {
        outputPath = join(await mkdtemp(join(tmpdir(), "pi-playwright-")), "output.txt");
        await writeFile(outputPath, output, { mode: 0o600 });
      }
      return {
        content: [{ type: "text", text: `Browser session: ${session}\n${preview.content}${outputPath ? `\nFull output: ${outputPath}` : ""}${result.killed ? "\nCommand was aborted or timed out; browser state may have changed." : ""}` }],
        isError: result.code !== 0 || result.killed || cliError,
        details: { session, exitCode: result.code, killed: result.killed, outputPath },
      };
    },
  });
}
