// Read-only Notes adapter. JSON on stdin; snapshots on stdout. No UI scripting.
ObjC.import("Foundation");

function snapshot(note) {
  if (note.passwordProtected()) {
    throw new Error("ロックされたメモは登録できません。");
  }
  var before = note.modificationDate().toISOString();
  var value = {
    id: note.id(),
    title: note.name(),
    html: note.body(),
    text: note.plaintext(),
    modified: before,
    attachments: note.attachments().length,
    shared: note.shared(),
  };
  if (note.modificationDate().toISOString() !== before) {
    throw new Error("読取中にメモが更新されました。もう一度実行してください。");
  }
  return value;
}

function run() {
  var data = $.NSFileHandle.fileHandleWithStandardInput.readDataToEndOfFile;
  var input = ObjC.unwrap($.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding));
  var request = JSON.parse(input);
  var notes = Application("Notes");
  try {
    if (request.operation === "selected") {
      var selection = notes.selection();
      if (selection.length !== 1) {
        throw new Error("標準メモで同期対象を1件選択してください。");
      }
      return JSON.stringify({ note: snapshot(selection[0]) });
    }
    if (request.operation === "read") {
      return JSON.stringify({ note: snapshot(notes.notes.byId(request.id)) });
    }
    throw new Error("この初期版はメモの読取だけを許可しています。");
  } catch (error) {
    if (request.operation === "read" &&
        (error.errorNumber === -1728 || /\(-1728\)/.test(String(error)))) {
      return JSON.stringify({ note: null });
    }
    return JSON.stringify({ error: String(error) });
  }
}
