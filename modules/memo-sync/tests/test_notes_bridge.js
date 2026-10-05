// Run with node. The Notes application and Foundation input are synthetic.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const script = fs.readFileSync(path.join(__dirname, "../files/notes.js"), "utf8");

function execute(request, options = {}) {
  let accesses = 0;
  let dates = 0;
  let writes = 0;
  let creations = 0;
  const fixture = {
    id: "fixture-id", name: "Synthetic 日本語メモ", body: "<p>All text</p>",
    plaintext: "All text\n日本語", shared: !!options.shared, passwordProtected: false,
  };
  const note = new Proxy({}, {
    set(target, key, value) {
      if (typeof value === "function") { target[key] = value; return true; }
      assert.equal(key, "body", "Only body may be set");
      writes++;
      fixture.body = value;
      fixture.plaintext = options.badReadback ? "Truncated\n" : request.text;
      return true;
    },
  });
  for (const [key, value] of Object.entries(fixture)) {
    note[key] = (...args) => {
      assert.equal(args.length, 0);
      accesses++;
      return key === "passwordProtected" && options.locked ? true : fixture[key];
    };
  }
  note.modificationDate = () => new Date(
    "2026-10-05T00:00:0" + (options.changing && dates++ > 0 ? "1" : "0") + "Z"
  );
  note.attachments = () => options.attachments ? [{}] : [];
  function children(parent) {
    const values = [];
    return Object.assign(() => values, { push: (value) => {
      value.container = () => parent;
      values.push(value);
    }});
  }
  const account = { id: () => "account-id" };
  account.folders = children(account);
  let folderNumber = 0;
  function folder(name) {
    const id = "folder-" + folderNumber++;
    const result = { id: () => id, name: () => name, shared: () => !!options.folderShared };
    result.folders = children(result);
    result.notes = children(result);
    return result;
  }
  const root = folder("Notes");
  const trashFolder = folder("Recently Deleted");
  account.folders.push(root);
  account.folders.push(trashFolder);
  account.defaultFolder = () => root;
  note.container = () => options.trash ? trashFolder : root;
  const trash = { id: () => "trash-id", container: () => trashFolder };
  const application = {
    accounts: () => [account],
    defaultAccount: () => account,
    Folder: ({ name }) => folder(name),
    Note: ({ body }) => {
      creations++;
      fixture.id = "created-id";
      fixture.body = body;
      fixture.plaintext = options.badReadback ? "Truncated\n" : request.text;
      return note;
    },
    selection: () => options.multiple ? [note, note] : [note],
    notes: Object.assign(() => [note, trash], {
      byId: (id) => {
        assert.equal(id, "fixture-id");
        if (options.missing) throw new Error("Can't get note (-1728)");
        return note;
      },
    }),
  };
  const context = vm.createContext({
    ObjC: { import: () => {}, unwrap: (value) => value },
    $: {
      NSFileHandle: { fileHandleWithStandardInput: { readDataToEndOfFile: JSON.stringify(request) } },
      NSString: { alloc: { initWithDataEncoding: (value) => value } },
      NSUTF8StringEncoding: 4,
    },
    Application: (name) => {
      assert.equal(name, "Notes");
      return application;
    },
  });
  vm.runInContext(script, context);
  return { result: JSON.parse(context.run()), accesses, writes, creations };
}

assert.equal(execute({ operation: "selected" }).result.note.text, "All text\n日本語");
assert.equal(execute({ operation: "read", id: "fixture-id" }).result.note.id, "fixture-id");
assert.equal(execute({ operation: "read", id: "fixture-id" }, { missing: true }).result.note, null);
assert.deepEqual(execute({ operation: "list" }).result.ids, ["fixture-id"]);
assert.equal(execute({ operation: "read", id: "fixture-id" }, { trash: true }).result.note, null);
assert.ok(execute({ operation: "selected" }, { trash: true }).result.error);
assert.ok(execute({ operation: "selected" }, { locked: true }).result.error);
assert.ok(execute({ operation: "selected" }, { multiple: true }).result.error);
assert.ok(execute({ operation: "selected" }, { changing: true }).result.error);
for (const operation of ["write", "delete", "create", "replace"]) {
  const blocked = execute({ operation });
  assert.ok(blocked.result.error);
  assert.equal(blocked.accesses, 0);
}
const expected = execute({ operation: "read", id: "fixture-id" }).result.note;
const replacement = { operation: "replace", id: "fixture-id", expected,
  html: "<div>Updated 日本語</div>", text: "Updated 日本語\n" };
let result = execute(replacement);
assert.equal(result.writes, 1);
assert.equal(result.result.note.text, replacement.text);
for (const options of [{ shared: true }, { attachments: true }, { changing: true }, { trash: true }]) {
  result = execute(replacement, options);
  assert.ok(result.result.error);
  assert.equal(result.writes, 0);
}
result = execute({ ...replacement, expected: { ...expected, html: "stale" } });
assert.ok(result.result.error);
assert.equal(result.writes, 0);
result = execute(replacement, { badReadback: true });
assert.ok(result.result.error);
assert.equal(result.writes, 1);
assert.equal(result.result.note.text, "Truncated\n");
console.log("Notes bridge: listing, trash, read, guarded write, stale read, metadata, and fidelity: 20 checks passed");
assert.deepEqual(execute({ operation: "ensure_folder", folder: ["a", "b"] }).result.folder.path, ["a", "b"]);
assert.deepEqual(execute({ operation: "folders" }).result.folders.map(f => f.path), [[]]);
for (const path of [[".."], [".memo-sync"], ["a/b"], ["Notes"], ["Recently Deleted"]]) {
  assert.ok(execute({ operation: "ensure_folder", folder: path }).result.error);
}
const create = { operation: "create", folder: ["a"], folder_id: "folder-2",
  account: "account-id", html: "<div>Created</div>", text: "Created\n" };
result = execute(create);
assert.equal(result.creations, 1);
assert.deepEqual(result.result.note.folder, ["a"]);
assert.equal(result.result.note.text, "Created\n");
for (const request of [{ ...create, folder_id: "stale" }, { ...create, account: "stale" }]) {
  result = execute(request);
  assert.ok(result.result.error);
  assert.equal(result.creations, 0);
}
assert.ok(execute(create, { folderShared: true }).result.error);
assert.ok(execute(create, { badReadback: true }).result.error);
console.log("Folders bridge: nested creation, safe names, destination checks, shared refusal, and fidelity passed");
