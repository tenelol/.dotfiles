# 生成・透明度・時間と収束の条件

この手順内の `scripts/`・`references/`・`research/` は元のスキルルート基準。明示された作業ディレクトリはその指定に従う。

## Generation Contract

### Visual Job Graph

Expect up to 13 visual jobs: 1 base pet, 9 standard row strips, 1 required four-cardinal anchor strip, and 2 required coherent look-direction row strips. The standard states are `idle`, `running-right`, `running-left`, `waving`, `jumping`, `failed`, `waiting`, `running`, and `review`. The only deterministic visual derivation is `running-left`, which may be produced by mirroring `running-right` only after `running-right` has been generated, visually inspected, and explicitly approved as safe to mirror. If mirroring is not appropriate, generate `running-left` as a normal grounded `$imagegen` row.

### Look Direction Sequence

After validating rows 0–8, write qa/look-mechanics.md, then generate and approve one four-pose cardinal strip in this fixed order: 000 up, 090 screen-right, 180 down, and 270 screen-left. Generate row 9 as one coherent eight-pose family from those approved cardinal pose families, interpolating the intermediate directions as even 22.5-degree steps. Deterministically register its eight ordered pose groups, then run final-cell edge, semantic, and continuity QA immediately. Only after row 9 passes, generate row 10 as one coherent eight-pose family, using the approved cardinals for direction meaning and completed row 9 for identity, scale, registration, and boundary continuity. Run the same QA immediately after row 10. Row 9 contains 000, 022.5, 045, 067.5, 090, 112.5, 135, and 157.5; row 10 contains 180, 202.5, 225, 247.5, 270, 292.5, 315, and 337.5. 000 means up, not neutral/front. Never ask $imagegen to generate or repair a complete 8×11 atlas.

### Visual Provenance And Grounding

After selecting a visual output, the parent agent copies that exact image into the job's `decoded/` path, runs its required incremental checks, and only then marks the job complete in `imagegen-jobs.json`. Do not write helper scripts that populate row outputs. The deterministic Python scripts may only process already-generated visual outputs.

Only the base job may be prompt-only. Every row-strip job generated through `$imagegen` must use the input images listed in `imagegen-jobs.json`, including the canonical base reference created after the selected base output is copied. Treat any row generation without attached grounding images as invalid.

## Pet-Safe Styles

Default style is `auto`: infer the pet's style from the user's prompt and references, then preserve that style across every row. If the user names a style, honor it. Supported style presets include `pixel`, `plush`, `clay`, `sticker`, `flat-vector`, `3d-toy`, `painterly`, `brand-inspired`, and `auto`.

Any style is acceptable when it remains pet-safe:

- compact whole-body silhouette readable inside a `192x208` cell
- consistent face, proportions, material, palette, and props across all rows
- clean removable chroma-key background
- details large enough to read at pet size
- no text, labels, UI, or readable logos unless the user explicitly provides approved reference art and asks for them

Non-pixel styles are first-class. Plush, clay, sticker, vector, 3D toy, painterly mascot, ink, and brand-inspired looks should be accepted when they satisfy the atlas and readability constraints.

## Transparency And Effects

Pet rows are processed into transparent `192x208` cells, so every generated pixel must either belong to the pet sprite or be cleanly removable chroma-key background. Prefer pose, expression, and silhouette changes over decorative effects.

The deterministic raster pipeline owns the transparency and chroma-cleanup invariants. Its final edge-local spill-suppression step selects every translucent silhouette-boundary pixel plus opaque boundary pixels whose chroma points toward the known key, then extends clean interior RGB outward through that band in linear light. It preserves alpha exactly, clears hidden RGB under fully transparent pixels, and reports the algorithm and parameters used. The cleanup report plus atlas validator are authoritative for chroma contamination. Once the final report has `ok: true` and atlas validation passes, do not regenerate imagery or add another chroma-cleanup pass.

Fully transparent pixels are allowed outside the sprite silhouette, in unused cells, and in intentional negative-space openings that are part of the pet's design, such as loops or holes in a ribbon body. Reject any generated or repaired cell with accidental 100%-transparent holes inside a filled body, including horizontal bands, seam rows, scanline-like gaps, sliced-tile boundaries, or "see-through" interior stripes. Inspect suspect cells on a high-contrast background or alpha mask before accepting them; ordinary atlas validation is not enough when the hole is inside the silhouette.

Allowed effects must satisfy all of these conditions:

- The effect is state-relevant and helps explain the animation.
- The effect is physically attached to, touching, or overlapping the pet silhouette, not floating nearby.
- The effect is inside the same frame slot as the pet and does not create a separate sprite component.
- The effect is opaque, hard-edged enough for clean extraction, and uses non-chroma-key colors.
- The effect is small enough to remain readable at `192x208` without clutter.

Avoid these by default because they usually break transparent-background cleanup or component extraction:

- wave marks, motion arcs, speed lines, action streaks, afterimages, blur, or smears
- detached stars, loose sparkles, floating punctuation, floating icons, falling tear drops, separated smoke clouds, or loose dust
- cast shadows, contact shadows, drop shadows, oval floor shadows, floor patches, landing marks, impact bursts, glow, halo, aura, or soft transparent effects
- text, labels, frame numbers, visible grids, guide marks, speech bubbles, thought bubbles, UI panels, code snippets, checkerboard transparency, white backgrounds, black backgrounds, or scenery
- chroma-key-adjacent colors in the pet, prop, effects, highlights, or shadows
- stray pixels, disconnected outline bits, speckle/noise, cropped body parts, overlapping poses, or any pose that crosses into a neighboring frame slot

State-specific guidance:

- `idle`: keep this calm and low-distraction. Use only subtle breathing, a tiny blink, a slight head or body bob, a very small material sway, or another quiet persona-preserving motion. The loop must still contain visible micro-variation; do not accept six effectively identical copies. Do not show waving, walking, running, jumping, talking, working, reviewing, emotional reactions, large gestures, item interactions, or new props.
- `waving`: show the wave through paw, hand, wing, or limb pose only. Do not draw wave marks, motion arcs, lines, sparkles, symbols, or floating effects around the gesture.
- `jumping`: show vertical motion through body position only. Do not draw shadows, dust, landing marks, impact bursts, bounce pads, or floor cues.
- `failed`: tears, attached smoke puffs, or attached stars are allowed if they obey the allowed-effects rules; do not use red X marks, floating symbols, detached smoke, detached stars, or separate tear droplets.
- `waiting`: show that Codex needs approval, help, or user input through an expectant asking pose. Keep it distinct from ordinary idle and review.
- `running`: show active task work, processing, thinking, scanning, typing, or focused effort. Do not show literal foot-running, jogging, sprinting, treadmill motion, raised knees, long steps, pumping arms, directional travel, speed lines, dust clouds, floor shadows, motion trails, or detached motion effects.
- `review`: show focus through lean, blink, eyes, head tilt, or paw/hand position. Do not add magnifying glasses, papers, code, UI, punctuation, symbols, or other new props unless they already exist in the base pet identity.
- `running-right` and `running-left`: show directional drag movement through body, limb, and prop movement only. `running-right` must face and travel right; `running-left` must face and travel left. Their cadence must visibly alternate across the loop rather than repeating one nearly static stride. Do not draw speed lines, dust clouds, floor shadows, motion trails, or detached motion effects.

## Visible Progress Plan

For every pet run, keep a visible checklist so the user can see where the work is up to. Create the checklist before starting, keep one step active at a time, and update it as each step finishes.

Use this checklist for every v2 pet run, replacing `<Pet>` with the pet's name or `your pet`:

1. Getting `<Pet>` ready.
2. Imagining `<Pet>`'s main look.
3. Picturing `<Pet>`'s poses.
4. Hatching `<Pet>`.

What each step means:

- `Getting <Pet> ready.` Choose or confirm the pet name, description, source images, style preset, style notes, and working folder. For bare brand/product/company requests, first run the brand discovery worker and capture the compact brand brief, source URLs, and avatar seed.
- `Imagining <Pet>'s main look.` Generate the pet's main reference image. This becomes the visual source of truth.
- `Picturing <Pet>'s poses.` Generate and approve rows `0-8`, write the pet-specific look mechanics plan, then generate rows `9-10`. Only mirror `running-left` if `running-right` clearly works when flipped.
- `Hatching <Pet>.` Assemble the 8x11 atlas, review standard motion plus all 16 look directions, fix every failed cell or row, package `spriteVersionNumber: 2`, and report the output paths.

Only mark a step complete when the real file, image, or decision exists. If this is a repair run, start from the first relevant step instead of restarting the whole checklist.

## Time Budget And Convergence

Aim to complete a normal pet run within 30 minutes while preserving every mandatory acceptance criterion. Treat this as a planning target and an incentive to maximize validated progress per minute, not as permission to weaken QA or package a failing pet.

At the start of the run, allocate an approximate budget:

- preparation: 2 minutes
- base image: 3 minutes
- standard rows: 10 minutes
- look directions: 8 minutes
- final QA and packaging: 5 minutes
- buffer: 2 minutes

Run independent generation jobs concurrently up to the worker limit, start deterministic checks as soon as each dependency is ready, and record actual stage plus repair time. Prefer character and prop constructions that naturally satisfy cell geometry, transparency, component connectivity, and direction semantics; identify likely conflicts such as open interior gaps, detached parts, thin connectors, asymmetric props, or ambiguous faces before row generation.

After every failed attempt:

1. Classify the failure as visual semantics, identity, source-edge geometry, component connectivity, extraction, chroma, continuity, or final visual QA.
2. State the concrete evidence and the root condition the next action will change.
3. Use a deterministic correction for deterministic failures before regenerating imagery.
4. Regenerate only when the source visual is genuinely wrong, and preserve every property that already passed.
5. Compare the new result with the previous one. A repair counts as progress only when it reduces the number or severity of failures without breaking a previously passing gate.

If the same root failure recurs twice, stop varying the prompt and change strategy: strengthen the cardinal pose families or row-level direction instructions, simplify the pose or prop construction, change the deterministic extraction method, or redesign the problematic visual feature. If a repair merely moves a failure to another cell or gate, treat that as a cycle and change strategy immediately.

Use elapsed-time checkpoints:

- At 15 minutes, verify the run is on pace and that the remaining dependency path is bounded.
- At 25 minutes, prioritize the shortest quality-preserving path through remaining blockers and avoid optional polish.
- At 30 minutes, continue only when the remaining work is clearly converging and bounded, such as final validation, one targeted repair, or packaging.
- Keep recording elapsed time, retries, validation failures, and QA cost throughout the run, but do not pause or stop solely because elapsed time crosses 45 or 60 minutes. Continue until the pet passes, the user cancels, or a genuine external blocker prevents further progress.

Never use the time target to skip blind direction QA, labeled semantics, continuity review, atlas validation, despill validation, final visual QA, or any other acceptance criterion.
