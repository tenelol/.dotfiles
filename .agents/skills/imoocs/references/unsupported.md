# CLI未対応操作と結果報告

この手順内の `scripts/`・`references/`・`research/` は元のスキルルート基準。明示された作業ディレクトリはその指定に従う。

## Unsupported Surfaces

Some surfaces may still be unsupported by the local CLI backend. Commands for course, lesson, attendance, direct URL routing, assignment submit/upload, or assignment push may return JSON envelopes with an unsupported reason such as `unsupported_by_imoocs`.

Use those envelopes as authoritative. Do not replace them with browser inspection or Playwright unless the user explicitly authorizes that fallback.

## Final Report

Always state one of these outcomes clearly:

- `何もしていない`: no submission/stage/push was performed.
- `stage だけした`: a local assignment draft was staged, but nothing was sent to the server.
- `auto で保存した`: `submit` / `upload` immediately saved answers/files to the server because the CLI was in auto mode, but final submit-button confirmation did not happen.
- `push で確定した`: only if `imoocs assignment push <courseId> <problemId>` completed successfully with `submission.state: "push"` and `data.serverSubmitted: true`.

For assignment work, also state whether post-write `imoocs assignment show '<lesson-url>'` confirmed the required and in-scope optional/challenge `currentValue` and `uploadedFile.filename` values. If verification was not possible, say so clearly. If a finish/submit request left any applicable visible field blank, list the skipped field and reason. Treat blanks in an explicitly inactive conditional branch as expected, not skipped.

For normal slide/material work, report downloaded paths or counts and state that no assignment submission was performed. If PDFs were only read from a temporary directory, state that the temporary PDFs were deleted instead of reporting them as saved materials.

For every completed MOOCs task, include a clickable Markdown link to the exact target course, lesson, or assignment URL in the final report so the user can verify the result immediately. Prefer the URL supplied by the user; otherwise use the URL resolved by `imoocs open`.

Always treat submitted content, submission judgment, submission operation, and compliance with related rules as the user's responsibility.
