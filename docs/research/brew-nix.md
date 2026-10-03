# brew-nix の段階導入

2026-10-03。ユーザーが通常のGUIアプリから移行する方針を選択したため、最初に **Insomnia と Notion** の設定を brew-nix へ移した。全 Cask の置換は行わない。

## 実装と確認結果

- `flake.nix` に `brew-nix` と別の非flake input `brew-api` を追加した。既存の input の lock は変更していない。固定版は [brew-nix `d058f7ec`](https://github.com/BatteredBunny/brew-nix/tree/d058f7ec3bdb325000a5c305f03020c621612bea)、[brew-api `1276d8a`](https://github.com/BatteredBunny/brew-api/tree/1276d8a7470cbe273056ee9cd070d6ff88d36b0d)。
- [brew-nix の overlay](https://github.com/BatteredBunny/brew-nix/blob/d058f7ec3bdb325000a5c305f03020c621612bea/flake.nix#L40-L50) を `modules/brew-casks/default.nix` の Darwin 出力で導入し、統合 Home Manager の `home.packages` に2アプリを追加した。対応する `homebrew.casks` の宣言を外した。
- 固定 nixpkgs の7zipは25.00。brew-nix の [DMG 展開処理](https://github.com/BatteredBunny/brew-nix/blob/d058f7ec3bdb325000a5c305f03020c621612bea/casks.nix#L108-L121) にある `-snld20` はこの版では受け付けられず、最初の実ビルドが失敗した。`packages/brew-cask.nix` は7zipが26未満の場合だけその引数を省く。nixpkgs全体を更新する必要はなかった。
- 互換処理後、**Insomnia 13.3.0 / Notion 7.36.1 の両パッケージを実ビルドできた**。双方で `codesign --verify --deep --strict` が成功し、Info.plist の bundle ID・version と実行ファイルの存在を確認した。

| アプリ | Cask の download SHA256 | 配置する bundle |
| --- | --- | --- |
| Insomnia 13.3.0 | `11c1b222bfa1d9203292cbedd2b142f00aae3b3b5702fbed738cdc0db1cf582f` | `Insomnia.app` |
| Notion 7.36.1 | `e005dd414bb020f1ff2914fab662c21aa43d063824c40f039b364b04a7dfb759` | `Notion.app` |

これはGUIアプリの直接artifact testであり、host build・全システム評価・switchは行っていない。アプリの起動、ログイン、内蔵updater、Spotlightによる発見は未検証。macOSの稼働構成と既存Homebrewコピーはまだ変更していない。

## brew-nix が担う範囲

[公式README](https://github.com/BatteredBunny/brew-nix/blob/d058f7ec3bdb325000a5c305f03020c621612bea/README.md#setup) と実装を確認した。brew-nix は Cask メタデータから Nix derivation を生成する独立inputで、nixpkgsへのoverlayとして `pkgs.brewCasks.<token>` を公開する。対象アプリはHomebrewでのインストールを必要としない。データは別の `brew-api` inputで固定し、更新するときはそのlockも更新する。

このrepoのHomebrew全体は引き続き必要。formula、Mac App Store、独自tapのCask、既存の `/Applications` / `/opt/homebrew` への連携が残る。[nix-homebrew](https://github.com/zhaofengli/nix-homebrew) はHomebrew本体とtapの管理が目的で、CaskをNix derivationにするbrew-nixとは役割が異なる。

## 残す対象と次の候補

固定版の [Cask parser](https://github.com/BatteredBunny/brew-nix/blob/d058f7ec3bdb325000a5c305f03020c621612bea/casks.nix#L47-L78) と [install処理](https://github.com/BatteredBunny/brew-nix/blob/d058f7ec3bdb325000a5c305f03020c621612bea/casks.nix#L160-L216) から、次の制約を確認した。

| 対象 | 今回の扱い | 理由 |
| --- | --- | --- |
| fonts | Homebrew維持 | 固定版parserに `font` artifact の導入処理がない。 |
| azooKey / Karabiner / Tailscale / Office | Homebrew維持 | PKG・driver・独自tap等の導入処理が必要。PKG payloadの展開だけではInstaller scriptやサービス登録を再現しない。 |
| Docker / Wireshark / qutebrowser | Homebrew維持 | helper、追加installer、Gatekeeper特例等を個別確認する必要がある。 |
| AeroSpace / boringNotch | Homebrew維持 | 現行は独自tapと固定アプリパスに依存する。公式APIの別tokenを同じ設定として扱わない。 |
| Blender / Obsidian | 次の候補 | `.app` は扱えるが、preflightやCLIなど追加artifactの意味も確認する。今回未移行。 |

InsomniaとNotionはインストールartifactが通常の `app`。`zap` / `uninstall` メタデータも含むが、brew-nixはその処理を実行しない。アプリデータを削除する操作は追加していない。hashが `no_check` のCaskは別途固定hashを与える必要があり、今回の2件はhashがあるものを選んだ。

## activation と後片付け

固定版 [nix-darwin の Homebrew option](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/homebrew.nix#L71-L98) の `cleanup = "check"` は、Brewfile外のインストール済みpackageがあるとactivation全体を中断する。2 Caskの宣言だけ先に外すと既存コピーが該当するので、移行中は `cleanup = "none"` とした。これは移行対象以外のBrewfile外packageも許容する変更で、既存コピーを自動削除する設定ではない。

固定版 [Home Manager の app linking](https://github.com/nix-community/home-manager/blob/7e3645c737e803fcc98e27bc99c5835c700836f2/modules/targets/darwin/linkapps.nix#L12-L43) と現在の `home.stateVersion = "25.05"` では、Nix版は `~/Applications/Home Manager Apps` に配置される。Homebrew版の `/Applications/Insomnia.app` / `/Applications/Notion.app` とは別の場所になる。

稼働移行は次の順序で行う。build/switch、アプリ削除はこの調査・設定変更では実行していない。

1. 新規NixファイルをGitのflake sourceに含めた上で、依頼された場合にDarwin構成を検証する。現在のriceを `dotfiles doctor --no-eval` で解決し、同時build/switchがないことを確認してから、明示された `nh darwin build` / `switch` を行う。
2. Nix版の明示的なbundle pathから起動して、ログイン・データ・更新挙動・Dock/Spotlightを確認する。同名のHomebrew版と取り違えない。
3. 既存の2アプリの導入元・実行状態を確認し、削除を依頼された場合にその2 Caskだけを通常のuninstallで整理する。`--zap` や全体cleanupは使わない。
4. Brewfile外のpackageをread-onlyで再確認し、移行が終わってから `cleanup = "check"` を戻す。追加のGUIアプリは同じ手順で個別に検証する。

## 直接検査

```sh
nix eval --impure --json --file modules/brew-casks/tests/default.nix-test
nix build --impure --no-link --json --file modules/brew-casks/tests/packages.nix-test insomnia notion
```

最初の検査は固定Caskのhash、インストールartifact、bundle名、derivation生成とinputのfollowsを確認する。後者は対象アプリだけをビルドし、稼働構成を変更しない。
