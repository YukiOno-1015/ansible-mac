# ansible-mac

Ansible を使った Mac セットアップ自動化プロジェクトです。
Homebrew・App Store アプリ・macOS 設定・Git 設定・dotfiles・Claude Code の MCP サーバ登録までを、同じ手順で何度でも再現できます。

- **2 つのプロファイル**: 開発用（`dev`）と普段使い（`personal`）。共通セットに差分を足す構成
- **冪等**: 繰り返し実行しても同じ状態に収束
- **ローカル完結**: `localhost` への自己適用（SSH 不要）。入口は `make`

要件・設計・運用の詳細は **[docs/](docs/README.md)** にまとめています。

## 前提条件

- macOS（Apple Silicon 前提）
- 管理者権限を持つ通常ユーザー（`sudo make ...` は使えません）
- App Store にサインイン済み（`mas` を使うため）
- [Homebrew](https://brew.sh/ja/) と Ansible。未導入なら `make init` で導入できます

## クイックスタート

1. リポジトリをクローンします。

   ```bash
   git clone git@github.com:YukiOno-1015/ansible-mac.git     # SSH
   # git clone https://github.com/YukiOno-1015/ansible-mac.git   # HTTPS
   cd ansible-mac
   ```

2. 前提条件（Homebrew / Ansible / Ansible collection）をセットアップします。Homebrew を新規に導入した場合は、PATH も通します。

   ```bash
   make init
   eval "$(/opt/homebrew/bin/brew shellenv)"
   ```

3. 変数を確認します。自分の環境で使う場合は、`group_vars/all.yml` の Git の設定を書き換えます。

   ```yaml
   git_user_name: "Your Name"
   git_user_email: "your@email.com"
   ```

4. プロファイルを選んで実行します。実行の冒頭で macOS のログインパスワードを尋ねられます（理由は下の「実行時の注意」）。

   ```bash
   make dev        # 開発用（開発ツール + 共通セット）
   make personal   # 普段使い用（コミュニケーション / エンタメ + 共通セット、開発ツールなし）
   ```

実行後に、Pleiades / FileZilla の展開など、いくつか手作業が残ります。詳しくは [docs/operations.md](docs/operations.md) を参照してください。

## make ターゲット

| コマンド | 内容 |
| --- | --- |
| `make init` | 前提条件（Homebrew / Ansible / collection）のセットアップ |
| `make dev` | 開発用の全体適用（playbook + npm グローバルパッケージ + uv ツール） |
| `make personal` | 普段使い用の全体適用（playbook のみ） |
| `make check-dev` / `make check-personal` | ドライラン（現状は最後まで完走しません。[KI-02](docs/known-issues.md)） |
| `make homebrew` | Homebrew の formula / cask |
| `make mas` | App Store アプリ |
| `make pleiades` | Pleiades DMG の取得 |
| `make filezilla` | FileZilla アーカイブの取得 |
| `make macos` | macOS 設定、ホスト名、`/etc/hosts` |
| `make git` | Git のグローバル設定 |
| `make dotfiles` | dotfiles の clone/update と install |
| `make import-settings` | 現環境のアプリ設定を dotfiles に取り込み |
| `make npm` / `make uv` | npm グローバルパッケージ / uv ツール |

> **部分実行のターゲットはプロファイルを引き継ぎません**（共通セットだけで動きます）。
> 特に `make macos` はホスト名の用途名が消え、`make pleiades` は何も取得しません。
> プロファイルを保つには `ansible-playbook site.yml --tags macos -e @vars/dev.yml` のように直接実行してください（[KI-03](docs/known-issues.md)）。
> また、`make xcode` は何も実行せず、MCP サーバ登録用のターゲットはありません（[KI-04](docs/known-issues.md)）。
> MCP は `ansible-playbook site.yml --tags mcp` で実行します。

ドライランや部分実行の使い分けは、[docs/operations.md](docs/operations.md) の 3 章にあります。

## プロファイル

2 つの違いは「開発に必要なものを入れるか」です。両者に共通する互換 CLI、エディタ、Office、AI ツールなどは、この環境を反映するために共通セットへ置いています。
個々のパッケージは [docs/catalog.md](docs/catalog.md) を参照してください。

| | 開発用 (`dev`) | 普段使い (`personal`) |
| --- | --- | --- |
| 共通 CLI（eza / bat / ripgrep / vim / ffmpeg など） | ✅ | ✅ |
| ansible / git / vault / mas | ✅ | ✅ |
| Node.js / nodenv / OpenJDK / jenv / uv | ✅ | ✅ |
| VS Code / wezterm / Chrome / qview / VLC | ✅ | ✅ |
| Microsoft Office / OneDrive | ✅ | ✅ |
| Discord / Slack | ✅ | ✅ |
| AI アシスタント（Claude / ChatGPT / Codex / Copilot の GUI・CLI） | ✅ | ✅ |
| Claude Code の MCP サーバ登録（11 件） | ✅ | ✅ |
| フォント（Nerd Font / HackGen など） | ✅ | ✅ |
| FileZilla（アーカイブの取得） | ✅ | ✅ |
| dotfiles | ✅ | ✅（Vault からの秘密情報の復元つき） |
| 開発系 CLI（gh / helm / maven / go など） | ✅ | ❌ |
| Docker / Postman / Sourcetree | ✅ | ❌ |
| swiftlint / Pleiades | ✅ | ❌ |
| App Store の開発系（Xcode / TestFlight / Developer） | ✅ | ❌ |
| npm / uv のグローバルツール | ✅ | ❌ |
| コミュニケーション（Webex / Thunderbird） | ❌ | ✅ |
| エンタメ（Kindle / LINE） | ❌ | ✅ |
| ホスト名の用途名 | `DEV` | `OA` |

## 実行時の注意

**sudo のパスワード**: Microsoft Office、`docker-desktop`、`webex-meetings` のような pkg ベースの cask は、インストール中に内部で `sudo` を呼びます。
そのため playbook は実行の冒頭で **macOS のログインパスワード**を尋ね、Ansible の `become`（`/etc/hosts` の書き換え）と、Homebrew cask 用の askpass ヘルパの両方で使います。
`sudo make ...` は使わず、通常ユーザーで実行してください。`git` / `dotfiles` のように sudo が不要な対象だけを実行するときは、空のまま Enter で構いません。

**Mac App Store**: `mas` は App Store へのサインインが必要です。失敗する場合の確認事項は [docs/operations.md](docs/operations.md) の 6 章にあります。

**手作業が残るもの**: Pleiades（`~/Downloads` の DMG）と FileZilla（`.app.tar.bz2`）は、取得までを自動化しています。インストールは手作業です。

## ディレクトリ構成

```text
ansible-mac/
├── Makefile                  # エントリーポイント
├── ansible.cfg               # Ansible 設定
├── requirements.yml          # Ansible collection 依存関係
├── site.yml                  # メイン playbook
├── inventory/localhost       # ローカル実行用インベントリ
├── group_vars/all.yml        # 共通変数（共通 packages / casks / MAS / Git / dotfiles / 取得元）
├── vars/
│   ├── dev.yml               # 開発用プロファイル
│   └── personal.yml          # 普段使い用プロファイル
├── roles/
│   ├── homebrew/             # tap / formula / OpenJDK / cask / jenv
│   ├── mas/                  # Mac App Store アプリ
│   ├── xcode/                # Xcode 依存 formula
│   ├── pleiades/             # Pleiades All in One DMG の取得
│   ├── filezilla/            # FileZilla アーカイブの取得
│   ├── macos/                # macOS 設定 / ホスト名 / /etc/hosts
│   ├── git/                  # Git グローバル設定
│   ├── dotfiles/             # dotfiles の clone/update と install
│   └── mcp/                  # Claude Code の MCP サーバ登録
├── scripts/
│   └── import-app-settings.sh  # 現環境のアプリ設定を dotfiles へ取り込み
├── .github/workflows/        # CI と版数追従 PR の自動作成
└── docs/                     # 要件定義・基本設計・詳細設計・運用ドキュメント
```

## CI

GitHub Actions（`pull_request` と `main` への push）で、次のチェックを実行します。

| チェック | 内容 |
| --- | --- |
| `yamllint` | YAML のフォーマット・インデントチェック |
| `shfmt` | Shell スクリプトのフォーマットチェック |
| `ansible-lint` | Ansible の静的チェック（現状は既知の 3 件で失敗。[KI-05](docs/known-issues.md)） |
| `ansible-playbook --syntax-check` | Playbook の構文チェック |

別に、Pleiades / FileZilla の新版を `group_vars/all.yml` に反映する PR を自動作成するワークフローがあります
（Jenkins の Mirror Pipeline から `repository_dispatch` を受信。現状は `RELEASE_PAT` が未登録で失敗します。[KI-01](docs/known-issues.md)）。

## ドキュメント

| 文書 | 内容 |
| --- | --- |
| [docs/requirements.md](docs/requirements.md) | 要件定義書 |
| [docs/basic-design.md](docs/basic-design.md) | 基本設計書 |
| [docs/detailed-design.md](docs/detailed-design.md) | 詳細設計書（変数一覧・role ごとの処理を含む） |
| [docs/catalog.md](docs/catalog.md) | 導入対象カタログ（formula / cask / MAS / MCP など） |
| [docs/operations.md](docs/operations.md) | 運用手順書・トラブルシューティング |
| [docs/testing.md](docs/testing.md) | テスト・品質 |
| [docs/design-decisions.md](docs/design-decisions.md) | 設計判断記録 |
| [docs/known-issues.md](docs/known-issues.md) | 既知の課題と改善候補 |

全体の索引は [docs/README.md](docs/README.md) です。
