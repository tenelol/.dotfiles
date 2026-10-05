# 課題の確認・解答・承認済み提出

この手順内の `scripts/`・`references/`・`research/` は元のスキルルート基準。明示された作業ディレクトリはその指定に従う。

## Assignments

Only handle assignment submit/upload/push when the user explicitly asks for that action. A request such as "submit this", "finish this", "complete it", or "提出まで終わらせて" is explicit permission to solve, save, upload, push, and verify the matching assignment.

When that request targets a lesson/page URL and does not explicitly limit the scope, complete every entry returned in `assignments[]`, regardless of the number of entries. Process each `problemId` independently: inspect all fields and answer details, solve and upload its required artifacts, run `push` for that problem, then reopen the original URL and verify that same array entry. Never use the first entry's successful push as evidence that later entries were completed. If an entry cannot be completed, continue safely with independent entries when possible and report the exact blocked `problemId` and field.

When the user asks to finish or submit an assignment without limiting the scope, complete every applicable visible answer field, not only required fields. Treat optional, challenge, bonus, and file-upload fields in the active branch as in scope unless the user explicitly asks for required-only work, the field is impossible/unsafe to complete, or the field's instructions clearly require unavailable personal input. A field in an explicitly inactive conditional branch is intentionally blank, not skipped.

Resolve the controlling condition first, then answer only the branch selected by that result. Leave every text, radio, checkbox, and select control in the inactive branch empty; do not enter `該当なし` or compute an answer for a branch the form says does not apply. Before `push`, verify both that every active-branch field is complete and that every inactive-branch pid is blank. If the branching instruction is ambiguous, inspect the lesson materials or ask the user instead of filling both branches.

Some INIAD MOOCs forms expose select/dropdown or radio-like answers only in `currentAnswers` / `currentAnswerDetails`, while omitting those pids from `fields[]`. Treat placeholder values such as `---`, empty strings, or option-looking current answers for pids not listed in `fields[]` as in-scope visible fields when the page text shows a selector or choice in the active branch. Infer the pid from the `currentAnswers` key, solve it from the assignment instructions, submit it in the same JSON payload, and verify it after submission. Preserve empty values for pids that belong to an explicitly inactive branch.

### Evidence Before Submission

Submit only answers grounded in the specified primary materials, actual data, or a reproducible calculation from verified inputs. For each intended answer, establish the source and calculation before any server-side autosave, upload, or push. A previous AI answer or an AI-written Notebook's source label is not proof of the instructor's method or dataset provenance.

For data-backed questions, identify the correct course/class folder and file from the instructor's links, check the actual contents, and run the analysis on that file. Use file IDs or hashes when needed to distinguish duplicate names or verify a local copy. Slides establish the questions and prescribed methods; packet counts, statistical values, and other observations must come from the actual capture/data. Mathematical derivations are valid when their stated inputs and assumptions are verified against the question.

When the required file, preprocessing method, question meaning, or personal fact remains unknown, leave that problem unsent and report the exact missing evidence. Do not fill attendance, seats, measurements, experiences, or unknown values by guessing. Continue independent problems whose evidence is complete.

### Inspect Before Writing

Start from the URL router or an explicit `courseId` / `problemId`, then inspect the assignment with whatever detail command the local CLI supports:

```bash
imoocs open '<lesson-url>'
imoocs assignment show '<lesson-url>'
```

If `assignment show` is unsupported, use the `imoocs open` envelope and `imoocs assignment --help` output as the authoritative limits. Do not guess hidden field IDs or submit to a problem whose fields are unknown.

Confirm these from the JSON envelope before any write:

- The `courseId`, `lessonId`, `pageId`, and `problemId` match the user's requested target.
- Every visible `fields[].pid` is known, including optional/challenge/bonus fields when the user asked to finish or submit the whole assignment.
- Every non-system `currentAnswers` / `currentAnswerDetails` key is reviewed, even if it is absent from `fields[]`. Pay special attention to `---` placeholder values: they often represent dropdown/select fields.
- Each field type is known, such as `text`, `textarea`, `radio`, `checkbox`, or `file`.
- Existing `currentValue` or `uploadedFile` values are understood before overwriting.
- The assignment is open/submittable. Treat closed, upcoming, expired, or disabled forms as not safe to submit unless the user gives explicit instructions after being told the risk.
- Required files and in-scope optional/challenge upload files exist and have been generated from the current source, not guessed.

Read the assignment page and any linked exercise PDFs, slides, or handouts needed to understand all visible fields before deciding a field can be left blank.

For slide-backed form assignments, verify the actual question text from the slide deck or downloaded slide PDF before writing answers. If the page has an embedded Google Slides iframe, use the slide deck/material as primary question evidence. The form labels alone are not sufficient evidence for numeric/statistical answers.

For notebooks, execute all cells and generate HTML when required by the fields:

```bash
python -m nbconvert --to notebook --execute --inplace <notebook.ipynb>
python -m nbconvert --to html <notebook.ipynb>
```

### Submit or Upload

Run `imoocs assignment --help` and use the syntax it advertises. Current `imoocs` 0.1.x wrappers may require `--confirm`, in which case submit/upload only stages a local draft:

```bash
imoocs assignment submit --confirm --course-id <courseId> --problem-id <problemId> --text '<answer text>'
imoocs assignment upload --confirm --course-id <courseId> --problem-id <problemId> --file <path>
```

If the local CLI advertises the newer field-based interface, text answers are saved as JSON keyed by `pid` and files are uploaded by field `pid`. In this mode the CLI uses MOOCs' assignment autosave API directly and reports `submission.state: "auto"` when the server accepted the write. This is server-side answer storage, not final confirmation by the page's green Submit button:

```bash
printf '%s\n' '{"p1":"answer text"}' > /tmp/imoocs-answers.json
imoocs assignment submit <courseId> <problemId> --data @/tmp/imoocs-answers.json
imoocs assignment upload <courseId> <problemId> --pid ipynb <notebook.ipynb>
imoocs assignment upload <courseId> <problemId> --pid html <notebook.html>
```

Include solved dropdown/select pids discovered only from `currentAnswers` in the same JSON payload, for example `{"p5":"option text","p6":"other option"}`. If the server accepts a pid that was absent from `fields[]`, treat the returned `currentAnswers` value as the authoritative confirmation.

Parse the JSON envelope after every submit/upload. The CLI submission mode determines the result:

| Mode | Meaning |
|---|---|
| `confirm` | No server submission yet. The operation only stages a local draft, typically under `.imoocs/drafts`. |
| `auto` | The operation sends/saves answers to the MOOCs server immediately, but it may still require `push` for final confirmation. |
| unset/invalid | Treat `VALIDATION_ERROR` as no submission and run `imoocs setup` or report the required setup. |

Prefer `confirm` mode for agent-assisted work unless the user explicitly asked for immediate server submission and the local CLI clearly supports it. Never report final completion until `push` has succeeded and the reflected values can be verified.

### Push Final Confirmation

After saving all intended answers, use `push` to perform the final submit-button confirmation through the CLI:

```bash
imoocs assignment push <courseId> <problemId>
```

Parse the JSON envelope. Treat `submission.state: "push"` and `data.serverSubmitted: true` as final confirmation. On the current MOOCs frontend, the green submit button verifies `/answers` autosave and leaves `data.assignmentStatus` as `open`; this is normal and should not be treated as a failed push. If `push` returns `auth_required`, `push_failed`, `not_submittable`, or any other non-ok envelope, report that no final submit-button confirmation occurred.

### Verify After Writes

After any server submission attempt or user-confirmed push, verify the reflected MOOCs state:

```bash
imoocs assignment show '<lesson-url>'
```

Match every in-scope `assignments[]` entry by `problemId`. For each entry, check that all intended text fields, including optional/challenge fields, have `currentValue`; all dropdown/select pids discovered from `currentAnswers` / `currentAnswerDetails` have the expected data value instead of `---`; and all intended file fields have `uploadedFile.filename`. Confirm that the post-write array still contains every originally discovered `problemId`; do not verify only the first compatibility alias. For current MOOCs pages, `status: open` can remain after the green submit-button confirmation, so rely on reflected answer/file values plus that problem's successful `push` rather than requiring a submitted status. If `assignment show` is unsupported, say verification was not possible and do not claim the reflected server state was confirmed. Local file generation or confirm-mode staging alone is not submission completion.

### Submission Screenshots

After successful push and CLI readback, open the exact submitted lesson/assignment URL in an authenticated browser for read-only visual confirmation. The requested submission evidence includes this visual check; CLI submission remains the preferred write path. Do not retype answers or press Submit again to obtain a screenshot.

Inspect the actual visible answers, selected options, and uploaded filenames for each submitted problem. Capture enough screenshots to cover the submitted fields, with the assignment identity and URL visible or clearly associated with the capture. Save the genuine browser screenshots as local image files in the task's evidence directory (or the user's designated course context). Exclude unrelated personal information and credentials. A terminal image, recreated form, generated mockup, or screenshot of a local answer document is not evidence of server reflection.

In the final report, include the clickable exact MOOCs URL and embed the inspected screenshots using Markdown image syntax with absolute local paths, for example `![提出後の回答確認](/absolute/path/submission-confirmation.png)`. A screenshot displayed only in a tool result, a bare file path, or a text claim that it was checked does not satisfy screenshot delivery. Apply this to resubmissions too. When reporting through a requested notification destination, attach the actual images through its supported upload mechanism; if that mechanism is unavailable, present the images in Codex and state the delivery limitation.

If authentication, browser access, or capture fails, preserve the confirmed CLI submission result and report screenshot verification/delivery as incomplete with the exact blocker. Do not fabricate evidence or report the full submission-and-evidence workflow as complete.
