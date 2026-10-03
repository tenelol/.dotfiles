# glassesneo/dotfiles から取り入れる候補

調査日: 2026-10-03。比較対象は `glassesneo/dotfiles` の [`38534df75a90579ee92bae5a75b10391bec2f5a6`](https://github.com/glassesneo/dotfiles/commit/38534df75a90579ee92bae5a75b10391bec2f5a6)（2026-09-28）と、この作業時点のローカル `/Users/tener/.dotfiles`。目的は実装案の選別であり、外部設定の移植ではない。

## 結論

| 優先度 | 候補 | このリポジトリでの最小案 |
| --- | --- | --- |
| 高 | SOPS Age 鍵ローテーション手順 | 現在の `web-server` / `nas` の暗号化ファイル、recipient、システム側 sops-nix に合わせた短い runbook を作る。鍵の生成、再暗号化、暗号文 diff 確認、切替、復旧の順を明記する。 |
| 中 | リポジトリ内リンク・参照元の整合性チェック | README の相対リンクと明示的な Nix のローカルファイル参照に絞り、標準ライブラリの小さな直接実行チェックを追加する。既存の host 評価/build を置き換えない。 |
| 条件付き | Rift 再起動後の SketchyBar 再同期 | 再起動直後に表示が古くなる実例が確認できたら、登録成功後に既存 `REFRESH=all` を一度送る。登録時の準備待ちも同じ障害が再現した場合に限る。 |

### 1. SOPS の運用手順（高）

外部の [鍵ローテーション runbook](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/docs/secrets-key-rotation.md) は、旧鍵を保持して `sops updatekeys` で recipient を更新し、新鍵で復号可能かを内容を表示せず確認してから鍵を切り替える。失敗時の戻し方と、不要な平文・秘密鍵の出力を避ける点も明示している。こちらの [`.sops.yaml`](../../.sops.yaml) は `secrets/web-server/*.enc` と `secrets/nas/*.enc` に別々の recipient ルールを持ち、[Proxmox guest 共通モジュール](../../modules/nixos-proxmox-guests/default.nix) はシステム鍵 `/var/lib/sops-nix/key.txt` を使う。実際の secret 宣言は [web-server](../../modules/nixos-host-web-server/default.nix) と [nas](../../modules/nixos-host-nas/default.nix) にある。鍵更新はこれらの現物を対象にした手順が必要で、運用時の誤操作を減らす価値がある。

外部 runbook の `nh home switch` と Home Manager のユーザー secret/symlink 確認は、こちらの **システム構成へ統合された Home Manager** と NixOS system secret に合わない。[ローカル flake](../../flake.nix) に `homeConfigurations` 出力はなく、[作業規則](../../AGENTS.md) も host の `nh os` / `nh darwin` を前提としている。コマンドを丸写しせず、対象 host ごとの暗号文・recipient・復号検証・切替手段を確定してから記述する。現時点では鍵変更そのものは提案しない。

### 2. 狭い整合性チェック（中）

外部の [`checks/repository-consistency.py`](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/checks/repository-consistency.py) は Python 標準ライブラリで Markdown/Org のローカルリンク、`source = ./...`・`readFile ./...` 等の明示的な Nix ファイル参照を検査し、自己テストも備える。外部 [`flake.nix`](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/flake.nix) はそれを独立 check として公開する。こちらの [README](../../README.md) にも多数の相対リンクがあり、[flake](../../flake.nix) の `checks` は主として host の評価・Linux build を対象とする。リンク切れは Nix の host 評価だけでは見つからないため、対象をこの repo の README と明示的参照に絞った直接チェックは有用。

外部スクリプトは正規表現による**存在確認**であり、Nix の意味解析、動的 path、実行時の正しさまでは保証しない。こちらの `.agents/skills` や既存の feature tests の所有形態を踏まえ、専用の大きな検証基盤、`flake-parts`、Nushell の導入までは必要ない。実装時は壊れたリンクと欠けた参照を検出する最小の runnable check を添える。

### 3. Rift の登録後再同期（条件付き）

外部の [Rift 起動時スクリプト](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/modules/services/sketchybar/widgets/workspace/rift-subscribe-on-start.sh) は、起動元 Rift の生存中だけ登録を 0.1 秒間隔で再試行し、成功直後に [workspace event bridge](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/modules/services/sketchybar/widgets/workspace/handler.nu) を呼んで現状態を再同期する。こちらも [Rift 設定](../../modules/rift/files/config.toml) の `run_on_start` で [登録スクリプト](../../modules/rift/files/sketchybar-workspace-subscribe) を実行し、既存登録を検査して重複を避ける。[SketchyBar 起動時](../../modules/sketchybar/files/sketchybarrc) は `REFRESH=all` を送っており、[Rift activation](../../modules/rift/default.nix) からも登録を試みる。

現状の差は、**Rift の再起動で登録した直後**の明示的な再同期と、CLI がまだ受け付けないときの限定的な待機。実際に表示が古くなる障害は今回確認していない。再現したら現在の callback とテストを使って最小修正を行い、Rift 再起動後の表示で確かめる。外部の workspace handler 全体を移植する理由はない。

## 既にあるもの・今回は採用しないもの

- **Denix / rice 境界**: 外部の [architecture contract](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/docs/denix-architecture.md) は所有者、単一の最終 writer、rice は typed `myconfig` の選択のみという規則を置く。こちらの [AGENTS.md](../../AGENTS.md) に Denix 自動発見、feature module 配置、rice の扱いが既にあり、[Darwin Rift rice](../../rices/darwin/rift.nix) も `myconfig` を選ぶ。全文移植は重複する。実際に複数 feature が同じ upstream option を書く衝突が出たときだけ、単一 writer の境界を局所的に明記する。
- **AquaSKK / HIToolbox 集約**: 外部の [AquaSKK module](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/modules/programs/aquaskk/default.nix) は [input-methods](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/modules/system/input-methods.nix) に配列要素を寄せ、AquaSKK 固有の [plist 起動問題](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/modules/programs/aquaskk/README.md) を扱う。こちらの [azooKey module](../../modules/azookey/default.nix) が現在の入力ソース配列をまとめて管理する。複数 IME を併用する要件が出るまでは集約インターフェースを増やさず、AquaSKK の復旧手順も取り込まない。
- **host tier**: 外部の [tier schema](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/flake.nix)、[比較 helper](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/modules/config/host-tier.nix)、[説明](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/docs/host-tiers.md) は手動ラベルを示す。こちらは [host ごとの構成](../../flake.nix) と feature 選択で足りている。能力差が同じ複数 module の既定値に反復して現れた場合に検討する。
- **大きな検証 runner / 契約 suite**: 外部は [`check-full`](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/checks/full-validation.sh)、[configuration contracts](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/checks/configuration-contracts.nu)、[検証方針](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/docs/nix-validation.md) を持つ。こちらは [flake checks](../../flake.nix) と feature ごとの artifact tests を既に持ち、[作業規則](../../AGENTS.md) は依頼なしの CI 型 Nix 検証・build/switch を禁じる。外部の複数 platform build や standalone Home Manager activation を伴う runner は採用しない。特定の生成物に評価だけでは観測できない不具合が出た場合、消費者の検査をその feature のテストへ小さく加える。
- **TCC 安定配置**: 外部の [tcc-stable-binaries](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/modules/system/tcc-stable-binaries.nix) は Nix store の実行ファイルを安定した場所へコピーする仕組み。こちらの [macOS Homebrew 管理](../../modules/darwin-homebrew/default.nix) と現在の所有箇所で具体的な TCC 失効が確認されていないため、共通抽象化は増やさない。

## 確認範囲と限界

外部の `README.org`、`flake.nix`、主要な設計・運用 docs、`checks/` の実コード、AquaSKK、input-methods、tier、rice、Rift/SketchyBar、TCC module を上記コミットで読んだ。ローカルの README、flake、関連 module・script と照合した。全ファイルの監査、実機の macOS/Rift 動作、secret の復号、Nix 評価・build・switch、CI 実行はしていない。したがって「条件付き」候補は実障害や効果を確認した結論ではない。
