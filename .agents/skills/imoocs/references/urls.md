# MOOCs URLの解析と参照

この手順内の `scripts/`・`references/`・`research/` は元のスキルルート基準。明示された作業ディレクトリはその指定に従う。

## URLs

```bash
imoocs open 'https://moocs.iniad.org/...'
```

Parse the JSON envelope. If `ok` is false, report the unsupported operation and use the envelope's `data.next` hints where relevant. Do not parse the URL by hand. For a resolved page, use `data.links` for ordinary anchors and `data.materialLinks` for discovered Google Slides / Drive materials instead of scraping the page separately.

For lesson URLs, inspect the resolved `courseId`, `lessonId`, `pageId`, `assignmentCount`, every `assignments[].problemId`, and every `assignments[].fields[]` when the CLI returns them. Do not assume that one lesson page contains one assignment or stop after `data.problem`; the array is authoritative and may contain any number of entries. If `imoocs open` returns `auth_required`, run `imoocs auth login --keychain` in Codex desktop sessions, then retry only if Keychain auth succeeds. If Keychain auth fails or blocks, stop and report the Keychain blocker; do not fall back to GUI/TTY/browser unless the user explicitly authorizes that fallback in the current turn. If the expected assignment is not present and the local CLI supports assignment listing/detail commands, use the same course's assignment list and then show the matching assignment:

```bash
imoocs assignment list <courseId> --status pending
imoocs assignment show <courseId> <problemId>
imoocs assignment show '<lesson-url>'
```

Do not submit a different pending assignment just because it appears in the list. The assignment must match the user's requested lesson/page/problem. If `list` or `show` returns an unsupported envelope, treat that as authoritative and do not replace it with browser parsing unless the user authorizes a fallback.
