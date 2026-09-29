import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("agent_settled", (_event, ctx) => {
    if (ctx.mode !== "tui" || process.env.HERDR_ENV === "1") return;
    process.stdout.write("\x1b]777;notify;Pi;処理が終了し、入力待ちになりました。\x07");
  });
}
