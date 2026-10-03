# brew-nix の段階導入

2026-10-03。ユーザーが通常のGUIアプリから移行する方針を選択したため、最初に Insomnia と Notion の設定を brew-nix へ移し、追加依頼に基づいて **18アプリ**まで拡大した。全 Cask の置換は行わない。

## 追加移行

[app manifest](../../modules/brew-casks/files/apps.json) を選択の正本とし、packageテストも同じmanifestを使う。従来の `fullDesktop` 条件は維持した。

| 条件 | Nix管理へ移したアプリ |
| --- | --- |
| Darwin desktop | Blender、Claude、ChatGPT、Cursor、Ghostty、Insomnia、Markdown Preview、Notion、Raycast、Dia、Zed、Zen |
| 上記＋fullDesktop | DB Browser for SQLite、Discord、Obsidian、Palmier Pro、Slack、Visual Studio Code |

Cursorの `cursor`、Markdown Previewの `mdp`、Zedの `zed`、Obsidianの `obsidian`、VS Codeの `code` / `code-tunnel` 等は、同じapp内の実行ファイルへリンクして維持した。Blender/ZenはHomebrewのcommand wrapperと同じく絶対パスへexecするwrapperを使う。Zenはsymlink経由の起動でXPCOMをロードできないことを実CLI検査で検出し、wrapper経由ではversion出力を確認した。

CLIは `~/.local/bin` にHome Managerで配線し、残存Homebrew版より優先する。対象9パスは追加前に不在を確認した。RaycastのGhostty起動scriptも、Nix版のHome Manager app pathが存在すればそれを明示的に開く。

Ghosttyのmanページとbash/zsh/fish補完、Zedのbash/zsh/fish/PowerShell補完もNix出力に含める。brew-nixの独自install phaseが `postInstall` hookを実行しないため、追加のlink処理はinstall phaseへ組み込む。Zedの補完生成を本体のfixup前に実行するとmacOSで後続chmodが失敗したため、完成済み本体から生成する別derivationに分けた。signed bundleの内容やhost security controlは変更していない。

18アプリの直接package buildと署名検証が成功した。7 CLI（Blender、Cursor、Ghostty、Zed、Zen、code、code-tunnel）のversion出力、CLI link/wrapper、補完・manファイルも検査した。GUI起動、内蔵updater、ログイン、Blenderのcache書込みは未検証。host build/switch・既存Homebrew版の削除は実行していない。

## Git source の追加漏れの修復

前回の変更で新規extensionを未追跡のまま残し、ユーザーのDarwin buildが `extensions/module-scope is not tracked by Git` で失敗した。Git経由のflake sourceでファイル不在を再現し、全新規sourceをGitに追加して同じ検査の成功を確認した。その後 `macbook-rift` の `system.build.toplevel.drvPath` が評価できた。commit `3d6f2da` に前回の実装を確定した。

再発確認用の直接検査:

```sh
nix eval --impure --json --file extensions/module-scope/tests/git-source.nix
```

これはGitに含まれるcritical sourceの存在確認であり、Gitのdirty状態だけをエラーにする検査ではない。

## 実装と確認結果

- `flake.nix` に `brew-nix` と別の非flake input `brew-api` を追加した。既存の input の lock は変更していない。固定版は [brew-nix `d058f7ec`](https://github.com/BatteredBunny/brew-nix/tree/d058f7ec3bdb325000a5c305f03020c621612bea)、[brew-api `1276d8a`](https://github.com/BatteredBunny/brew-api/tree/1276d8a7470cbe273056ee9cd070d6ff88d36b0d)。
- [brew-nix の overlay](https://github.com/BatteredBunny/brew-nix/blob/d058f7ec3bdb325000a5c305f03020c621612bea/flake.nix#L40-L50) を `modules/brew-casks/default.nix` の Darwin 出力で導入し、統合 Home Manager の `home.packages` に2アプリを追加した。対応する `homebrew.casks` の宣言を外した。
- 初期の個別package検査は `lock.nodes.nixpkgs` を直接参照しており、実際のroot inputとは異なる古い入力を使っていた。検査を `lock.nodes.root.inputs.nixpkgs` 経由に修正した。実際の固定入力は [`4975466d`](https://github.com/NixOS/nixpkgs/tree/4975466d324710c576dc11ad614684e6bd8cad8e)、7zipは26.02。初期検査の7zip 25向け互換処理は不要だったので削除した。flake.lockの既存入力は更新していない。
- 全18アプリを実際のroot inputでビルドし、`configuration.nix-test` でDarwin構成に入る各derivationとの一致、CLI sourceと補完packageの一致を確認した。初回2アプリの検査だけで稼働構成まで検証したという扱いにはしない。

| アプリ | Cask の download SHA256 | 配置する bundle |
| --- | --- | --- |
| Insomnia 13.3.0 | `11c1b222bfa1d9203292cbedd2b142f00aae3b3b5702fbed738cdc0db1cf582f` | `Insomnia.app` |
| Notion 7.36.1 | `e005dd414bb020f1ff2914fab662c21aa43d063824c40f039b364b04a7dfb759` | `Notion.app` |

これはGUIアプリの直接artifact testであり、host build・全システム評価・switchは行っていない。アプリの起動、ログイン、内蔵updater、Spotlightによる発見は未検証。macOSの稼働構成と既存Homebrewコピーはまだ変更していない。

## brew-nix が担う範囲

[公式README](https://github.com/BatteredBunny/brew-nix/blob/d058f7ec3bdb325000a5c305f03020c621612bea/README.md#setup) と実装を確認した。brew-nix は Cask メタデータから Nix derivation を生成する独立inputで、nixpkgsへのoverlayとして `pkgs.brewCasks.<token>` を公開する。対象アプリはHomebrewでのインストールを必要としない。データは別の `brew-api` inputで固定し、更新するときはそのlockも更新する。

このrepoのHomebrew全体は引き続き必要。formula、Mac App Store、独自tapのCask、既存の `/Applications` / `/opt/homebrew` への連携が残る。[nix-homebrew](https://github.com/zhaofengli/nix-homebrew) はHomebrew本体とtapの管理が目的で、CaskをNix derivationにするbrew-nixとは役割が異なる。

## Homebrewに残す対象

固定版の [Cask parser](https://github.com/BatteredBunny/brew-nix/blob/d058f7ec3bdb325000a5c305f03020c621612bea/casks.nix#L47-L78) と [install処理](https://github.com/BatteredBunny/brew-nix/blob/d058f7ec3bdb325000a5c305f03020c621612bea/casks.nix#L160-L216) から、次の制約を確認した。

| 対象 | 今回の扱い | 理由 |
| --- | --- | --- |
| fonts | Homebrew維持 | 固定版parserに `font` artifact の導入処理がない。 |
| azooKey / Karabiner / Tailscale / Office | Homebrew維持 | PKG・driver・独自tap等の導入処理が必要。PKG payloadの展開だけではInstaller scriptやサービス登録を再現しない。 |
| Docker / Wireshark / qutebrowser | Homebrew維持 | helper、追加installer、Gatekeeper特例等を個別確認する必要がある。 |
| AeroSpace / boringNotch | Homebrew維持 | 現行は独自tapと固定アプリパスに依存する。公式APIの別tokenを同じ設定として扱わない。 |
| Chrome / Spotify / Steam | Homebrew維持 | 固定APIのhashが `no_check` で、ダウンロードURLも可変。今回の固定hashによる移行対象に含めない。 |
| codex Cask | Homebrew維持 | このtokenはGUIではなくCLI配布と補完生成。今回のGUI移行とは分ける。 |

InsomniaとNotionはインストールartifactが通常の `app`。`zap` / `uninstall` メタデータも含むが、brew-nixはその処理を実行しない。アプリデータを削除する操作は追加していない。hashが `no_check` のCaskは別途固定hashを与える必要があり、今回の2件はhashがあるものを選んだ。

## activation と後片付け

固定版 [nix-darwin の Homebrew option](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/homebrew.nix#L71-L98) の `cleanup = "check"` は、Brewfile外のインストール済みpackageがあるとactivation全体を中断する。移行対象Caskの宣言を先に外すと既存コピーが該当するので、移行中は `cleanup = "none"` とした。これは移行対象以外のBrewfile外packageも許容する変更で、既存コピーを自動削除する設定ではない。

固定版 [Home Manager の app linking](https://github.com/nix-community/home-manager/blob/7e3645c737e803fcc98e27bc99c5835c700836f2/modules/targets/darwin/linkapps.nix#L12-L43) と現在の `home.stateVersion = "25.05"` では、Nix版は `~/Applications/Home Manager Apps` に配置される。Homebrew版の `/Applications/Insomnia.app` / `/Applications/Notion.app` とは別の場所になる。

稼働移行は次の順序で行う。build/switch、アプリ削除はこの調査・設定変更では実行していない。

1. 新規NixファイルをGitのflake sourceに含めた上で、依頼された場合にDarwin構成を検証する。現在のriceを `dotfiles doctor --no-eval` で解決し、同時build/switchがないことを確認してから、明示された `nh darwin build` / `switch` を行う。
2. Nix版の明示的なbundle pathから起動して、ログイン・データ・更新挙動・Dock/Spotlightを確認する。同名のHomebrew版と取り違えない。
3. 移行対象アプリの導入元・実行状態を確認し、削除を依頼された場合に対象Caskだけを通常のuninstallで整理する。`--zap` や全体cleanupは使わない。
4. Brewfile外のpackageをread-onlyで再確認し、移行が終わってから `cleanup = "check"` を戻す。追加のGUIアプリは同じ手順で個別に検証する。

## 直接検査

```sh
nix eval --impure --json --file modules/brew-casks/tests/default.nix-test
nix eval --impure --json --file modules/brew-casks/tests/configuration.nix-test
nix build --impure --no-link --json --file modules/brew-casks/tests/packages.nix-test insomnia notion
```

最初の検査は固定Caskのhash、インストールartifact、bundle名、derivation生成とinputのfollowsを確認する。後者は対象アプリだけをビルドし、稼働構成を変更しない。

全対象を検査する場合はmanifestのアプリ名と `zed-completions` をpackage buildへ渡し、evalのJSONとbuildのJSONを次へ渡す:

```sh
python3 modules/brew-casks/tests/verify_builds.py /path/to/metadata.json /path/to/build-results.json
```
