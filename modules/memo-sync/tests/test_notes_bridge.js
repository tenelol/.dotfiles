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
  const application = {
    selection: () => options.multiple ? [note, note] : [note],
    notes: {
      byId: (id) => {
        assert.equal(id, "fixture-id");
        if (options.missing) throw new Error("Can't get note (-1728)");
        return note;
      },
    },
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
  return { result: JSON.parse(context.run()), accesses, writes };
}

assert.equal(execute({ operation: "selected" }).result.note.text, "All text\n日本語");
assert.equal(execute({ operation: "read", id: "fixture-id" }).result.note.id, "fixture-id");
assert.equal(execute({ operation: "read", id: "fixture-id" }, { missing: true }).result.note, null);
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
for (const options of [{ shared: true }, { attachments: true }, { changing: true }]) {
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
console.log("Notes bridge: read, guarded write, stale read, unsupported metadata, and fidelity: 16 checks passed");
