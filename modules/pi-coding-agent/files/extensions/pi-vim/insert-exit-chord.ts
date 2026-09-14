/** Buffer a typed k briefly; kj becomes Escape. Never interpret bracketed paste. */
export class InsertExitChord {
  private timer: ReturnType<typeof setTimeout> | undefined;
  private pasting = false;

  constructor(
    private readonly emit: (data: string) => void,
    private readonly enabled: () => boolean,
    private readonly timeoutMs = 200,
  ) {}

  handle(data: string): void {
    if (this.timer !== undefined) {
      clearTimeout(this.timer);
      this.timer = undefined;
      if (this.enabled() && !this.pasting && data === "j") {
        this.emit("\x1b");
        return;
      }
      this.emit("k");
    }

    const wasPasting = this.pasting;
    for (const marker of data.matchAll(/\x1b\[(200|201)~/g)) {
      this.pasting = marker[1] === "200";
    }
    if (this.enabled() && !wasPasting && !this.pasting && data === "k") {
      this.timer = setTimeout(() => {
        this.timer = undefined;
        this.emit("k");
      }, this.timeoutMs);
      return;
    }
    this.emit(data);
  }
}
