// Run: node modules/pi-coding-agent/tests/keybindings.test.mjs
import assert from "node:assert/strict";
import { join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = process.env.PI_PACKAGE_DIR || "/opt/homebrew/opt/pi-coding-agent/libexec/lib/node_modules/@earendil-works/pi-coding-agent";
const { KeybindingsManager } = await import(pathToFileURL(join(root, "dist/core/keybindings.js")));
const { CustomEditor } = await import(pathToFileURL(join(root, "dist/modes/interactive/components/custom-editor.js")));
const { InteractiveMode } = await import(pathToFileURL(join(root, "dist/modes/interactive/interactive-mode.js")));
const keybindings = KeybindingsManager.create(fileURLToPath(new URL("../files", import.meta.url)));
const ui = { requestRender() {} };
const editor = new CustomEditor(ui, { borderColor: (text) => text }, keybindings);
let aborted = 0;
let bashAborted = 0;
let exited = 0;
const mode = {
  setupKeyHandlers: InteractiveMode.prototype.setupKeyHandlers,
  handleCtrlC: InteractiveMode.prototype.handleCtrlC,
  handleCtrlD: InteractiveMode.prototype.handleCtrlD,
  restoreQueuedMessagesToEditor: InteractiveMode.prototype.restoreQueuedMessagesToEditor,
  defaultEditor: editor,
  editor,
  ui,
  isBashMode: false,
  session: { isStreaming: true, isBashRunning: false, abortBash: () => bashAborted++ },
  agent: { abort: () => aborted++ },
  settingsManager: { getDoubleEscapeAction: () => "none" },
  clearAllQueues: () => ({ steering: [], followUp: [] }),
  updatePendingMessagesDisplay() {},
  clearEditor: () => assert.fail("Ctrl+C must not clear the editor or arm double-press exit"),
  shutdown: () => exited++,
};
mode.setupKeyHandlers();

editor.setText("draft");
editor.handleInput("\x03");
editor.handleInput("\x03");
assert.equal(aborted, 2, "Ctrl+C aborts active generation even when pressed twice");
assert.equal(editor.getText(), "draft");
assert.equal(exited, 0);
editor.handleInput("\x1b");
assert.equal(aborted, 3, "Escape still aborts");

mode.session.isStreaming = false;
mode.session.isBashRunning = true;
editor.handleInput("\x03");
assert.equal(bashAborted, 1, "Ctrl+C aborts running shell commands");
mode.session.isBashRunning = false;
editor.handleInput("\x04");
assert.equal(exited, 0, "Ctrl+D preserves a nonempty editor");
editor.setText("");
editor.handleInput("\x03");
editor.handleInput("\x03");
assert.equal(exited, 0, "Repeated Ctrl+C never exits an idle session");
editor.handleInput("\x04");
assert.equal(exited, 1, "Ctrl+D exits when the editor is empty");
console.log("Pi keybindings: generation/shell abort, repeated Ctrl+C, and Ctrl+D exit passed");
