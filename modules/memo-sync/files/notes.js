// Notes adapter. JSON on stdin; snapshots on stdout. No UI scripting.
ObjC.import("Foundation");

function inTrash(note) {
  var folder = note.container().name();
  return folder === "Recently Deleted" || folder === "最近削除した項目";
}

function tableOnly(note, count) {
  return Number.isInteger(count) && count > 0 && note.attachments === count &&
    (note.html.match(/<table(?:\s|>)/gi) || []).length === count &&
    !/<(?:img|audio|video|iframe)\b/i.test(note.html);
}

function folderInfo(folder) {
  var app = Application("Notes");
  var accountIds = app.accounts.id();
  var id = folder.id();
  var parts = [];
  while (true) {
    var name = folder.name().normalize("NFC");
    if (name === "Recently Deleted" || name === "最近削除した項目") {
      throw new Error("削除済みフォルダは同期できません。");
    }
    parts.unshift(name);
    var parent = folder.container();
    var parentId = parent.id();
    if (accountIds.indexOf(parentId) !== -1) {
      var account = app.accounts.byId(parentId);
      if (id === account.defaultFolder().id()) parts = [];
      return { id: id, path: parts, account: account.id(),
        default_account: account.id() === app.defaultAccount().id() };
    }
    folder = parent;
    if (parts.length > 32) throw new Error("フォルダ階層が深すぎます。");
  }
}

function ensureFolder(app, parts) {
  if (!Array.isArray(parts) || parts.length > 32 || parts.some(function(part) {
    return typeof part !== "string" || !part || part[0] === "." ||
      part === "_accounts" || /[\/\\\x00-\x1f]/.test(part) ||
      part === "Recently Deleted" || part === "最近削除した項目";
  })) throw new Error("フォルダ名が不正です。");
  parts = parts.map(function(part) { return part.normalize("NFC"); });
  var account = app.defaultAccount();
  if (parts.length === 0) return account.defaultFolder();
  if (parts[0] === account.defaultFolder().name()) {
    throw new Error("既定フォルダはmemo直下に対応しています。");
  }
  var parent = account;
  parts.forEach(function(name) {
    var matches = parent.folders().filter(function(folder) {
      return folder.name().normalize("NFC") === name && folder.container().id() === parent.id();
    });
    if (matches.length > 1) throw new Error("同名フォルダを一意に選べません。");
    var folder = matches[0];
    if (!folder) {
      folder = app.Folder({ name: name });
      parent.folders.push(folder);
    }
    if (folder.shared()) throw new Error("共有フォルダへの作成は停止しました。");
    parent = folder;
  });
  return parent;
}

function snapshot(note, locations) {
  if (inTrash(note)) {
    var missing = new Error("削除済みのメモは同期できません。");
    missing.errorNumber = -1728;
    throw missing;
  }
  if (note.passwordProtected()) {
    throw new Error("ロックされたメモは登録できません。");
  }
  var before = note.modificationDate().toISOString();
  var properties = note.properties();
  var container = properties.container;
  var folderId = container.id();
  var folder = locations && locations[folderId];
  // Read-only polling reuses one folder inventory per scan. Writes always use fresh metadata.
  if (!folder || folder.id !== folderId) folder = folderInfo(container);
  var value = {
    id: properties.id,
    title: properties.name,
    html: properties.body,
    text: properties.plaintext,
    modified: before,
    attachments: note.attachments().length,
    shared: properties.shared,
  };
  value.folder_id = folder.id;
  value.folder = folder.path;
  value.account = folder.account;
  value.default_account = folder.default_account;
  if (properties.passwordProtected || properties.modificationDate.toISOString() !== before ||
      note.modificationDate().toISOString() !== before) {
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
    if (request.operation === "ui_state") {
      ObjC.import("AppKit");
      var selection = notes.selection();
      var target = notes.notes.byId(request.id);
      return JSON.stringify({ ui: {
        selected: selection.length === 1 ? selection[0].id() : null,
        foreground: ObjC.unwrap($.NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier),
        attachments: target.attachments().map(function(a) {
          return { id: a.id(), cid: a.contentIdentifier(), name: a.name() };
        })
      } });
    }
    if (request.operation === "selected") {
      var selection = notes.selection();
      if (selection.length !== 1) {
        throw new Error("標準メモで同期対象を1件選択してください。");
      }
      return JSON.stringify({ note: snapshot(selection[0]) });
    }
    if (request.operation === "read") {
      var target = notes.notes.byId(request.id);
      return JSON.stringify({ note: snapshot(target, request.locations) });
    }
    if (request.operation === "list") {
      // Notes' all-notes collection includes trash. The scripting dictionary has no trash flag.
      var active = notes.notes().filter(function(note) {
        return !inTrash(note);
      });
      return JSON.stringify({ ids: active.map(function(note) { return note.id(); }) });
    }
    if (request.operation === "index") {
      var ids = notes.notes.id();
      var dates = notes.notes.modificationDate();
      if (ids.length !== dates.length || JSON.stringify(ids) !== JSON.stringify(notes.notes.id())) {
        throw new Error("一覧取得中にメモが変化しました。");
      }
      var trash = {};
      notes.folders.whose({ _or: [{ name: "Recently Deleted" }, { name: "最近削除した項目" }] })().forEach(function(folder) {
        if (!folder.exists()) return;
        if (folder.name() === "Recently Deleted" || folder.name() === "最近削除した項目") {
          folder.notes.id().forEach(function(id) { trash[id] = true; });
        }
      });
      var index = {};
      ids.forEach(function(id, i) { if (!trash[id]) index[id] = dates[i].toISOString(); });
      return JSON.stringify({ index: index });
    }
    if (request.operation === "folders") {
      var folders = [];
      var noteLocations = {};
      var account = notes.defaultAccount();
      var accountId = account.id();
      var defaultFolderId = account.defaultFolder().id();
      function walk(parent, depth, parentPath) {
        if (depth > 32) throw new Error("フォルダ階層が深すぎます。");
        var parentId = parent.id();
        parent.folders().forEach(function(folder) {
          if (!folder.exists()) return;
          var name = folder.name().normalize("NFC");
          if (folder.container().id() !== parentId ||
              name === "Recently Deleted" || name === "最近削除した項目") return;
          var id = folder.id();
          var path = parentPath.concat([name]);
          folders.push({ id: id, path: id === defaultFolderId ? [] : path,
            account: accountId, default_account: true });
          folder.notes.id().forEach(function(noteId) { noteLocations[noteId] = id; });
          walk(folder, depth + 1, path);
        });
      }
      walk(account, 0, []);
      return JSON.stringify({ folders: folders, note_locations: noteLocations });
    }
    if (request.operation === "ensure_folder") {
      return JSON.stringify({ folder: folderInfo(ensureFolder(notes, request.folder)) });
    }
    if (request.operation === "delete_folder") {
      var expected = request.expected;
      if (!expected || !expected.default_account || !Array.isArray(expected.path) || !expected.path.length) {
        throw new Error("既定フォルダは削除できません。");
      }
      var folder = notes.folders.byId(expected.id);
      if (JSON.stringify(folderInfo(folder)) !== JSON.stringify(expected) || folder.shared() ||
          folder.notes().some(function(n) { return n.exists() && !inTrash(n); }) ||
          folder.folders().some(function(f) { return f.exists(); })) {
        throw new Error("フォルダが変更されたか、メモ・子フォルダが残っています。");
      }
      notes.delete(folder);
      return JSON.stringify({ deleted: true });
    }
    if (request.operation === "create") {
      if (typeof request.html !== "string" || typeof request.text !== "string" || !request.text.trim()) {
        throw new Error("空または不正な本文は作成できません。");
      }
      if (notes.defaultAccount().id() !== request.account) {
        throw new Error("作成先アカウントが変わったため停止しました。");
      }
      var destination = notes.folders.byId(request.folder_id);
      var info = folderInfo(destination);
      if (info.id !== request.folder_id || info.account !== request.account ||
          JSON.stringify(info.path) !== JSON.stringify(request.folder) || destination.shared()) {
        throw new Error("作成先フォルダが変わったため停止しました。");
      }
      var created = notes.Note({ body: request.html });
      destination.notes.push(created);
      var result = snapshot(created);
      if (request.tables_after ? !tableOnly(result, request.tables_after) :
          request.content_key ? result.text.replace(/\s+/g, "") !== request.content_key :
          result.text.replace(/\r\n?/g, "\n") !== request.text) {
        return JSON.stringify({ error: "作成した本文が一致しません。再作成せず確認してください。", note: result });
      }
      return JSON.stringify({ note: result });
    }
    if (request.operation === "replace") {
      if (typeof request.id !== "string" || !request.expected ||
          request.expected.id !== request.id || typeof request.html !== "string" ||
          typeof request.text !== "string" || !request.text.trim()) {
        throw new Error("書込要求が不正です。");
      }
      var note = notes.notes.byId(request.id);
      var current = snapshot(note);
      if (current.shared || (current.attachments !== 0 && !tableOnly(current, request.tables_before)) ||
          JSON.stringify(current) !== JSON.stringify(request.expected)) {
        throw new Error("書込直前にメモが更新されたか、添付・共有を含んでいます。");
      }
      note.body = request.html;
      var updated = snapshot(note);
      if (request.tables_after ? !tableOnly(updated, request.tables_after) :
          request.content_key ? updated.text.replace(/\s+/g, "") !== request.content_key :
          updated.text.replace(/\r\n?/g, "\n") !== request.text) {
        return JSON.stringify({ error: "書き戻した本文が一致しません。同期を停止してください。", note: updated });
      }
      return JSON.stringify({ note: updated });
    }
    if (request.operation === "move_note") {
      if (!request.expected || request.expected.id !== request.id || !request.destination) {
        throw new Error("移動要求が不正です。");
      }
      var target = notes.notes.byId(request.id);
      var current = snapshot(target);
      var destination = notes.folders.byId(request.destination.id);
      if (current.shared || target.container().shared() || !current.default_account || destination.shared() ||
          current.account !== request.destination.account ||
          JSON.stringify(current) !== JSON.stringify(request.expected) ||
          JSON.stringify(folderInfo(destination)) !== JSON.stringify(request.destination)) {
        throw new Error("移動前にメモ・移動先が変わったか、共有・別アカウントです。");
      }
      if (current.folder_id !== request.destination.id) notes.move(target, { to: destination });
      var moved = snapshot(notes.notes.byId(request.id));
      if (moved.folder_id !== request.destination.id || moved.html !== current.html ||
          moved.text !== current.text || moved.attachments !== current.attachments) {
        throw new Error("移動後の本文・添付・移動先が一致しません。");
      }
      return JSON.stringify({ note: moved });
    }
    if (request.operation === "trash") {
      if (typeof request.id !== "string" || !request.expected || request.expected.id !== request.id) {
        throw new Error("削除要求が不正です。");
      }
      var target = notes.notes.byId(request.id);
      var current = snapshot(target);
      if (current.shared || !notes.accounts.byId(current.account).upgraded() ||
          JSON.stringify(current) !== JSON.stringify(request.expected)) {
        throw new Error("削除直前に変更されたか、最近削除への移動に対応しないメモです。");
      }
      notes.delete(target);
      if (!inTrash(target)) throw new Error("最近削除への移動を確認できません。");
      return JSON.stringify({ deleted: true });
    }
    throw new Error("未対応の操作です。");
  } catch (error) {
    if ((request.operation === "read" || request.operation === "trash") &&
        (error.errorNumber === -1728 || /\(-1728\)/.test(String(error)))) {
      return JSON.stringify(request.operation === "trash" ? { deleted: true } : { note: null });
    }
    return JSON.stringify({ error: String(error) });
  }
}
