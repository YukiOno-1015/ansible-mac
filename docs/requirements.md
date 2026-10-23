# 要件定義書

| 項目 | 内容 |
| --- | --- |
| 最終更新 | 2026-10-24（`main` @ `a5e36ad` 時点） |
| 位置づけ | 既存の実装・PR 履歴・運用実態から**逆算して**整理した要件です。実装と食い違う場合は実装を正とし、本書を直してください |
| 下位文書 | [basic-design.md](basic-design.md) → [detailed-design.md](detailed-design.md) |
| 検証 | [testing.md](testing.md)（TC-xx との対応は 4 章の表） |

## 1. 背景と目的

### 1.1 背景

- Mac を新規に用意する、あるいは作り直すたびに、アプリの導入や設定を手作業で繰り返すと、時間がかかるうえ抜け漏れやばらつきが出る
- 用途の違う 2 種類の Mac（開発用・普段使い）がある。境界が曖昧だと意図しないツールが入る（PR #1 の背景）
- Pleiades と FileZilla は Homebrew cask で提供されず、取得手段が必要だった（PR #1、#2）
- 社内向けの `*.sk4869.info` を Cloudflare 経由でなく、内部 VIP に直接向けたい（PR #1）
- AI アシスタントと、Claude Code の MCP サーバ設定を全環境で揃えたい（PR #5）

### 1.2 目的

1. Mac のセットアップを**少ないコマンドで再現**できるようにする
2. 構成を**コードで管理**し、変更履歴とレビューを残す
3. 開発用と普段使いの**差を明示的に管理**する

## 2. スコープ

### 2.1 対象

| 領域 | 内容 |
| --- | --- |
| パッケージ | Homebrew の tap / formula / cask、OpenJDK と jenv、Xcode 依存 formula |
| App Store | 無料アプリの取得（`mas`） |
| 配布物の取得 | Pleiades All in One と FileZilla を社内 Nexus から `~/Downloads` へ |
| macOS 設定 | Finder・キー入力・Dock・スクリーンショットの設定、ホスト名、`/etc/hosts` の内部 DNS |
| 開発環境 | Git のグローバル設定、dotfiles の取得と展開、npm グローバルパッケージと uv ツール |
| AI ツール | AI アシスタントの GUI / CLI、Claude Code の MCP サーバ登録 |
| 設定の取り込み | 現環境のアプリ設定を dotfiles へ取り込む（秘密情報は除く） |
| 品質・運用 | 静的検査（CI）、Pleiades / FileZilla の版数追従 PR の自動作成 |

### 2.2 対象外

| 項目 | 理由・扱い |
| --- | --- |
| macOS 以外（Windows / Linux） | `make init` が Darwin 以外を拒否する |
| Intel Mac の完全対応 | 部分的な分岐（`openjdk@8`）のみ。FileZilla / Pleiades の配布物は Apple Silicon 用 |
| 有料の App Store アプリ | `mas get` は無料アプリの取得 |
| Pleiades / FileZilla のインストール | 取得までを自動化。展開と配置は手作業 |
| Apple ID のサインイン、Vault のログイン | 利用者が事前に行う |
| Nexus、Jenkins、dotfiles リポジトリの構築・運用 | 別リポジトリ / 別システム。本書では連携の契約だけを扱う |
| アプリ個別の詳細設定 | dotfiles 側の責務 |
| MDM、ユーザーデータのバックアップ | 範囲外 |

## 3. 利用者と利用シナリオ

利用者は、リポジトリのオーナー本人が、自身の管理する Mac に対して実行する個人運用を想定しています。

| ID | シナリオ | 流れ |
| --- | --- | --- |
| S-1 | 新しい Mac を開発機として構築 | App Store にサインイン → `make init` → `make dev` → Pleiades / FileZilla を展開 |
| S-2 | 新しい Mac を普段使い機として構築 | App Store にサインイン → `make init` → `make personal` → FileZilla を展開 |
| S-3 | 定義の変更を既存の Mac に反映 | YAML を編集 → 同じコマンドを再実行 |
| S-4 | 一部だけ再適用 | タグ指定の部分実行（`ansible-playbook --tags` / `make <target>`） |
| S-5 | 現環境のアプリ設定を保存 | `make dotfiles` → `make import-settings` → 差分を確認して dotfiles にコミット |
| S-6 | Pleiades / FileZilla の新版に追従 | Jenkins がミラー → 追従 PR が自動作成 → レビューしてマージ → 各 Mac で再実行 |
| S-7 | MCP サーバを増やす | `mcp_servers` に追加 → `ansible-playbook site.yml --tags mcp` |

## 4. 機能要件

優先度は「必須」「推奨」の 2 段階です。「確認」は [testing.md](testing.md) のテストケースです。

| ID | 要件 | 優先度 | 実現手段 | 確認 |
| --- | --- | --- | --- | --- |
| FR-01 | `dev` / `personal` の 2 プロファイルを切り替えて適用できる | 必須 | `vars/*.yml`、`make dev` / `make personal` | TC-20 |
| FR-02 | 共通セットを 1 か所で定義し、プロファイルは差分だけを持つ | 必須 | `group_vars/all.yml` の `*_common` | TC-20 |
| FR-03 | 前提ツール（Homebrew・Ansible・collection）を導入できる | 必須 | `make init`、`requirements.yml` | TC-06 |
| FR-04 | Homebrew の tap / formula / cask を宣言的に導入できる | 必須 | `homebrew` role | TC-07 |
| FR-05 | OpenJDK を複数バージョン導入し、jenv に登録できる（Apple Silicon では `openjdk@8` を除く） | 必須 | `homebrew` role | TC-08 |
| FR-06 | Mac App Store の無料アプリを導入できる | 必須 | `mas` role | TC-15 |
| FR-07 | Xcode 依存の formula を、Xcode の導入後に導入できる | 推奨 | `xcode` role | TC-16 |
| FR-08 | Homebrew で提供されない配布物（Pleiades・FileZilla）を取得できる | 必須 | `pleiades` / `filezilla` role | TC-17 |
| FR-09 | macOS の設定（Finder・キー入力・Dock・スクリーンショット）を適用できる | 必須 | `macos` role | TC-10 |
| FR-10 | 機種・用途・シリアルからホスト名を生成して設定できる | 必須 | `macos` role | TC-09 |
| FR-11 | 社内 FQDN を内部 VIP に向ける `/etc/hosts` のエントリを管理できる | 必須 | `macos` role | TC-11 |
| FR-12 | Git のグローバル設定を適用できる | 必須 | `git` role | TC-12 |
| FR-13 | dotfiles を取得して展開できる。`personal` では Vault から秘密情報も復元する | 必須 | `dotfiles` role | TC-13 |
| FR-14 | AI アシスタント（Claude・ChatGPT・Codex・Copilot の GUI / CLI）を全プロファイルに導入できる | 必須 | `homebrew_casks_common` | TC-07 |
| FR-15 | Claude Code の MCP サーバを一括登録できる（未登録のものだけ） | 必須 | `mcp` role | TC-14 |
| FR-16 | npm グローバルパッケージと uv ツールを導入できる（`dev` のみ） | 推奨 | `make npm` / `make uv` | TC-18 |
| FR-17 | 現環境のアプリ設定を dotfiles へ取り込める（秘密情報は除外） | 推奨 | `make import-settings` | TC-19 |
| FR-18 | 対象を絞って部分的に実行できる | 必須 | タグ、`make <target>` | TC-22 |
| FR-19 | 変更を加えずに実行内容を確認できる（ドライラン） | 推奨 | `make check-dev` / `make check-personal` | TC-05 |
| FR-20 | pkg ベースの cask が必要とする `sudo` を、非対話の実行で通せる | 必須 | askpass ヘルパ | TC-23 |
| FR-21 | 静的検査（書式・lint・構文）を PR と `main` への push で自動実行する | 必須 | `ci.yml` | TC-01 〜 TC-04 |
| FR-22 | Pleiades / FileZilla の新版を検知し、追従 PR を自動作成する | 推奨 | Jenkins Mirror Pipeline、更新ワークフロー | TC-24 |

## 5. 非機能要件

| ID | 区分 | 要件 | 実現方法・根拠 | 確認 |
| --- | --- | --- | --- | --- |
| NFR-01 | 冪等性 | 繰り返し実行しても同じ状態に収束する | Ansible のモジュール、`creates`、`changed_when`。例外は `mas get` の changed 表示と、毎回走る `brew update` | TC-21 |
| NFR-02 | 機密保護 | パスワード・トークンをリポジトリ・ログ・設定ファイルに平文で残さない | `vars_prompt`（`private`）、`no_log`、`expand_argument_vars: false`、`~/.secrets.env` の実行時読み込み、`RELEASE_PAT` は Secrets | TC-25 |
| NFR-03 | 権限 | root で実行しない。`sudo` は必要な箇所だけで使う | `ensure-not-root`、`become` は `/etc/hosts` のタスクだけ | レビュー |
| NFR-04 | 継続性 | 個別の cask の失敗で全体を止めない | `Install Homebrew casks` の `ignore_errors` | TC-07 |
| NFR-05 | 保守性 | 値は変数に 1 回だけ書く。lint が通る。既存の流儀に合わせる | `group_vars/all.yml`、`.yamllint`、`.ansible-lint` | TC-01、TC-03 |
| NFR-06 | 可観測性 | 実行結果が読みやすい形式で出力される | `result_format = yaml` | レビュー |
| NFR-07 | 移植性 | macOS 専用。Apple Silicon を前提とし、Intel は一部を分岐で扱う | `ansible_architecture` による `openjdk@8` の除外 | TC-08 |
| NFR-08 | 再現性 | Pleiades / FileZilla の版数は固定する。Homebrew と MCP（`@latest`）は最新に追従する | 厳密に同一の状態を再現することは求めない | レビュー |
| NFR-09 | 運用性 | 失敗時の切り分け手順が文書化されている | [operations.md](operations.md) | レビュー |
| NFR-10 | 公開前提 | リポジトリは公開。公開してよい情報だけを置く | Vault と GitHub Secrets に秘密を置く | レビュー |

処理時間に要件は定めていません。

## 6. 制約・前提条件

| ID | 区分 | 内容 |
| --- | --- | --- |
| C-01 | OS | macOS のみ |
| C-02 | CPU | Apple Silicon 前提。FileZilla の URL とファイル名は arm64 用。Homebrew の存在判定は `/opt/homebrew/bin/brew` 固定（KI-12） |
| C-03 | 権限 | 管理者権限を持つ通常ユーザーで実行し、macOS ログインパスワードを入力する |
| C-04 | ネットワーク | GitHub、Homebrew、Mac App Store、社内 Nexus（`nexus.sk4869.info`）、`npx` / `uvx` が取得するパッケージの配布元に到達できること |
| C-05 | App Store | Apple ID でサインイン済みで、規約・支払い情報の確認が残っていないこと |
| C-06 | PATH | `brew` / `mas` / `jenv` / `claude` が PATH にあること（新規 Mac は `make init` の後に `brew shellenv` を通す） |
| C-07 | 外部リポジトリ | dotfiles の `install.sh` の出力文言（`リンク作成:` / `バックアップ:`）に、changed の判定が依存する |
| C-08 | 秘密情報 | `~/.secrets.env` はリポジトリ外にあり、Vault から復元される（`personal` は自動、`dev` は手動。KI-08） |
| C-09 | 公開 | リポジトリは公開 |
| C-10 | 手作業 | App Store のサインイン、Vault のログイン、Pleiades / FileZilla の展開は手作業 |

## 7. 外部インタフェース要件

詳細は [basic-design.md](basic-design.md) の 7 章にあります。

| 相手 | 要件 |
| --- | --- |
| 社内 Nexus | `raw-tools/eclipse/<release>/` と `raw-tools/filezilla/<version>/` に配布物があること |
| Jenkins Mirror Pipeline | 新版を Nexus に置いたあと、`repository_dispatch`（`update-filezilla` / `update-pleiades`）を送ること |
| dotfiles リポジトリ | `install.sh` が `--restore-secrets` を受け付け、リンク作成・退避時に所定の文言を出力すること |
| Claude Code CLI | `claude mcp get` / `claude mcp add-json --scope user` が使えること |

## 8. 受入基準

「現状」は 2026-10-24 に確認できた範囲です。「未検証」は、新規の Mac での通し実行を行っていないことを示します。

| ID | 基準 | 現状 |
| --- | --- | --- |
| AC-01 | 初期状態の Mac で `make init` と `make dev` が完了し、`dev` の導入物が揃う | 未検証。検証に使った Mac では `macos` role が Dock の設定で失敗した（KI-14） |
| AC-02 | 同様に `make init` と `make personal` が完了し、`personal` の導入物が揃う | 未検証 |
| AC-03 | 同じコマンドを再実行しても、破壊的な変更がなく、changed が想定の範囲に収まる | 未検証 |
| AC-04 | `make check-dev` / `make check-personal` が完走する | **未達**（KI-02、KI-14） |
| AC-05 | CI の静的検査がすべて通る | **未達**。`ansible-lint` が 3 件で失敗（KI-05）。`yamllint`（warning のみ）と `--syntax-check` は通る |
| AC-06 | 秘密情報がログ・リポジトリ・設定ファイルに残らない | 設計上は満たす。中断時に askpass の一時ファイルが残る余地がある（KI-10） |
| AC-07 | 新版の通知から追従 PR の作成までが自動で行われる | **未達**。`RELEASE_PAT` が未登録（KI-01） |

## 9. リスク

| ID | リスク | 影響 | 対応 |
| --- | --- | --- | --- |
| R-01 | 配布元サイトの改修でスクレイピングが壊れる（Pleiades は API なし、FileZilla は暗号化された HTML） | 版数の検知が止まる | Jenkins 側で検出ロジックを差し替える |
| R-02 | Homebrew の formula / cask の改名・廃止・tap 移動（例: `vault` は core から外れ tap 経由） | 導入の失敗 | YAML を直す。cask の失敗は無視されるため出力を確認する |
| R-03 | `@latest` 指定の MCP パッケージが変わる | 起動の失敗や挙動の変化 | 必要なら版を固定する |
| R-04 | Nexus や Jenkins の停止 | Pleiades / FileZilla を取得できない、追従が止まる | 復旧を待つか、`*_url` を一時的に差し替える |
| R-05 | dotfiles の `install.sh` の出力文言の変更 | `dotfiles` role の changed 判定が外れる | 文言を揃える |
| R-06 | App Store の状態（サインイン・規約・支払い情報） | `mas` が空のエラーで失敗する | [operations.md](operations.md) のトラブルシューティング |

## 10. 用語集

| 用語 | 意味 |
| --- | --- |
| プロファイル | `dev`（開発用）と `personal`（普段使い）。`vars/<profile>.yml` で定義する |
| 共通セット | 両プロファイルに入れるもの。`group_vars/all.yml` の `*_common` |
| formula / cask / tap | Homebrew の CLI パッケージ / GUI アプリ / 追加のリポジトリ |
| MAS | Mac App Store。`mas` はその CLI |
| askpass | `sudo -A` がパスワードを得るためのヘルパプログラム。`SUDO_ASKPASS` で指定する |
| dotfiles | 設定ファイルを管理する別リポジトリ（`YukiOno-1015/dotfiles`） |
| Vault | HashiCorp Vault。SSH / AWS の認証情報と `~/.secrets.env` の保管先 |
| Nexus | 社内のアーティファクトリポジトリ。`raw-tools` に Pleiades / FileZilla を置く |
| Mirror Pipeline | Jenkins のジョブ（別リポジトリ `jenkins-cli`）。配布元の新版を Nexus に複製し、通知を送る |
| MCP | Model Context Protocol。Claude Code が外部ツールを使うための仕組み |
| jenv | Java のバージョン管理ツール |
| 冪等 | 何度実行しても同じ結果になること |
