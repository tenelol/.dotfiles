import { ToolExecutionComponent, type ExtensionAPI, type Theme } from "@earendil-works/pi-coding-agent";
import { stripTerminalSequences, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

export function shellCard(rows: string[], width: number, theme: Theme): string[] {
  const cardWidth = width >= 80 ? Math.min(88, Math.floor(width * 0.7)) : width;
  const inner = Math.max(1, cardWidth - 3);
  const content = rows.filter(row => stripTerminalSequences(row).trim());
  const hidden = Math.max(0, content.length - 4);
  const preview = hidden ? [...content.slice(0, 2), theme.fg("muted", `… ${hidden} lines hidden`), ...content.slice(-2)] : content;
  const indent = " ".repeat(Math.max(0, width - cardWidth));
  const rail = theme.fg("borderMuted", "│ ");
  return ["", ...preview.map(row => indent + rail + truncateToWidth(row, inner, "…")),
    indent + rail + theme.fg("dim", truncateToWidth("Ctrl+o / click · expand", inner, "…"))];
}

export default function (pi: ExtensionAPI) {
  const proto = ToolExecutionComponent.prototype;
  let restore: (() => void) | undefined;
  pi.on("session_start", (_event, ctx) => {
    if (!ctx.hasUI || ctx.mode !== "tui") return;
    restore?.();
    const originalRender = proto.render;
    const originalMouse = proto.handleMouse;
    // ponytail: Pi 0.85.1 shell fields are private; use native rendering if their shape changes.
    const compact = (tool: any) =>
      ["bash", "powershell"].includes(tool.toolName) && typeof tool.expanded === "boolean" &&
      !tool.expanded && !tool.result?.isError && !tool.hideComponent &&
      !tool.result?.content?.some((block: any) => block.type === "image");
    const render: typeof proto.render = function (width) {
      const tool = this as any;
      if (["bash", "powershell"].includes(tool.toolName) && tool.result?.isError && tool.expanded === false) {
        this.setExpanded(true); // Errors remain fully visible, never a clipped preview.
      }
      if (width < 12 || !compact(this)) return originalRender.call(this, width);
      const cardWidth = width >= 80 ? Math.min(88, Math.floor(width * 0.7)) : width;
      const rows = originalRender.call(this, Math.max(1, cardWidth - 3));
      // Unknown terminal graphics must keep their native geometry.
      if (rows.some(row => /\x1b[_P]/.test(row))) return originalRender.call(this, width);
      const lines = shellCard(rows, width, ctx.ui.theme);
      return lines.every(line => visibleWidth(line) <= width) ? lines : originalRender.call(this, width);
    };
    const mouse: typeof proto.handleMouse = function (event) {
      if (compact(this) && event.type === "click" && event.button === "left") {
        this.setExpanded(true);
        (this as any).ui?.requestRender();
        return { handled: true };
      }
      return originalMouse.call(this, event);
    };
    proto.render = render;
    proto.handleMouse = mouse;
    restore = () => {
      if (proto.render === render) proto.render = originalRender;
      if (proto.handleMouse === mouse) proto.handleMouse = originalMouse;
    };
  });
  pi.on("session_shutdown", () => { restore?.(); restore = undefined; });
}
