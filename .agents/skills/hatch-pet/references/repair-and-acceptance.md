# 既存petの修復と受け入れ条件

この手順内の `scripts/`・`references/`・`research/` は元のスキルルート基準。明示された作業ディレクトリはその指定に従う。

## Repair Workflow

If frame inspection or final visual QA fails, read `qa/review.json`, regenerate the smallest failing row, copy the replacement row into the same decoded output path, and keep that job marked complete with the new `source_path` and `completed_at`. Repair the failed row, not the whole sheet.

## Rules

- Keep `$imagegen` as the primary generation layer.
- For brand/product/company/prospect requests without a concrete avatar description or reference image, run brand discovery before base generation and pass only the compact brief into the run.
- Use `$imagegen` as the only visual generation layer. Do not invoke image APIs, image CLIs, local raster generators, or one-off generation scripts from this skill.
- Keep reference images attached/visible for `$imagegen` whenever the chosen path supports references.
- Attach the row's `references/layout-guides/<state>.png` image to every row-strip job as a layout-only guide, and do not accept outputs that copy guide pixels.
- Use lightweight visual workers for base generation, row-strip visual generation, and final contact-sheet QA by default; the parent owns manifest updates, deterministic image scripts, packaging, and cleanup.
- Generate every normal visual job with `$imagegen`: base plus all row strips that are not explicitly approved `running-left` mirror derivations.
- Treat only the base job as eligible for prompt-only generation; every row job must attach its listed grounding images.
- Generate `running-right` before deciding whether `running-left` can be mirrored.
- When `running-left` is mirrored, preserve frame order and timing semantics; derive it through the deterministic script instead of mirroring an entire strip wholesale.
- Do not derive or reuse `waiting`, `running`, `failed`, `review`, `jumping`, or `waving` from another state; each has distinct app semantics and must be generated as its own row.
- Generate look row 9 directly from the approved cardinal strip, then generate row 10 only after row 9 clears deterministic registration and post-registration edge QA and has no semantic or continuity hard failure. Reviewed warnings do not block row 10. Both rows attach the cardinal strip, and row 10 must also attach completed row 9.
- Final look rows must each originate from one coherent 8-frame row generation. Individually generated repair cells may never be copied into the final atlas.
- If one look direction fails, strengthen the containing row's direction instructions and resynthesize the complete row. Do not patch the final cell directly, even when deterministic assembly supports individual-cell input.
- Deterministically register each coherent look row, then run final-cell edge diagnostics and explicit labeled semantics immediately after generation, before expensive final atlas assembly. Run blind horizontal-and-vertical axis QA as soon as both coherent rows exist.
- Never substitute locally drawn, tiled, transformed, or code-generated row strips for missing `$imagegen` outputs.
- Only mark a visual job complete after its selected output has been copied into the decoded output path.
- Never mark a failed coherent row, diagnostic iteration, or one-off repair cell as packaging eligible.
- Do not rely on generated images for exact atlas geometry; use this skill's deterministic image scripts.
- Use the chroma key stored in `pet_request.json`; do not force a fixed green screen.
- Keep the pet's silhouette, face, materials, palette, style, and props consistent across all rows.
- Treat visual identity or style drift as a blocker even when deterministic validation has no errors.
- Treat a contact sheet that shows cropped references, repeated tiles, white cell backgrounds, or non-sprite fragments as failed.
- Treat preview GIFs that show extraction-induced size popping, reversed directional timing, wrong facing direction, or inert idle loops as failed.
- Apply the Direction Acceptance Policy to look cells. Cardinals are hard gates. Intermediate blind uncertainty is a warning unless labeled normal-size review confirms a wrong quadrant, missing axis, or loop reversal.
- Treat a missing explicit per-direction semantic gaze review as failed even when the focused QA sheet and continuity JSON exist.
- Treat missing `qa/direction-semantics.json` as failed. The file must include every expected direction with `verdict`, `expected`, `observed`, and `reason` fields. Packaging requires no `fail` verdicts; reviewed `warning` verdicts are allowed.
- In independent blind-review mode, treat missing or failed `qa/direction-blind-validation.json` as failed. Three isolated reviewers see only the randomized A/B sheet. In local mode, use the labeled semantic and motion review described in [look directions](look-directions.md), record the lack of independent review, and do not fabricate a blind-validation file. Cardinals still require clear confirmation.
- Never use the same worker for blind A/B classification after it has seen the labeled direction sheet or direction prompts. Label-conditioned classification is not independent evidence.
- If independent review is required, use an independent final QA worker or explicit user inspection for repaired directions. Otherwise the parent may perform the local QA procedure and must record that review was not independent.
- After an independent blind or final QA fail, the parent may override only a minor issue under Blind Review Severity Resolution. Record the evidence in `qa/blind-review-resolution.json`; never override a major failure.
- For humanoid cardinal verdicts, record concrete screen-coordinate landmark evidence in `qa/direction-semantics.json`. Intermediate verdicts may use holistic head, face, posture, and ordered-loop evidence; exact pupil or nose placement is advisory rather than mandatory.
- Treat look rows that rotate, skew, or tilt the whole sprite to fake gaze as failed unless the pet is literally a rotating object and the look mechanics decision explicitly justifies whole-object rotation.
- Treat pupil-only motion or underused natural mechanics as a warning unless it visibly breaks identity, direction meaning, or loop cohesion.
- Treat adjacent continuity metrics as review evidence. Fail only when visual QA confirms a conspicuous snap, pop, registration jump, identity change, broken silhouette, or semantic discontinuity.
- Treat forbidden detached effects, shadows, glows, smears, dust, landing marks, wave marks, speed lines, or motion trails as failed rows. Chroma-key-adjacent generation artifacts are handled only by the single deterministic despill pass and never trigger image retries after that pass reports success.
- Treat `qa/review.json` errors as blockers. Warnings require visual review.

## Acceptance Criteria

- Final atlas is PNG or WebP, exactly `1536x2288`, and based on `192x208` cells. The `1536x1872` standard atlas is intermediate-only.
- `pet.json` contains `spriteVersionNumber: 2`, the extended despill report has `ok: true`, and the packaged spritesheet passes `validate_atlas.py --require-v2` with the run's chroma key. These deterministic results close chroma QA; no separate visual chroma-fringe gate or image retry is allowed.
- Used cells are non-empty and unused cells are fully transparent.
- Atlas follows the row/frame counts in `references/animation-rows.md`.
- The four-cardinal strip has been deterministically extracted, its clipping report passes, and all four anchors are semantically approved before look-row generation.
- Both coherent look rows use `decoded/look-anchors-approved.png` as the direction basis, interpolate all intermediate directions as even 22.5-degree steps, and preserve the fixed clockwise order.
- Deterministic pose-group registration, post-registration final-cell edge diagnostics, and labeled per-direction semantic QA pass immediately on each coherent source row before final atlas assembly; blind horizontal-and-vertical axis QA runs after both rows exist.
- Contact sheet and per-row motion previews have been produced and inspected. Record whether inspection was local, by a worker, or by the user.
- A focused neutral-plus-16-directions QA sheet has been produced and inspected before packaging.
- If independent blind QA is performed, its randomized pair sheet, three isolated classifications and combined validation pass, or any allowed minor resolution is documented. Local QA does not produce an independent consensus; it must instead satisfy the same labeled direction and motion criteria and report `independent_review: false`. An explicitly required independent review cannot be waived by local QA.
- Every expected direction has an explicit `pass`, `warning`, or `fail` semantic verdict with horizontal and vertical axis evidence where applicable; no wrong cardinal, labeled wrong-quadrant pose, or visible reversal remains.
- `qa/direction-semantics.json` records evidence and verdicts for all 16 directions, including the actual reviewer and notes for accepted warnings. Do not describe local inspection as independent.
- `qa/look-continuity.json` has been reviewed; metric warnings are acceptable when the normal-size ordered loop has no visible snap, pop, identity change, or semantic discontinuity.
- `qa/review.json` has no errors.
- Row-by-row review confirms the animation cycles are complete enough for the Codex app.
- Motion previews do not show unintended size popping, reversed directional cadence, or wrong row semantics.
- Look directions follow the fixed clockwise order and form a cohesive, readable loop at normal pet size. Cardinals must be unmistakable. Intermediate blind uncertainty is acceptable as a reviewed warning when labeled normal-size review confirms the intended direction and the loop does not reverse.
- Non-pixel styles are accepted when readable at pet size and consistent across rows.
- `${CODEX_HOME:-$HOME/.codex}/pets/<pet-name>/pet.json` and `${CODEX_HOME:-$HOME/.codex}/pets/<pet-name>/spritesheet.webp` are staged together for custom pets.
