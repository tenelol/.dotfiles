この手順内の `scripts/`・`references/`・`research/` は元のスキルルート基準。明示された作業ディレクトリはその指定に従う。

# Hatch Pet

## Overview

Create a Codex-compatible v2 animated pet from a concept, brand cue, company/prospect name, one or more reference images, or any combination of those inputs. Every newly hatched pet is an 8x11 atlas with the 9 standard animation rows plus 16 clockwise look directions and is packaged with `spriteVersionNumber: 2`. The intermediate 8x9 atlas exists only to assemble and review rows 0-8; never package it as a new pet.

User-facing inputs are optional. If the user omits a pet name, infer one from the concept, brand, company, or reference filenames; if that is not possible, choose a short friendly name. If the user omits a description, infer one from the concept or references. If the user omits reference images, generate the base pet from text first, then use that base as the canonical reference for every animation row.

## Existing Inputs And Upgrades

Treat character art, generated images, standard or v2 atlases, contact sheets, and built-in pet art as first-class grounding inputs.

- Preserve user-provided art as a generation reference; do not assume it already has final cell geometry.
- For an existing valid 8x9 atlas, use it as the rows `0-8` intermediate after deterministic and visual validation, then generate rows `9-10` and package the result as v2.
- For an existing 8x11 atlas, preserve approved standard rows. If a look cell fails, correct the complete containing 8-frame row before deterministic reassembly. Never package a newly generated one-off repair cell beside cells from another generation.
- For a built-in pet, extract and use its atlas or neutral/idle cell as the canonical identity reference.
- Include every image that defines head shape, face, palette, markings, material, flame/ears/hair, props, or look mechanics in look-direction generation.
- When a renderer or source provides a dedicated neutral/front frame, pass it through `--neutral-cell`; otherwise use the approved idle/default frame. The 16 directional cells never treat `000` as neutral.

## Generation Delegation

Use `$imagegen` for all normal visual generation.

Before generating base art, row strips, or repair rows, load and follow the installed image generation skill:

```text
${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/SKILL.md
```

Do not call the Image API, image CLI, or any other image-generation path directly. Let `$imagegen` choose its own built-in-first path and fallback rules. If `$imagegen` says a fallback requires confirmation, ask the user before continuing.

When invoking `$imagegen`, pass the generated pet prompt as the authoritative visual spec. Pet prompts should stay concise, state-specific, sprite-production oriented, and grounded in the listed input images. Keep longer policy and QA rules in this skill and the deterministic review scripts rather than expanding them into every image prompt. Do not wrap prompts in the generic `$imagegen` shared prompt schema.

Use this skill's scripts for deterministic image work only: preparing layout guides and prompts, mirroring approved `running-left`, extracting frames, validating rows, composing the final atlas, and creating contact-sheet plus motion-preview QA media. Parent-owned shell/`jq` steps handle manifest updates, packaging, and cleanup.

## Runtime Dependencies

Before running any bundled script, call `load_workspace_dependencies`. Set `PYTHON` to the exact Python executable path returned by that tool and use `"$PYTHON"` for every command below. The bundled runtime includes Pillow, which these scripts require. Do not use a bare system `python`; if workspace dependencies are unavailable, stop and report that the bundled runtime is required.

## Storage Controls

The built-in `$imagegen` path stores generated PNG bytes in the rollout that invokes it, even when it also writes a file under `${CODEX_HOME:-$HOME/.codex}/generated_images`. Deleting files later reduces filesystem use, but it does not shrink an already-written rollout. Keep image generation isolated and bounded:

- When delegation helps and is permitted, use one bounded worker per visual job. With a no-subagent request, perform jobs locally and keep the same generation boundaries.
- Workers must return only `selected_source=...` and `qa_note=...`; they must not include Markdown image previews, base64, or extra visual attachments in their final response.
- Use worker QA when available; otherwise perform visual checks locally. Inspect the final contact sheet and any unresolved row, without reopening already verified images.
- After copying the selected generated output into `decoded/`, remove the selected original from `${CODEX_HOME:-$HOME/.codex}/generated_images` when it lives there, then remove its now-empty generation directory if possible.
- For storage-sensitive full runs, ask the user whether to use the `$imagegen` CLI fallback when available. That path requires local API credentials and explicit user confirmation, but it can avoid built-in image payloads being embedded in rollout events.

## Brand Discovery

If the user provides a brand, company, product, or prospect name rather than a concrete avatar description or reference image, perform a narrow discovery pass before preparing the pet run. Delegate only if useful and permitted. Use web search and prefer official sources such as the brand site, product pages, docs, about pages, press pages, or brand pages. Use reputable secondary sources only when official pages are too thin. Keep the search narrow: enough to extract visual and personality cues, not a market-research brief.

Skip discovery when the user already provides a concrete mascot/avatar description or reference images, unless the user explicitly asks for brand research.

Discovery worker responsibilities:

- search the web for 2-4 relevant sources, preferring official pages
- write an adaptive markdown brief rather than a rigid field dump
- cover identity/category, audience/use context, visual system, personality/tone, product/domain motifs, mascot translation cues, avoidances, and evidence/confidence
- mark mascot guidance that is inferred from sources as inference
- avoid copying logos, readable marks, UI screenshots, slogans, or text
- end with a compact `Generation handoff` section containing only `brand_name`, `brand_brief`, `avatar_seed`, `avoid`, and `brand_sources`
- do not generate images, prepare run folders, or edit unrelated files

Use this discovery worker prompt:

```text
Research a brand for hatch-pet mascot creation.

Brand/product/prospect: <brand name>
User context: <short user request>
Output file: <absolute path to brand-discovery.md>

Use web search. Prefer official brand, product, docs, about, press, or brand pages. Use reputable secondary sources only if official sources are too thin. Write an adaptive markdown brief to the output file. Headings may flex by brand, but the brief must cover:
- identity/category: canonical name, product type, what it does
- audience/use context: who it serves and where it appears
- visual system: palette, shapes, line quality, materials, typography feel, iconography, patterns
- personality/tone: emotional traits, energy, formality, playfulness
- product/domain motifs: objects, workflows, verbs, metaphors, environments
- mascot translation cues: candidate forms, signature traits, props, what must read at pet size
- avoidances: logos/text, trademark-sensitive elements, misleading cues, competitor confusion, poor mascot fits
- evidence/confidence: source URLs plus notes where evidence is weak or inferred

Do not copy logos, readable marks, UI screenshots, slogans, or text. Clearly label mascot guidance that is inferred rather than directly sourced.

End the brief with a `Generation handoff` section containing exactly:
- brand_name=<canonical brand/product name>
- brand_brief=<one sentence, max 45 words, covering palette/tone/domain motifs/personality>
- avatar_seed=<short mascot-safe visual idea, no logo copying>
- avoid=<short comma-separated list>
- brand_sources=<comma-separated source URLs>

Return exactly:
brand_discovery_file=<absolute output file path>
brand_name=<canonical brand/product name>
brand_brief=<same compact sentence from Generation handoff>
avatar_seed=<same short seed from Generation handoff>
avoid=<same short avoid list from Generation handoff>
brand_sources=<same comma-separated URLs from Generation handoff>
```

The parent should save the markdown brief before preparing the run, then pass it to `prepare_pet_run.py` as `--brand-discovery-file` together with `--brand-name`, `--brand-brief`, repeated `--brand-source`, and a concise `--pet-notes` value based on `avatar_seed` when the user did not provide a better avatar description. Keep the full brief for review; only the compact handoff fields should shape prompts. If web search is unavailable and the user gave only a bare brand name, ask for brand cues before generating.
