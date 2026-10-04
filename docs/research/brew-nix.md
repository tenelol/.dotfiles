# macOS の Homebrew 管理を Nix へ移す

2026-10-04 時点の設定と直接検査。`brew-nix` は Cask メタデータを Nix derivation に変換する。formula、独自tapのバイナリ、署名付きinstaller、Mac App Storeは、それぞれ適した Nix module で扱う。Darwin target の評価で `homebrew.enable = false` を確認した。`macbook-rift` へ `nh darwin switch` を実行し、Docker・Officeの更新を確認した。旧Homebrew実体は個別に整理している。ブラウザーのプロフィール・キャッシュ・暗号化済みKeychainはバックアップし、ユーザーデータを削除する `--zap` は使っていない。

## 管理元と対象

| 管理元 | 宣言 | 対象 |
| --- | ---: | --- |
| [brew-casks の manifest](../../modules/brew-casks/files/apps.json) と [module](../../modules/brew-casks/default.nix) | 26 Cask | immutable GUI 3件、自己更新GUI source 13件、Codex CLI 1、font 9 |
| [darwin-cli](../../modules/darwin-cli/default.nix) | 58 Nix package | 旧formula 54件と Rift、SketchyBar、Borders。Zathura 5 formulaはプラグイン入りwrapper 1件に集約 |
| [darwin-installers](../../modules/darwin-installers/default.nix) | 10 native installer、自己更新GUI 20件、MAS 8件 | azooKey、Karabiner、Tailscale、Wireshark、Docker、Office 4アプリ、通常配置の20 GUI、Microsoft AutoUpdate、Mac App Store アプリ |
| [AeroSpace](../../modules/aerospace/default.nix)、[boringNotch](../../modules/boringnotch/default.nix) | GUI 2件 | nixpkgs の AeroSpace と固定した boringNotch package |

`brew-nix` と `brew-api` は `flake.lock` に固定し、Cask source の再現に使う。実際のroot `nixpkgs` inputは `flake.lock` の `root.inputs.nixpkgs` が指す `nixpkgs_2`（`4975466d324710c576dc11ad614684e6bd8cad8e`）。旧検査は別node `nodes.nixpkgs` を直接読んでいたため修正済み。Caskの `no_check` sourceは固定hashを補い、Material Symbols は固定Git archiveと必要なfontファイルに絞った。

Blender・qutebrowser・DB Browser for SQLiteの3件はHome Managerの `~/Applications/Home Manager Apps` に配置する。ChatGPT（Codexを含む）・ChatGPT Classic・Dia・Claude・Discord・Slackは署名を保持したNix packageから通常の `/Applications` へコピーし、primary userの所有・書込権限で公式updaterを利用する。Nix側のversionは導入時の最低版とし、自己更新された新しい版をswitchで戻さない。Nixへの既存linkやroot所有の通常配置は、現在のversionを保持したユーザー所有のコピーへ置き換える。app data/cache/Keychainのパスは変更しない。ChatGPTの導入元は公開版26.930.41038の公式ZIPとSHA256を固定した。Classicは公式Caskの1.2026.184を使い、`no_check`だった公式DMGに取得済みのSHA256を固定した。

LINEのmacOS公式配布は[Mac App Store](https://guide.line.me/ja/signup/pc-line.html)で、brew-nixのCaskは存在しない。既存のMAS導入確認と通常のapp配置を維持し、既にONだったApp Store自動更新をNixでも宣言した。この自動更新設定はMac App Storeアプリ全体に作用する。通常コピー配置はbrew-nixの自動更新オプションではなく、このrepositoryのinstaller処理による。

ChatGPT終了後も旧版のCrashpad・shortcut monitorが親PID 1で残り、最初の実機activationは稼働判定で停止した。終了後のsnapshotを使う回帰テストで再現し、通常本体・CLI・workerがいない場合だけ、対象bundle内の既知の孤立helperへSIGTERMを送る処理を追加した。本体やworkerが動いている場合は置き換えを止め、実行ファイルとPIDを表示する。アプリを参照するだけのコマンド引数を実プロセスと混同しないため、ChatGPTは実行ファイルのパスで判定する。

app内CLIは `~/.local/bin` に公開し、Ghosttyのman/completionとZedのbash・zsh・fish・PowerShell補完を維持する。fontは `fonts.packages` で宣言する。Codex CaskはGUIではなくCLIとして扱い、completionを別packageから生成する。AeroSpaceは `/Applications/Nix Apps` を使用する。boringNotchは `/Applications/boringNotch.app` へ移す。

CLI formulaの置換では名前だけでなくコマンドも合わせた。Homebrewの `gdrive` はglotlabs v3なので `pkgs.gdrive3`、`cloudflare-wrangler` は `pkgs.wrangler`、`dotnet` はSDK 10、`node` はNode 26を選んだ。`pkgconf` に `pkg-config` のaliasを足し、Rustは `rustc`・`cargo`・`rustfmt`・`clippy` を揃えた。`herdr-bin` はmacOS/Linuxとも公式の固定releaseを使用し、`herdr` source inputとの版一致を確認する。Zathura wrapperはpdf-mupdf、ps、cb、djvuを同梱するため、Homebrew prefixにpluginをリンクするactivationは不要。MySQLは既存の9.7.1に合わせた[Oracle署名済みbinary](../../packages/mysql97.nix)を固定し、`/opt/homebrew/var/mysql` には触れずserverも起動しない。

RiftとPeekabooは固定されたnixpkgsにはないため、[Rift package](../../packages/rift.nix)と[Peekaboo package](../../packages/peekaboo.nix)を公式releaseのURL・SHA256で定義した。Riftは公式0.6.4の配布済みバイナリを使い、公式tap同様にad-hoc再署名し、PeekabooはOpenClawのDeveloper ID署名と同梱Swift libraryを保持する。launchdとworkspace helperの実行パスはNix profile側へ変更した。macOSのAccessibility・Screen Recording権限は新しい実行パスで確認が必要。


## アプリ内更新が可能なGUIへ広げる（2026-10-05）

新しい宣言は既存6件に加え、Cursor・Ghostty・Insomnia・Markdown Preview・Notion・Raycast・Zed・Zen・Chrome・Obsidian・PalmierPro・VS Code・Spotify・boringNotchを通常コピーにする。Dockerのroot所有・書込不可コピーもユーザー所有へ変える。Tailscale・Wireshark・azooKey・Officeは公式PKGの通常配置を保持する。OfficeのMicrosoft AutoUpdateを除外するinstaller choiceを撤去し、署名済みMAU PKGを最低版として宣言する。MAUのapp短縮versionは4.85、receipt/buildは4.85.26091737で別々に照合する。

一次証拠は、[GhosttyのUpdate and Restart](https://ghostty.org/docs/install/release-notes/1-3-0)、[InsomniaのSoftware Updates](https://developer.konghq.com/insomnia/)、[NotionのCheck for Updates](https://www.notion.com/help/notion-for-desktop)、[Zedのauto_update](https://zed.dev/docs/reference/all-settings)、[SpotifyのUpdate Spotify now](https://support.spotify.com/us/article/updating-spotify/)、[OfficeのMicrosoft AutoUpdate](https://support.microsoft.com/en-us/office/lifecycle/officeinstall/update-office-for-mac-automatically)と導入済み署名bundleのupdater実装。Cursor・Insomnia・NotionのSquirrel、Ghostty・Markdown Preview・PalmierPro・boringNotchのSparkle/feed、ChromeのKSUpdateURLを確認した。Raycastの実機メニューにCheck for updatesがあることも確認した。[Chromeの公式手順](https://support.google.com/chrome/answer/95414?hl=en)はAboutから更新する。DarwinのVS Code設定に残っていたupdate.mode=noneもdefaultへ変更する。LinuxのNix管理版はnoneを維持する。

CLIとGhosttyのman/completionは `/Applications` の実体を参照する専用support packageへ分離し、更新後の旧Nix binaryを呼ばない。Zedの生成済み補完は既存のsource packageから再利用する。Home Managerには自己更新GUIのimmutable bundleを二重配置しない。Zenは旧symlinkをresolveしたinstall hashから、将来の通常配置をresolveせず計算したhashへ既存選択profileを引き継ぐ。profiles.ini/installs.iniをbackupし、profile内容・cache・Keychainを移動・削除しない。

boringNotchは旧 `/Applications/Nix Apps` をDarwinが整理する前にcopyする必要がある。preActivationで全件の稼働・署名を先に確認し、この旧linkだけを通常コピーへ移す。postActivationで残りを処理する。新しい自己更新版も次のswitchで保持する。Karabiner 16.0.0とVirtualHIDDevice 6.14.0はKanata互換性のため固定を維持する。

設定と直接artifact testの検証を行った。今回の実機activationの結果は完了後に追記する。GUI本体は既存のNix store成果物を再利用し、生成するのはCLI/support linkとmanifestのみ。MAUは公式署名済みPKGを取得する。

## Installer と Mac App Store

[reconcile.py](../../modules/darwin-installers/files/reconcile.py) は、PKGの署名、appのbundle ID・Team ID・version、receipt、必要なsystem fileを確認する。更新が必要なappが動作中ならpreflightで止める。全件preflightの後でのみinstallerまたはapp copyを実行する。`--plan` はread-onlyの状態一覧を出す。azooKeyの既存導入判定だけは、固定hashの旧Homebrew PKGを移行用の一次証拠として参照する。

Steamはユーザーが不要と指定したためinstaller宣言から外した。旧Caskは通常の `brew uninstall --cask steam` で削除し、`/Applications/Steam.app` と Caskroom のSteam entryがないことを確認した。`--zap` は使わずgame/library dataは削除対象にしていない。Dockerは稼働中コンテナを停止して4.93へ更新し、Desktopを再起動した。停止前に記録した16件のうち再起動後にも存在するMySQL・PostgreSQLの2件は起動を確認した。他14件は存在せず、必要なものは特にないというユーザー回答に沿って再作成していない。volume削除・prune操作は行っていない。Officeも更新対象が稼働中なら同様に止まる。Mac App Storeの8件は `mas list` で確認し、不足があればconsole userに既に所有するアプリの手動installを案内してactivationを止める。購入やApple ID認証は自動化しない。

## 検証と稼働状態

- 58 CLI packageの一括direct artifact buildが成功。代表CLIのversionと、Zathuraのpdf-mupdf・ps・cbなどのplugin検出を確認した。
- 21 GUI Caskのdirect artifact buildと署名検査が成功。Cask metadata、配置、CLI linkとcompletionは直接fixtureで検査した。
- 署名付きinstallerのmetadataとreconcileのunit testを確認した。Darwinのbuild/switchとDocker・Officeのinstaller/app更新を確認した。Nix版Diaは既存プロフィールのDBを開き、保存login record数45件を維持した。ログイン操作とMAS新規導入は未実施。
- 旧Homebrew formula 179件を削除した。最後のChatGPTの旧trackingも除去し、CellarとCaskroomの両方が空であることを確認した。旧GUI本体は通常のCask uninstallで削除し、Dock等の既存パスにはNix版へのlinkを残した。native installerの旧trackingだけを削除し、導入済みdriver/helperは保持した。MySQL dataとapp data/cacheは保持する。
- commit `644db30` の `macbook-rift` activationが成功し、6アプリが通常のユーザー所有コピーになったこと、署名、App Store自動更新ONを確認した。ChatGPTは26.930.41038、Classicは1.2026.184。Diaはその後、公式updaterから1.51.1へ更新・再起動でき、Nix側の判定が `newer` となることも実機確認した。保存login record数は移行前・移行後・公式更新後のいずれも45件だった。
- profile/cache/暗号化済みKeychainのバックアップを保持した。Classicの `group.com.openai.chat` 共有コンテナはmacOSの保護でバックアップを拒否されたため、アクセス権を拡張せずコピー対象から外した。アプリ本体の配置・所有権だけを変更し、この共有コンテナ自体には変更を加えていない。
- Ghosttyはユーザーが作業を保存して終了した後に旧本体を削除し、Nix版1.3.1を起動した。CLIはNix側から解決することを確認し、`llvm-config`にはbinary cache取得済みLLVM 22の開発outputへのlinkを追加した。

直接検査はdenixの自動検出を避ける `.nix-test` を使う。例：

```sh
nix eval --json --file modules/darwin-cli/tests/packages.nix-test
nix eval --impure --json --file modules/brew-casks/tests/default.nix-test
nix eval --impure --json --file modules/brew-casks/tests/configuration.nix-test
python3 -m unittest discover -s modules/darwin-installers/tests
```

稼働移行は、現在のriceを `dotfiles doctor --no-eval` で確定し、他のbuild/switchがないことを確認してから、明示された場合だけrice専用targetで `nh darwin build` または `switch` を行う。たとえばriftなら `nh darwin build . -H macbook-rift`。switch前に動作中appとMAS不足を解消する必要がある。Nix版を起動してデータ・権限・Dock/Spotlightを確認した後、旧Homebrew実体の削除は個別に対象を確定して行う。`brew uninstall --zap` や一括cleanupはこの変更に含めない。

## 前段階の記録

2026-10-03にInsomnia・Notionから始め、通常GUI 18件まで移した。初期のGit sourceに新規 `extensions/module-scope` が未追跡で、Darwin buildが失敗したためsourceを追加し、`macbook-rift` のtop-level導出評価を再確認した（commit `3d6f2da`）。その時点のroot nodeを誤ったpackage testも上記の `root.inputs.nixpkgs` 経由に直した。以前の18件のみの検証と、今回の21件・CLI58件の検証を区別する。

Riftの0.6.0ではscrolling用gestureを有効にすると列操作が優先され、空workspaceからの切替と従来の方向を設定だけで両立できなかった。公式0.6.4のworkspace fallbackとscroll gesture無効の組合せで、ウィンドウ上・空workspace両方の三本指直接切替を実機確認した。[調査記録](./rift-0.6-gestures.md)には旧版ソースとの照合と説明の訂正を残した。
