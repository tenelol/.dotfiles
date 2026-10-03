# glassesneo/dotfiles の設計比較と denix リファクタリング候補

調査日: 2026-10-03。比較対象は `glassesneo/dotfiles` の [`38534df75a90579ee92bae5a75b10391bec2f5a6`](https://github.com/glassesneo/dotfiles/commit/38534df75a90579ee92bae5a75b10391bec2f5a6)（2026-09-28、今回取得した HEAD も同じ）と、ローカル `/Users/tener/.dotfiles` の `21c6dcd198b9eea6762227878649c7efe6074770` および作業開始時の working tree。既存の Neovim 未 commit 変更を保持して調査した。denix の根拠は最新一般論ではなく、ローカル `flake.lock` が固定する [`271d76816ca215d80e6736ab24d8d22417b24773`](https://github.com/yunfachi/denix/tree/271d76816ca215d80e6736ab24d8d22417b24773)。目的は実装案の選別であり、設定変更・build・switch は行っていない。

## 結論

**取り入れる価値がある。特に、繰り返す適用条件の集約と、排他的な機能を一つの型付き選択値で表す設計が有力。** ローカルの `modules/`・`hosts/`・`rices/` の `.nix` を静的に走査すると、63個の feature module 中、`lib.mkIf` / `pkgs.lib.mkIf` は **32箇所・21ファイル**。うち26箇所は module の出力全体をホスト・OS条件で包む形で、抽象化対象としてまとまっている。ただし、denix 標準が自動で吸収する条件と、リポジトリ側で追加の interface が必要な条件は異なる。

| 優先度 | 候補 | このリポジトリでの最小案 |
| --- | --- | --- |
| 高・小変更 | `nixbuild` の有効化条件を denix に移す | `nixos.always` / `darwin.always` と手動の `mkIf cfg.enable` を `*.ifEnabled` にする。現行コードの一時コピーで NixOS/Darwin × on/off の4ケースが一致した。 |
| 高・段階的 | host/OS 条件の共有と module 適用条件の集約 | `args.shared` で共通判定を供給し、小さな denix extension の `scopedModule` で繰り返す外側の条件を一度だけ書く。まず Hyprland、AeroSpace、Rift 等の代表例で確認する。 |
| 中・interface変更 | window manager の単一選択値 | Darwin は `"native" / "rift" / "aerospace"`、Linux は `"niri" / "hyprland"` の enum を候補にする。rice の複数 enable 指定を減らし、provider の有効化を導出する。 |
| 高 | SOPS Age 鍵ローテーション手順 | 現在の `web-server` / `nas` の暗号化ファイル、recipient、システム側 sops-nix に合わせた短い runbook を作る。鍵の生成、再暗号化、暗号文 diff 確認、切替、復旧の順を明記する。 |
| 中 | リポジトリ内リンク・参照元の整合性チェック | README の相対リンクと明示的な Nix のローカルファイル参照に絞り、標準ライブラリの小さな直接実行チェックを追加する。既存の host 評価/build を置き換えない。 |
| 条件付き | Rift 再起動後の SketchyBar 再同期 | 再起動直後に表示が古くなる実例が確認できたら、登録成功後に既存 `REFRESH=all` を一度送る。登録時の準備待ちも同じ障害が再現した場合に限る。 |

## denix と `mkIf` の調査

### 標準で既に抽象化されているもの

固定版の [`delib.module` 実装](https://github.com/yunfachi/denix/blob/271d76816ca215d80e6736ab24d8d22417b24773/lib/configurations/module.nix#L45-L81) は、module 名から `cfg` を解決し、`ifEnabled` を `cfg.enable`、`ifDisabled` をその逆で内部の `mkIf` に包む。`enable` option 自体がない場合は両方とも適用されない。callback へは `name`・`cfg`・`parent`・`myconfig` を渡す。[公式の module structure](https://github.com/yunfachi/denix/blob/271d76816ca215d80e6736ab24d8d22417b24773/docs/src/modules/structure.md#L4-L21) と実装の両方で確認した。

[`apply.nix`](https://github.com/yunfachi/denix/blob/271d76816ca215d80e6736ab24d8d22417b24773/lib/configurations/apply.nix#L9-L54) は `nixos.*` を NixOS に、`darwin.*` を nix-darwin に振り分ける。一方、**`home.*` は統合 Home Manager に対して Linux/Darwin の両方で適用される**。したがって `nixos.*` 内の Linux 判定、`darwin.*` 内の Darwin 判定は通常重複するが、`home.*` 内の OS 判定はそのまま必要になり得る。また、サーバー除外や特定 host 限定は標準では補わない。

固定版の `delib.module` の引数は `name`・`options`・`myconfig`・`nixos`・`home`・`darwin` であり、module 全体に効く `scope` / `condition` / `enable` 引数は存在しない。以下の `scopedModule` は **追加を検討する独自 interface** である。[extension の `libExtension`](https://github.com/yunfachi/denix/blob/271d76816ca215d80e6736ab24d8d22417b24773/lib/extension.nix#L41-L57) に小さな関数を追加する形なら、denix の内部実装を fork せず実現できる。

### 32箇所の内訳

走査対象は上記3ディレクトリの `.nix`。単純な文字列出現の集計で、展開後の定義数や設定全体の品質を表す数字ではない。

| 種類 | 箇所数 | 具体例 | 判断 |
| --- | ---: | --- | --- |
| 自分の `cfg.enable` を手動で判定 | 1 | [nixbuild](../../modules/nixbuild/default.nix) | denix 標準の `ifEnabled` へ移せる。 |
| `nixos.*` 内の Linux 判定＋別の機能条件 | 1 | [boot](../../modules/nixos-boot/default.nix) の `Linux && efiLimine` | Linux 判定のみ省ける。`efiLimine` 条件は残す。 |
| 出力全体への host/OS 適用条件 | 26 | 16ファイル。うち `*.ifEnabled = mkIf …` は18箇所・12ファイル | 条件の共有や module wrapper の主対象。適用条件の意味を保って集約する。 |
| module 内部の部分的な条件 | 4 | [theme](../../modules/theme/default.nix) の Linux 部分、[qutebrowser](../../modules/qutebrowser/default.nix) / [zen-browser](../../modules/zen-browser/default.nix) の MIME、[nixos.desktop](../../modules/nixos-system/default.nix) の portal | `mkIf` / `optionals` を残すか、OS部分を別の明確な feature に分ける。汎用 wrapper だけでは消えない。 |

26箇所には `*.ifEnabled` の18箇所に加え、AeroSpace/Rift の `darwin.always` が2箇所、Kanata の `ifDisabled` が2箇所、lazygit/yazi/VSCode/theme の `home.always` が4箇所含まれる。

### A. そのまま直せる重複

[nixbuild](../../modules/nixbuild/default.nix) は共通設定を `lib.mkIf cfg.enable` で包んだ上で `nixos.always` / `darwin.always` へ渡している。次の形へ移せば、同じ条件を denix が担う。

```nix
# options は現在のまま。config 関数内の mkIf cfg.enable を取り除く。
nixos.ifEnabled = config;
darwin.ifEnabled = config;
```

`config` 関数も `{ cfg, ... }: { ... }` にすると、`myconfig.nixbuild` を手動で引く必要がなくなる。ただし前後一致の実験は、外側の条件移動だけを施したコピーを使った。[boot](../../modules/nixos-boot/default.nix) は `enable` option を持たず `efiLimine` を持つので、単純に `ifEnabled` へ変えると設定が出なくなる。こちらは `nixos.always = { cfg, ... }: lib.mkIf cfg.efiLimine { ... };` が小さな整理案。

### B. 適用対象を一度だけ指定する

同じ `isDarwinDesktop` / `isLinuxDesktop` 定義が **9箇所・8ファイル**、同じ `isMacbook` 判定が **5ファイル**にある。[kanata](../../modules/kanata/default.nix)、[aerospace](../../modules/aerospace/default.nix)、[rift](../../modules/rift/default.nix)、[hyprland](../../modules/hyprland/default.nix)、[codex-cli](../../modules/codex-cli/default.nix) 等で確認した。

最初に共有するのは host の事実から計算する純粋な判定だけでよい。既に有効な [`args` extension](https://github.com/yunfachi/denix/blob/271d76816ca215d80e6736ab24d8d22417b24773/lib/extensions/args.nix#L15-L45) と、ローカル [home-manager module](../../modules/home-manager/default.nix) の `myconfig.always.args.shared.hm` が先例になる。

```nix
# 所有する denix module の例。現在は未導入。
myconfig.always.args.shared.hostTraits = {
  linuxDesktop = !host.isServer && lib.hasSuffix "-linux" host.system;
  darwinDesktop = !host.isServer && lib.hasSuffix "-darwin" host.system;
  macbook = host.name == "macbook" && lib.hasSuffix "-darwin" host.system;
};
```

この段階で判定式の複製は減るが、各出力の `mkIf` は残る。次に、**条件を一度書いて `always` / `ifEnabled` / `ifDisabled` の寄与に適用する**小さな wrapper を検討する。`options` は常に宣言し、機能の選択と適用対象を区別する。

```nix
# 独自の scopedModule を追加した場合の Hyprland の呼び出し例。
delib.scopedModule {
  name = "hyprland";
  scope = hostTraits.linuxDesktop;
  options = delib.singleEnableOption false;

  nixos.ifEnabled = {
    programs.hyprland.enable = true;
    programs.hyprland.xwayland.enable = true;
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    };
  };
  home.ifEnabled.xdg.configFile."hypr/hyprland.conf".text =
    displayConfig + "\n" + baseConfig;
}
```

共通処理の核は次の程度で足りる。これは最小評価で試した処理を denix extension の形で示した設計案で、設定には組み込んでいない。

```nix
delib.extension {
  name = "module-scope";
  libExtension = _: final: prev: {
    scopedModule = { scope, ... }@args:
      let
        gate = body:
          if builtins.isFunction body then
            callbackArgs: lib.mkIf scope (body callbackArgs)
          else
            lib.mkIf scope body;
      in
      prev.module (builtins.removeAttrs args [ "scope" ] //
        lib.genAttrs [ "myconfig" "nixos" "home" "darwin" ]
          (target: lib.mapAttrs (_: gate) (args.${target} or {})));
  };
}
```

これなら callback の `cfg` 等を保ち、disabled 時の cleanup と常時導入する Homebrew の寄与も扱える。[Rift](../../modules/rift/default.nix) と [AeroSpace](../../modules/aerospace/default.nix) は、rice が無効でも `darwin.always` でツールをインストールする現行仕様がある。これを全部 `ifEnabled` に寄せるのは挙動変更になる。[Kanata](../../modules/kanata/default.nix) の cleanup は `ifDisabled` を保つ。両OSにまたがる module は、出力の routing と条件を個別に確認してから適用する。

配置案は独自 extension を auto-discovery 対象外の `extensions/module-scope/`、共有判定を通常の `modules/host-policy/default.nix` に置く形。これは新規設計案であり、[現行規則](../../AGENTS.md) に合わせ、一般の helper `.nix` を `modules/` に置いて誤って自動発見させることや、既存 module の手動 import は避ける。import 時に `host` や `myconfig` へ依存して対象 module ごと消す方式も、module 評価の再帰や未宣言 option を招くため採らない。

### C. default と適用条件を混同しない

`singleEnableOption isDarwinDesktop` は **既定値**であり、Linux/server で手動設定した `enable = true` を禁止するものではない。現在の `home.ifEnabled = mkIf isDarwinDesktop { ... };` を、既定値が同じという理由で削除すると適用対象が広がる。この反例は最小評価でも確認した。

[SketchyBar](../../modules/sketchybar/default.nix) のように既定値だけで OS を限定する module と、[Karabiner](../../modules/karabiner/default.nix) のように追加 guard を持つ module が混在している。refactor 時には「非対応 host の手動 enable は無視する／明示エラーにする／対応させる」のどれを意味するかを揃える必要がある。まずは既存 guard の意味を保つ wrapper に限定する。`enable = scope && requested` だけで済ませると、対象外で `ifDisabled` の cleanup が動くおそれもある。

値リストを作る `lib.optionals`、設定を module semantics で条件付きにする `lib.mkIf`、静的 attrset を作る `lib.optionalAttrs` も一括置換しない。OSにより package が存在するか、`config` 依存条件か、option 自体が存在するかを各利用箇所で確認する。

## 参照先から取り入れたい設計

### 排他的 backend の型付き選択値

参照先の [window-manager](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/modules/services/window-manager.nix#L13-L49) は backend enum を選び、[AeroSpace](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/modules/services/aerospace.nix#L10-L18) / [Rift](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/modules/services/rift/default.nix#L57-L65) の read-only enable を導出する。assertion で選択と provider の一致も確認する。launcher にも [同じ方式](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/modules/programs/application-launcher/default.nix#L13-L39) がある。

ローカルの [Rift rice](../../rices/darwin/rift.nix)、[AeroSpace rice](../../rices/darwin/aerospace.nix)、[native rice](../../rices/darwin/mac.nix) は `rift.enable` / `aerospace.enable` / `autoraise.enable` を個別に指定している。次のように policy を一つにすれば、排他性と AutoRaise の依存関係を同じ owner が管理できる。

```nix
# 新しい interface の案。現行の option 名ではない。
myconfig.desktop.darwin.windowManager = "rift";
# native rice は "native"、AeroSpace rice は "aerospace"。
```

参照先の enum は AeroSpace/Rift の2択と別の `enable` flag なので、こちらの native rice を含めるには適応が必要。JankyBorders の選択は native rice 固有の現在値を維持する。Linux の [Niri](../../rices/linux/niri.nix) / [Hyprland](../../rices/linux/hyprland.nix) の enable 対も同じ整理候補で、[nixos.desktop の portal](../../modules/nixos-system/default.nix) は選択値を消費できる。ただし Darwin と Linux を強制的に一つの enum にしない。既存 bool override の移行、非対応 host の扱い、launchd/process cleanup は interface 変更として別途検証する。今回、二重起動の実障害は確認していない。

### 共有設定の最終 writer と contribution interface

参照先は [architecture contract](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/docs/denix-architecture.md#L36-L67) で、feature が型付き寄与を提供し、共有する設定には最終 writer を置く。例えば [SketchyBar workspace widget](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/modules/services/sketchybar/widgets/workspace/default.nix#L49-L59) が `services.rift.startupCommands` にコマンドを追加し、[Rift module](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/modules/services/rift/default.nix#L102-L115) が `run_on_start` を生成する。

こちらも Rift への startup hook や macOS 入力ソースを複数 feature が書くようになれば有用。ただし現在の azooKey 入力ソース管理や Rift 専用連携だけなら owner は既に局所化している。Nix が自然に merge できる `home.packages` / `homebrew.brews` の複数寄与まで禁止したり、汎用 event bus を作ったりする必要はない。

### 構造の模倣より interface の選別

参照先の共有データは `modules/config/`、広域 integration は `modules/toplevel/` にある。[README](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/README.org#L4-L18) と [directory owners](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/docs/denix-architecture.md#L13-L31) で確認した。こちらの feature directory と `files/`・`tests/` の同居を維持し、有用な interface だけ導入する。参照先が持つ [standalone `homeConfigurations`](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/flake.nix#L66-L87)、`flake-parts`、`justfile` は現在の統合 Home Manager / `nh` の運用に必須ではない。

色 registry や host tier は下記の条件付き候補のまま。参照先も [Home Manager の Darwin 設定](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/modules/toplevel/home-manager.nix#L33-L53) や workspace hook に `mkIf` を残しており、`mkIf` をゼロにする設計ではない。

## 進める場合の順序と検証

1. `nixbuild` の条件移動と boot の重複 OS 判定だけを小さな変更にする。
2. host 判定を一箇所から供給し、必要な module に導入する。
3. Hyprland と AeroSpace/Rift など代表例に `scopedModule` を適用し、disabled/always の意味も確認する。採算が合えば残りを移す。
4. window manager selector は別の interface 変更として扱い、全 rice と旧 bool override の移行をまとめて行う。

最小評価には `flake.lock` の denix と、その `nixpkgs-lib` input [`02e72200e6d56494f4a7c0da8118760736e41b60`](https://github.com/nix-community/nixpkgs.lib/tree/02e72200e6d56494f4a7c0da8118760736e41b60) を取得し、`lib.evalModules` と denix の `module.nix` / `apply.nix` を使用した。実験用ファイルは一時ディレクトリに置き、ホスト構成は評価しなかった。

| 直接実験 | 結果 | 確認した範囲 |
| --- | --- | --- |
| 現行 nixbuild と条件を移動した一時コピー | 4ケース一致 | NixOS/Darwin × enable true/false の `nix`・`programs` 出力。pkgs は OS 判定だけを持つ最小 stub。 |
| 手動 guard と wrapper の寄与の比較 | 12ケース一致 | NixOS/Darwin × enable true/false/optionなし × scope true/false。callback の cfg、always、ifDisabled、option 宣言維持、統合 home routing を確認。 |
| false default と追加 guard の違い | 反例成立 | scope=false で手動 enable=true にすると、guard を削除した版だけ home 設定が出た。 |

これらは小さな interface の意味に関する実験で、denix extension の flake 組込み、実際の Home Manager option schema、全 module の前後等価性、activation の実行を保証しない。実装時は同じ条件 matrix に代表 module の実出力を加える。特に server・WSL、Linux desktop、Darwin 各 rice、明示 enable override を含める。全システム評価・host build・switch は明示依頼があった場合にリポジトリ規則の `nix flake check --all-systems --no-build` / `nh` を使う。現時点では調査を終えた段階で、上記 interface の導入は未実施。

## その他の運用候補

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

- **Denix / rice の基本境界**: こちらの [AGENTS.md](../../AGENTS.md) と既存 rice は既に自動発見・feature module 配置・`myconfig` 選択を使うため、外部設計文書の全文移植は重複する。一方、上記の backend selector と scope interface は現行にない具体的な整理候補である。共有設定の最終 writer は、実際に複数 feature が同じ対象に寄与する場合に局所導入する。
- **AquaSKK / HIToolbox 集約**: 外部の [AquaSKK module](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/modules/programs/aquaskk/default.nix) は [input-methods](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/modules/system/input-methods.nix) に配列要素を寄せ、AquaSKK 固有の [plist 起動問題](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/modules/programs/aquaskk/README.md) を扱う。こちらの [azooKey module](../../modules/azookey/default.nix) が現在の入力ソース配列をまとめて管理する。複数 IME を併用する要件が出るまでは集約インターフェースを増やさず、AquaSKK の復旧手順も取り込まない。
- **host tier**: 外部の [tier schema](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/flake.nix)、[比較 helper](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/modules/config/host-tier.nix)、[説明](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/docs/host-tiers.md) は手動ラベルを示す。こちらは [host ごとの構成](../../flake.nix) と feature 選択で足りている。能力差が同じ複数 module の既定値に反復して現れた場合に検討する。
- **色 registry**: 外部の [colorschemes](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/modules/config/colorschemes/default.nix#L34-L89) は scheme/variant の選択と palette の共有を型付きで扱う。こちらの [theme](../../modules/theme/default.nix) は既に複数アプリの色を集約するが、[AeroSpace rice](../../rices/darwin/aerospace.nix) はアプリ固有の透明度・gradient も選ぶ。共通 palette を複数アプリへ繰り返し展開する要求が増えたら有用で、現在値を固定 palette に押し込む導入は勧めない。
- **大きな検証 runner / 契約 suite**: 外部は [`check-full`](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/checks/full-validation.sh)、[configuration contracts](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/checks/configuration-contracts.nu)、[検証方針](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/docs/nix-validation.md) を持つ。こちらは [flake checks](../../flake.nix) と feature ごとの artifact tests を既に持ち、[作業規則](../../AGENTS.md) は依頼なしの CI 型 Nix 検証・build/switch を禁じる。外部の複数 platform build や standalone Home Manager activation を伴う runner は採用しない。特定の生成物に評価だけでは観測できない不具合が出た場合、消費者の検査をその feature のテストへ小さく加える。
- **TCC 安定配置**: 外部の [tcc-stable-binaries](https://github.com/glassesneo/dotfiles/blob/38534df75a90579ee92bae5a75b10391bec2f5a6/modules/system/tcc-stable-binaries.nix) は Nix store の実行ファイルを安定した場所へコピーする仕組み。こちらの [Kanata](../../modules/kanata/default.nix) も既に公式 binary と `/usr/local/bin/kanata` の安定配置、管理 marker による上書き保護を持ち、[macOS Homebrew 管理](../../modules/darwin-homebrew/default.nix) も使う。複数 feature に同じ配置要求が現れるまでは共通抽象化を増やさない。

## 確認範囲と限界

外部の `README.org`、`flake.nix`、主要な設計・運用 docs、`checks/` の実コード、window-manager、launcher、colorscheme、AquaSKK、input-methods、tier、rice、Rift/SketchyBar、TCC module を上記コミットで読んだ。ローカルの README、flake、関連 module・script、固定版 denix の実装と照合した。走査による集計と上記の最小 module 評価を行い、調査文書のリンク・diff を直接検査した。全ファイルの意味監査、実機の macOS/Rift 動作、secret の復号、全 host の Nix 評価・build・switch、CI 実行はしていない。「条件付き」候補は実障害や効果を確認した結論ではない。
