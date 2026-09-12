---
name: hatch-pet
description: "Codex用のv2アニメーションpetを作成・修復・検証・梱包するときに使う。"
---

# Hatch Pet

Create or repair a Codex v2 animated pet. Preserve its identity and approved rows. A new package uses an 8×11 atlas, nine standard animation rows, sixteen look directions, and `spriteVersionNumber: 2`; the 8×9 atlas is an intermediate only.

- Use the installed `imagegen` skill for visual generation and the bundled scripts for deterministic layout, assembly and validation. Resolve workspace Python dependencies before running image scripts.
- Read the generation contract before generating, and the repair/acceptance reference before packaging. Do not claim acceptance while a required direction or final visual check is unresolved.
- Delegate only when independent jobs or image-context isolation help, through `subagent-model-router`. Respect a no-subagent request: perform generation and review locally, record that independent blind QA is unavailable, and do not fabricate worker verdicts or independent consensus.
- Preserve the declared output schemas and the final single chroma-cleanup pass. Clean only known intermediates after the selected output and required QA are retained.

## 必要な操作だけ読む

該当する操作の参照だけ読み、別の操作の手順は必要になった時点で開く。

| 操作・条件 | 参照 |
| --- | --- |
| 既存画像・依存・ブランド調査・生成の準備 | [手順](references/preparation.md) |
| 生成・透明度・時間と収束の条件 | [手順](references/generation-contract.md) |
| ベース画像と標準9行の作成 | [手順](references/standard-rows.md) |
| 16方向・v2組立・最終QA・梱包 | [手順](references/look-directions.md) |
| 委譲に利点がある場合のworker境界とprompt | [手順](references/delegation.md) |
| 既存petの修復と受け入れ条件 | [手順](references/repair-and-acceptance.md) |
