# ansible-mac

Ansible を使った Mac セットアップ自動化プロジェクトです。

## 前提条件

- macOS
- [Homebrew](https://brew.sh/ja/)
- Ansible (`brew install ansible`)

Homebrew / Ansible が未導入の場合は、次のコマンドで前提条件をセットアップできます。

```bash
make init
```

## ディレクトリ構成

```
ansible-mac/
├── Makefile             # エントリーポイント
├── ansible.cfg          # Ansible設定
├── requirements.yml     # Ansible collection 依存関係
├── site.yml             # メインplaybook
├── scripts/
│   └── import-app-settings.sh # 現環境のアプリ設定取り込み
├── inventory/
│   └── localhost        # ローカル実行用インベントリ
├── vars/
│   ├── dev.yml          # 開発用プロファイル（Casks / MAS apps）
│   └── personal.yml     # 普段使い用プロファイル（Casks / MAS apps）
├── group_vars/
│   └── all.yml          # 共通変数（Homebrew packages / Git設定）
└── roles/
    ├── homebrew/        # Homebrewパッケージ・Caskのインストール
    ├── mas/             # Mac App Storeアプリのインストール
    ├── xcode/           # Xcode 依存 Homebrew パッケージのインストール
    ├── pleiades/        # Pleiades All in One DMG の取得
    ├── macos/           # macOSシステム設定
    ├── git/             # Gitグローバル設定
    └── dotfiles/        # dotfiles リポジトリの clone/update と install
```

## セットアップ

### 1. リポジトリをクローン

SSH:

```bash
git clone git@github.com:YukiOno-1015/ansible-mac.git
cd ansible-mac
```

HTTPS:

```bash
git clone https://github.com/YukiOno-1015/ansible-mac.git
cd ansible-mac
```

### 2. 前提条件をセットアップ

```bash
make init
```

### 3. 変数を編集

`group_vars/all.yml` を編集して、インストールするパッケージや設定値をカスタマイズします。

```bash
vim group_vars/all.yml
```

**最低限設定すべき項目:**

```yaml
git_user_name: "Your Name"
git_user_email: "your@email.com"
```

### 4. 実行

プロファイルを選んで実行します。

```bash
make init       # 前提条件（Homebrew / Ansible）をセットアップ
make dev        # 開発用（コミュニケーションツールなし）
make personal   # 普段使い用（全部入り）
```

ドライランで確認してから実行する場合:

```bash
make check-dev
make check-personal
```

特定の対象のみ実行したい場合:

```bash
make homebrew   # Homebrew パッケージのみ
make mas        # App Store アプリのみ
make xcode      # Xcode 依存 Homebrew パッケージのみ
make pleiades   # Pleiades All in One DMG の取得のみ
make macos      # macOS 設定のみ
make git        # Git 設定のみ
make dotfiles   # dotfiles の clone/update と install
make import-settings # 現環境のアプリ設定を dotfiles に取り込み
make npm        # npm グローバルパッケージのみ
make uv         # uv ツールのみ
```

## 実行時メモ

### Homebrew Cask で sudo が必要な場合

`docker-desktop` や `webex-meetings` など、一部の cask はインストール中に `sudo` を呼びます。
Ansible 経由では sudo のパスワード入力ができず、次のようなエラーになることがあります。

```text
sudo: a terminal is required to read the password
sudo: a password is required
```

その場合は、先に sudo 認証を通してから再実行します。

```bash
sudo -v
make personal
```

それでも失敗する場合は、該当 cask だけ対話的に入れてから再実行します。

```bash
brew install --cask docker-desktop webex-meetings
make personal
```

### Mac App Store アプリのインストールに失敗する場合

`mas` は App Store へのサインインと、対象アプリが Apple ID の購入済み/入手済みであることが必要です。
次のような空のエラーで落ちる場合は、App Store 側の状態を確認します。

```text
Error running command 'install' on app '<app-id>':
```

確認すること:

- App Store アプリを開いてサインインしていること
- 初回利用規約や支払い情報の確認が残っていないこと
- 対象アプリを一度 App Store GUI で「入手」していること
- `mas account` で Apple ID が表示されること

状態を直したら、`make mas` または `make personal` を再実行します。

## プロファイル

| | 開発用 (`dev`) | 普段使い (`personal`) |
| --- | --- | --- |
| Homebrew packages（CLI/言語） | ✅ | ✅ |
| 開発ツール（IDE/Docker/Git GUI） | ✅ | ✅ |
| コミュニケーション（Discord/Slack など） | ❌ | ✅ |
| エンタメ・一般（Kindle/LINE など） | ❌ | ✅ |
| dotfiles | ✅ | ✅ |
| npm / uv ツール | ✅ | ✅ |

## CI

GitHub Actions で次のチェックを実行します。

| チェック | 内容 |
| --- | --- |
| `yamllint` | YAML のフォーマット・インデントチェック |
| `shfmt` | Shell スクリプトのフォーマットチェック |
| `ansible-lint` | Ansible の静的チェック |
| `ansible-playbook --syntax-check` | Playbook の構文チェック |

## ロール詳細

### pleiades

Pleiades All in One の公式 DMG を `~/Downloads` に取得します。
Homebrew cask では提供されていないため、DMG の取得後に Finder から開いてインストールします。

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `pleiades_enabled` | Pleiades DMG を取得するか | `false` |
| `pleiades_url` | Pleiades All in One DMG の URL | `""` |
| `pleiades_download_dest` | DMG の保存先 | `~/Downloads/pleiades-all-in-one.dmg` |

既定では Pleiades All in One 2025 Java Full Edition for Mac ARM を取得します。
公式ページでは Mac 版 All in One と Pleiades プラグインが提供されています。

FileZilla は現在の Homebrew cask では見つからなかったため、この playbook では自動導入していません。
必要な場合は公式サイトからインストールし、設定だけ `make import-settings` で dotfiles に取り込みます。

### import-settings

現環境のアプリ設定を `~/dotfiles/home/...` に取り込みます。
Thunderbird のパスワード DB、証明書 DB、メール本体、VS Code の `globalStorage` など、秘密情報や巨大な生成物は取り込みません。

```bash
make dotfiles
make import-settings
```

取り込み対象:

| アプリ | 対象 |
| --- | --- |
| VS Code | `settings.json`, `keybindings.json`, `tasks.json`, `snippets/`, `prompts/` |
| Thunderbird | `profiles.ini`, `installs.ini`, `prefs.js`, `handlers.json`, `xulstore.json` |
| FileZilla | `~/.config/filezilla/`, `org.filezilla-project.filezilla.plist` |
| Eclipse / Pleiades | 軽量な Preferences |

### homebrew

Homebrew パッケージ・Cask をインストールします。

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `homebrew_packages` | `brew install` するパッケージ一覧 | `[]` |
| `homebrew_casks` | `brew install --cask` するアプリ一覧 | `[]` |
| `homebrew_taps` | 追加する tap 一覧 | `[]` |
| `homebrew_upgrade_all` | 全パッケージをアップグレードするか | `false` |
| `homebrew_java_packages` | `jenv` に追加する OpenJDK formula 一覧 | `[]` |
| `xcode_homebrew_packages` | Xcode インストール後に `brew install` するパッケージ一覧 | `[]` |

#### Taps

| tap |
| --- |
| `hashicorp/tap` |

#### Packages (`brew install`)

| パッケージ | 用途 |
| --- | --- |
| `act` | GitHub Actions をローカル実行 |
| `actionlint` | GitHub Actions の lint |
| `ansible` | 構成管理ツール |
| `argocd` | ArgoCD CLI |
| `automake` | ビルドツール |
| `bat` | cat の代替（シンタックスハイライト付き） |
| `cmake` | ビルドシステム |
| `curl` | HTTP クライアント |
| `dos2unix` | 改行コード変換 |
| `eza` | ls の代替 |
| `ffmpeg` | 動画・音声変換 |
| `gh` | GitHub CLI |
| `git` | バージョン管理 |
| `go` | Go 言語 |
| `helm` | Kubernetes パッケージマネージャ |
| `jenv` | Java バージョン管理 |
| `macmon` | Mac リソースモニタ |
| `maven` | Java ビルドツール |
| `mysql-client` | MySQL クライアント |
| `nmap` | ネットワークスキャナ |
| `node` | Node.js |
| `nodenv` | Node.js バージョン管理 |
| `osx-cpu-temp` | CPU 温度モニタ |
| `packer` | イメージビルドツール（hashicorp/tap） |
| `ripgrep` | 高速 grep |
| `shfmt` | Shell スクリプトフォーマッタ |
| `swiftformat` | Swift コードフォーマッタ |
| `telnet` | Telnet クライアント |
| `tenv` | Terraform / OpenTofu バージョン管理 |
| `tree` | ディレクトリツリー表示 |
| `vim` | テキストエディタ |
| `wget` | ファイルダウンロード |
| `xcodegen` | Xcode プロジェクト生成 |
| `yt-dlp` | 動画ダウンロード |
| `zabbix` | 監視エージェント |
| `uv` | Python パッケージマネージャ |

#### Java / jenv

Homebrew でインストール可能な OpenJDK formula をまとめてインストールし、`jenv` に追加します。
Apple Silicon では `openjdk@8` が x86_64 専用のため、自動的に対象から外します。
シェルで `jenv` を有効化する設定は dotfiles 側で管理します。

| パッケージ | 用途 |
| --- | --- |
| `openjdk` | 最新の OpenJDK |
| `openjdk@8` | Java 8（Intel Mac のみ） |
| `openjdk@11` | Java 11 |
| `openjdk@17` | Java 17 |
| `openjdk@21` | Java 21 |

#### Xcode dependent packages

`swiftlint` のように Xcode が必要な Homebrew パッケージは、Mac App Store アプリのインストール後に入れます。

| パッケージ | 用途 |
| --- | --- |
| `swiftlint` | Swift lint |

#### Casks (`brew install --cask`)

| アプリ | 用途 |
| --- | --- |
| `claude-code` | Claude Code CLI |
| `visual-studio-code` | エディタ |
| `docker` | Docker CLI |
| `docker-desktop` | Docker Desktop |
| `github-copilot-for-xcode` | Xcode 向け GitHub Copilot |
| `iterm2` | ターミナル |
| `postman` | API クライアント |
| `sourcetree` | Git GUI クライアント |
| `wezterm@nightly` | ターミナル |
| `google-chrome` | ブラウザ |
| `discord` | チャット |
| `slack` | チャット |
| `thunderbird` | メールクライアント |
| `webex` | ビデオ会議 |
| `webex-meetings` | ビデオ会議 |
| `qview` | 画像ビューア |
| `vlc` | メディアプレイヤー |
| `font-hack-nerd-font` | Nerd Font |
| `font-hackgen` | HackGen フォント |
| `font-hackgen-nerd` | HackGen Nerd フォント |
| `font-jetbrains-mono` | JetBrains Mono フォント |

### mas

Mac App Store アプリをインストールします。事前に App Store へのサインインが必要です。

| 変数 | 説明 | デフォルト |
| --- | --- | --- |
| `mas_apps` | インストールするアプリの `id` と `name` のリスト | `[]` |

#### App Store アプリ一覧

| アプリ | App Store ID | dev | personal |
| --- | --- | --- | --- |
| Developer | 640199958 | ✅ | ✅ |
| Kindle | 302584613 | ❌ | ✅ |
| LanguageTranslator | 1218781096 | ✅ | ✅ |
| LINE | 539883307 | ❌ | ✅ |
| PL2303Serial | 1624835354 | ✅ | ✅ |
| Tailscale | 1475387142 | ✅ | ✅ |
| TestFlight | 899247664 | ✅ | ✅ |
| Windows App | 1295203466 | ✅ | ✅ |
| WireGuard | 1451685025 | ✅ | ✅ |
| Xcode | 497799835 | ✅ | ✅ |

### macos

macOS のシステム設定を変更します。

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `macos_show_hidden_files` | 隠しファイルを表示する | `true` |
| `macos_show_all_filename_extensions` | 拡張子を常に表示する | `true` |
| `macos_disable_auto_correct` | 自動修正を無効にする | `true` |
| `macos_key_repeat_rate` | キーリピート速度 | `2` |
| `macos_key_repeat_delay` | キーリピートの遅延 | `15` |
| `macos_dock_autohide` | Dock を自動的に隠す | `true` |
| `macos_dock_icon_size` | Dock のアイコンサイズ | `48` |
| `macos_screenshots_dir` | スクリーンショット保存先 | `~/Desktop/screenshots` |
| `macos_hostname_manage` | Mac の ComputerName / HostName / LocalHostName を設定する | `true` |
| `macos_hostname_device_name` | PC 名に使うデバイス名（空なら Mac のモデルから自動判定） | `""` |
| `macos_hostname_purpose` | PC 名に使う用途名（`dev` / `home` など） | `""` |
| `macos_hostname_serial_suffix_length` | PC 名に付けるシリアル末尾の文字数（`0` なら全体） | `0` |

PC 名は `macmini-dev-serial` や `macbook-home-serial` の形式で設定します。
デバイス名は `hw.model` から `macmini` / `macbook` / `imac` / `macstudio` / `macpro` に自動判定します。
`dev` プロファイルでは `dev`、`personal` プロファイルでは `home` を用途名に使います。

### git

Git のグローバル設定を行います。

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `git_user_name` | `user.name` | `""` |
| `git_user_email` | `user.email` | `""` |
| `git_default_branch` | `init.defaultBranch` | `main` |
| `git_core_editor` | `core.editor` | `vim` |

### dotfiles

dotfiles リポジトリを clone/update し、`install.sh` を実行して `home/` 配下の設定ファイルを `$HOME` にシンボリックリンクします。

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `dotfiles_repo` | dotfiles リポジトリ URL | `https://github.com/YukiOno-1015/dotfiles.git` |
| `dotfiles_dest` | clone 先ディレクトリ | `~/dotfiles` |
| `dotfiles_version` | checkout するブランチ / タグ / コミット | `main` |
| `dotfiles_update` | 既存 clone を更新するか | `true` |
| `dotfiles_install_command` | clone 後に実行するコマンド（空なら実行しない） | `./install.sh` |
