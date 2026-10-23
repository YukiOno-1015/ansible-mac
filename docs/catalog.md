# 導入対象カタログ

ansible-mac が導入・管理する対象の一覧です。

| 項目 | 内容 |
| --- | --- |
| 最終更新 | 2026-10-24（`main` @ `a5e36ad` 時点） |
| 正本 | 各 YAML（`group_vars/all.yml` / `vars/dev.yml` / `vars/personal.yml` / `roles/*/defaults/main.yml`） |

> **この文書は YAML の写しです。** 値が食い違う場合は YAML が正です。件数は
> `ansible-playbook` で変数を展開した実効値（共通 / `dev` / `personal`）を数えたものです。
> 版数（FileZilla / Pleiades）は自動更新の対象なので、この文書には書きません。`group_vars/all.yml` を参照してください。

## 件数サマリ

| 種別 | 共通のみ（プロファイル未指定） | `dev` | `personal` |
| --- | --- | --- | --- |
| Homebrew formula | 21 | 38（共通 21 + 追加 17） | 21（追加なし） |
| Homebrew cask | 24 | 28（共通 24 + 追加 4） | 27（共通 24 + 追加 3） |
| Mac App Store アプリ | 4 | 8（共通 4 + 追加 4） | 6（共通 4 + 追加 2） |
| Xcode 依存 formula | 0 | 1 | 0 |
| Pleiades の取得 | しない | する | しない |
| FileZilla の取得 | する | する | する |
| MCP サーバ登録 | 11 | 11 | 11 |
| npm グローバル / uv ツール | `make npm` / `make uv` で個別導入 | `make dev` で導入（6 / 1） | 導入しない |

「共通のみ」は、`make homebrew` のようにプロファイルを渡さない部分実行ターゲットが見る状態です
（[detailed-design.md](detailed-design.md) の「プロファイルと部分実行」を参照）。

## 1. Homebrew

### 1.1 tap

| tap | 用途 |
| --- | --- |
| `hashicorp/tap` | HashiCorp 製 CLI（`vault`、`packer`）。Homebrew core から外れたため tap 経由で導入 |

`homebrew/cask-fonts` は `group_vars/all.yml` でコメントアウトされています（導入していません）。

### 1.2 formula（共通 21）

`dev` / `personal` のどちらにも入ります（`homebrew_packages_common`）。

| formula | 用途 |
| --- | --- |
| `bat` | `cat` の代替（シンタックスハイライト付き） |
| `eza` | `ls` の代替 |
| `ripgrep` | 高速 grep |
| `tree` | ディレクトリツリー表示 |
| `vim` | テキストエディタ |
| `wget` | ファイルダウンロード |
| `curl` | HTTP クライアント |
| `dos2unix` | 改行コード変換 |
| `macmon` | Mac のリソースモニタ |
| `osx-cpu-temp` | CPU 温度モニタ |
| `telnet` | Telnet クライアント |
| `ffmpeg` | 動画・音声変換 |
| `yt-dlp` | 動画ダウンロード |
| `ansible` | 構成管理（この環境を反映するため） |
| `git` | バージョン管理 |
| `hashicorp/tap/vault` | Vault CLI（dotfiles の秘密情報復元で使用） |
| `mas` | Mac App Store CLI（`mas` role が使用） |
| `node` | Node.js ランタイム（`npx` 系 MCP サーバが使用） |
| `nodenv` | Node.js バージョン管理 |
| `jenv` | Java バージョン管理 |
| `uv` | Python パッケージマネージャ（`uvx` 系 MCP サーバが使用） |

### 1.3 formula（`dev` 追加 17）

`vars/dev.yml` の `homebrew_packages_dev_extra` です。

| 分類 | formula | 用途 |
| --- | --- | --- |
| GitHub Actions / CI | `act` | GitHub Actions をローカル実行 |
| | `actionlint` | GitHub Actions の lint |
| | `gh` | GitHub CLI |
| クラウド / k8s / IaC | `argocd` | ArgoCD CLI |
| | `helm` | Kubernetes パッケージマネージャ |
| | `packer` | イメージビルドツール（`hashicorp/tap`） |
| | `tenv` | Terraform / OpenTofu バージョン管理 |
| ビルド / 言語 | `automake` | ビルドツール |
| | `cmake` | ビルドシステム |
| | `go` | Go 言語 |
| | `maven` | Java ビルドツール |
| DB / ネットワーク | `mysql-client` | MySQL クライアント |
| | `nmap` | ネットワークスキャナ |
| フォーマッタ | `shfmt` | シェルスクリプトのフォーマッタ（CI と同じ流儀で整形するため） |
| | `swiftformat` | Swift コードのフォーマッタ |
| iOS / Xcode | `xcodegen` | Xcode プロジェクト生成 |
| 監視 | `zabbix` | 監視エージェント |

### 1.4 Xcode 依存 formula

`xcode_homebrew_packages` です。`/Applications/Xcode.app` が存在するときだけ導入します（`xcode` role）。

| プロファイル | formula | 用途 |
| --- | --- | --- |
| `dev` | `swiftlint` | Swift の lint |
| `personal` / 共通のみ | なし | |

### 1.5 Java（OpenJDK）

`homebrew_java_packages` です。導入後に `jenv add` で登録します。

| formula | 備考 |
| --- | --- |
| `openjdk` | 最新の OpenJDK |
| `openjdk@8` | **Intel Mac（`ansible_architecture == 'x86_64'`）のみ**。Apple Silicon では対象から外れる |
| `openjdk@11` | |
| `openjdk@17` | |
| `openjdk@21` | |

登録パスは `<brew --prefix>/opt/<formula>/libexec/openjdk.jdk/Contents/Home` です。
シェルで `jenv` を有効化する設定は dotfiles 側にあります。

### 1.6 cask（共通 24）

`homebrew_casks_common` です。

| 分類 | cask | 用途 |
| --- | --- | --- |
| エディタ | `visual-studio-code` | エディタ（この環境を反映するため） |
| ターミナル | `wezterm@nightly` | ターミナル（iTerm2 は廃止し wezterm に移行済み） |
| ブラウザ | `google-chrome` | ブラウザ |
| ユーティリティ | `qview` | 画像ビューア |
| | `vlc` | メディアプレイヤー |
| Microsoft 365 | `microsoft-word` / `microsoft-excel` / `microsoft-powerpoint` | Office アプリ |
| | `microsoft-outlook` / `microsoft-onenote` / `microsoft-teams` | メール / ノート / 会議 |
| | `onedrive` | クラウドストレージ |
| コミュニケーション | `discord` / `slack` | チャット |
| AI アシスタント | `claude` | Claude デスクトップ（GUI） |
| | `claude-code` | Claude Code（CLI）。`mcp` role が `claude` コマンドを使う |
| | `chatgpt` | ChatGPT デスクトップ（GUI） |
| | `codex` | OpenAI Codex（CLI） |
| | `github-copilot-for-xcode` | GitHub Copilot（GUI / Xcode 拡張） |
| | `copilot-cli` | GitHub Copilot CLI |
| フォント | `font-hack-nerd-font` / `font-hackgen` / `font-hackgen-nerd` / `font-jetbrains-mono` | Nerd Font / HackGen / JetBrains Mono |

### 1.7 cask（プロファイル追加）

| プロファイル | cask | 用途 |
| --- | --- | --- |
| `dev`（4） | `docker` | Docker CLI |
| | `docker-desktop` | Docker Desktop |
| | `postman` | API クライアント |
| | `sourcetree` | Git GUI クライアント |
| `personal`（3） | `thunderbird` | メールクライアント |
| | `webex` | ビデオ会議 |
| | `webex-meetings` | ビデオ会議 |

pkg ベースの cask（Microsoft Office、`docker-desktop`、`webex-meetings` など）は、インストール中に
内部で `sudo` を呼びます。このため実行開始時に macOS ログインパスワードを尋ね、askpass 経由で渡します
（[basic-design.md](basic-design.md) の「権限・セキュリティ設計」を参照）。

## 2. Mac App Store アプリ

`mas_apps_common` と、プロファイルごとの `mas_apps_*_extra` です。`mas get <id>` で無料アプリを取得します。

| アプリ | App Store ID | 共通 | `dev` | `personal` |
| --- | --- | --- | --- | --- |
| LanguageTranslator | 1218781096 | ✅ | ✅ | ✅ |
| Tailscale | 1475387142 | ✅ | ✅ | ✅ |
| Windows App | 1295203466 | ✅ | ✅ | ✅ |
| WireGuard | 1451685025 | ✅ | ✅ | ✅ |
| Developer | 640199958 | | ✅ | |
| PL2303Serial | 1624835354 | | ✅ | |
| TestFlight | 899247664 | | ✅ | |
| Xcode | 497799835 | | ✅ | |
| Kindle | 302584613 | | | ✅ |
| LINE | 539883307 | | | ✅ |

## 3. Homebrew で提供されないアプリ（ダウンロードのみ）

社内 Nexus（`raw-tools`）から `~/Downloads` へ取得します。**インストールは手作業**です（DMG / アーカイブを展開して配置）。
取得元の更新と、版数の追従は [basic-design.md](basic-design.md) の「CI/CD 設計」を参照してください。

| アプリ | 取得するファイル | Nexus 上のパス | 対象 |
| --- | --- | --- | --- |
| Pleiades All in One（Java / Mac） | `pleiades-<release>-java-mac-jre_<buildDate>.dmg` | `raw-tools/eclipse/<release>/` | `dev` のみ（`pleiades_enabled`） |
| FileZilla クライアント（Apple Silicon） | `FileZilla_<version>_macos-arm64.app.tar.bz2` | `raw-tools/filezilla/<version>/` | 共通（`filezilla_enabled`） |

## 4. npm グローバルパッケージ / uv ツール

`Makefile` の `NPM_PACKAGES` / `UV_TOOLS` です。`make dev` の最後に `make npm` → `make uv` が走ります（`make personal` では走りません）。

| 種別 | 対象 |
| --- | --- |
| npm（`npm install -g`） | `@github/copilot`, `@redocly/cli`, `mcp-proxy`, `multi-file-swagger`, `pnpm`, `yarn` |
| uv（`uv tool install`） | `serena-agent` |

## 5. Claude Code の MCP サーバ（11）

`roles/mcp/defaults/main.yml` の `mcp_servers` です。`claude mcp add-json <name> <json> --scope user` で登録します。
登録済みのサーバは更新しません（未登録分のみ追加）。

| 名前 | 方式 | 起動 | 前提 |
| --- | --- | --- | --- |
| `context7` | http | `https://mcp.context7.com/mcp` | ネットワーク |
| `github` | stdio | `docker run -i --rm -e GITHUB_PERSONAL_ACCESS_TOKEN ghcr.io/github/github-mcp-server` | **Docker**（`dev` のみ導入）、`~/.secrets.env` の `GITHUB_PERSONAL_ACCESS_TOKEN` |
| `serena` | stdio | `uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context ide-assistant` | `uv` |
| `playwright` | stdio | `npx -y @playwright/mcp@latest` | Node.js |
| `chrome-devtools` | stdio | `npx -y chrome-devtools-mcp@latest` | Node.js、Chrome |
| `sequential-thinking` | stdio | `npx -y @modelcontextprotocol/server-sequential-thinking` | Node.js |
| `clasp` | stdio | `npx -y @google/clasp mcp` | Node.js |
| `backlog` | stdio | `npx -y backlog-mcp-server`（事前に `~/.secrets.env` を読み込む） | Node.js、`~/.secrets.env` の Backlog 接続情報 |
| `qiita` | stdio | `npx -y @2bo/qiita-mcp-server`（事前に `~/.secrets.env` を読み込む） | Node.js、`~/.secrets.env` の `QIITA_API_TOKEN` |
| `n8n-mcp` | stdio | `npx -y n8n-mcp`（`MCP_MODE=stdio` などを設定し、事前に `~/.secrets.env` を読み込む） | Node.js、`~/.secrets.env` の n8n 接続情報 |
| `linksee` | stdio | `npx -y linksee-memory` | Node.js |

`~/.secrets.env` は dotfiles リポジトリの `--restore-secrets`（Vault から復元）が配置します。
`personal` プロファイルだけが自動で `--restore-secrets` を付けます（[known-issues.md](known-issues.md) の KI-08、KI-09 を参照）。

## 6. 管理対象の設定

### 6.1 macOS 設定（`macos` role）

| 設定 | domain / key | 型 | 変数 | 既定値 |
| --- | --- | --- | --- | --- |
| 隠しファイルを表示 | `com.apple.finder` / `AppleShowAllFiles` | bool | `macos_show_hidden_files` | `true` |
| 拡張子を常に表示 | `NSGlobalDomain` / `AppleShowAllExtensions` | bool | `macos_show_all_filename_extensions` | `true` |
| 自動修正 | `NSGlobalDomain` / `NSAutomaticSpellingCorrectionEnabled` | bool | `macos_disable_auto_correct`（`true` で自動修正を無効化） | `true` |
| キーリピート速度 | `NSGlobalDomain` / `KeyRepeat` | int | `macos_key_repeat_rate` | `2` |
| キーリピート開始までの遅延 | `NSGlobalDomain` / `InitialKeyRepeat` | int | `macos_key_repeat_delay` | `15` |
| Dock の自動非表示 | `com.apple.dock` / `autohide` | bool | `macos_dock_autohide` | `true` |
| Dock のアイコンサイズ | `com.apple.dock` / `tilesize` | int | `macos_dock_icon_size` | `48` |
| スクリーンショット保存先 | `com.apple.screencapture` / `location` | string | `macos_screenshots_dir` | `~/Desktop/screenshots` |

### 6.2 ホスト名

`ComputerName` / `HostName` / `LocalHostName` を、`<デバイス名><用途名><シリアル>` から生成した同一の値に設定します。
アルゴリズムは [detailed-design.md](detailed-design.md) の `macos` role を参照してください。

| プロファイル | 用途名 | 生成例 |
| --- | --- | --- |
| `dev` | `DEV` | `MACBDEV<シリアル>` |
| `personal` | `OA` | `MACBOA<シリアル>` |
| 未指定 | （空） | `MACB<シリアル>` |

### 6.3 `/etc/hosts`

`macos_internal_dns_entries` の FQDN を `macos_internal_dns_vip` に向ける次のブロックを管理します（`sudo` が必要）。

```text
# BEGIN ANSIBLE MANAGED: internal sk4869.info
<macos_internal_dns_vip>  nexus-cli.sk4869.info
<macos_internal_dns_vip>  nexus-docker.sk4869.info
# END ANSIBLE MANAGED: internal sk4869.info
```

VIP の値は `roles/macos/defaults/main.yml` を参照してください。

### 6.4 Git グローバル設定（`git` role）

| 設定 | 変数 | 既定値 | 備考 |
| --- | --- | --- | --- |
| `user.name` | `git_user_name` | `group_vars/all.yml` を参照 | 空文字なら設定しない |
| `user.email` | `git_user_email` | `group_vars/all.yml` を参照 | 空文字なら設定しない |
| `init.defaultBranch` | `git_default_branch` | `main` | |
| `core.editor` | `git_core_editor` | `vim` | |

### 6.5 dotfiles

| 変数 | 既定値 | 備考 |
| --- | --- | --- |
| `dotfiles_repo` | `https://github.com/YukiOno-1015/dotfiles.git` | |
| `dotfiles_dest` | `~/dotfiles` | |
| `dotfiles_version` | `main` | ブランチ / タグ / コミット |
| `dotfiles_update` | `true` | 既存 clone を更新する |
| `dotfiles_install_command` | `./install.sh`（`personal` は `./install.sh --restore-secrets`） | 空文字なら実行しない |

## 7. アプリ設定の取り込み対象（`make import-settings`）

`scripts/import-app-settings.sh` が現環境の設定を `~/dotfiles/home/...` へコピーします。
パスワード DB・証明書 DB・メール本体・VS Code の `globalStorage` など、秘密情報や巨大な生成物は取り込みません。

| アプリ | 取り込む対象 |
| --- | --- |
| VS Code | `settings.json`, `keybindings.json`, `tasks.json`, `snippets/`, `prompts/` |
| Thunderbird | `profiles.ini`, `installs.ini`、各 `*.default*` プロファイルの `prefs.js`, `handlers.json`, `xulstore.json` |
| FileZilla | `~/.config/filezilla/`, `org.filezilla-project.filezilla.plist` |
| Eclipse / Pleiades | `setup-pleiades/Preferences`、`~/Library/Preferences/` 直下の `*eclipse*` |
