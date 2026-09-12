---
name: apple-design
description: "Webのジェスチャー・アニメーションをAppleらしい操作感に設計・改善するときに使う。"
---

# Apple Design

Webの操作感を、直接操作・連続した応答・割込み可能なmotionとして設計する。既存のデザインシステムとユーザーの指定を優先する。

- pointerの動きとdrag対象を結びつけ、途中の操作変更にも応答させる。
- motionには位置関係や状態変化を伝える目的を持たせる。装飾のためだけに増やさない。
- reduced motion、keyboard操作、描画性能を対象の操作に応じて確認する。
- 小さな修正に全原則のレビューを要求せず、該当する問題の参照だけ読む。

## 必要な操作だけ読む

該当する操作の参照だけ読み、別の操作の手順は必要になった時点で開く。

| 操作・条件 | 参照 |
| --- | --- |
| 直接操作・spring・割込み・ジェスチャー設計 | [手順](references/gestures.md) |
| 描画性能・素材・フィードバック・reduced motion | [手順](references/rendering.md) |
| 文字組み・視覚階層・デザイン原則 | [手順](references/typography.md) |
| 大きな操作設計の検討と参照表 | [手順](references/process.md) |
