import { readFileSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

const art = readFileSync(new URL("./art/dashboard-character.txt", import.meta.url), "utf8").trimEnd().split("\n");
const logo = [
	"██████╗ ██╗",
	"██╔══██╗██║",
	"██████╔╝██║",
	"██╔═══╝ ██║",
	"██║     ██║",
	"╚═╝     ╚═╝",
];

function centerBlock(lines: string[], width: number): string[] {
	const blockWidth = Math.max(...lines.map(visibleWidth));
	const padding = " ".repeat(Math.max(0, Math.floor((width - blockWidth) / 2)));
	return lines.map((line) => truncateToWidth(padding + line, width, ""));
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		ctx.ui.setHeader((_tui, theme) => ({
			render: (width: number) => [...centerBlock(art, width), ...centerBlock(logo, width), ""]
				.map((line) => theme.fg("accent", line)),
			invalidate() {},
		}));
	});
}
