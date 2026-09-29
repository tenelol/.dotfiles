import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  if (process.env.HERDR_ENV !== "1") return;
  pi.on("ui_prompt_start", (_event, ctx) => {
    if (ctx.mode === "tui") pi.events.emit("herdr:blocked", { active: true, label: "入力待ち" });
  });
  pi.on("ui_prompt_end", (_event, ctx) => {
    if (ctx.mode === "tui") pi.events.emit("herdr:blocked", { active: false });
  });
}
