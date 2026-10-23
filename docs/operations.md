# 運用手順書

| 項目 | 内容 |
| --- | --- |
| 最終更新 | 2026-10-24（`main` @ `666591a` 時点） |
| 対象 | セットアップ、日常運用、版数の更新、変更の進め方、トラブルシューティング |
| 関連 | 仕組みは [basic-design.md](basic-design.md)、既知の不具合は [known-issues.md](known-issues.md) |

## 1. 事前準備

実行前に、次を確認します。

- [ ] macOS（Apple Silicon）で、管理者権限を持つ通常ユーザーでログインしている（`sudo make ...` は不可）
- [ ] App Store アプリでサインイン済み。利用規約や支払い情報の確認が残っていない
- [ ] 社内 Nexus（`nexus.sk4869.info`）に到達できる（Pleiades / FileZilla の取得に必要）
- [ ] Vault にログインできる（`personal`、または `dev` で秘密情報を復元するとき）
- [ ] macOS のログインパスワードが分かる（実行の冒頭で 2 回入力する）

## 2. 初回セットアップ

### 2.1 手順

1. リポジトリを取得します。

   ```bash
   git clone git@github.com:YukiOno-1015/ansible-mac.git    # SSH
   # git clone https://github.com/YukiOno-1015/ansible-mac.git  # HTTPS
   cd ansible-mac
   ```

2. 前提ツール（Homebrew・Ansible・collection）を導入します。

   ```bash
   make init
   ```

   Homebrew を新規に導入した場合、`brew` は PATH に入っていません。続けて実行する前に PATH を通します。

   ```bash
   eval "$(/opt/homebrew/bin/brew shellenv)"
   ```

3. 変数を確認します。他人の環境で使う場合は、`group_vars/all.yml` の `git_user_name` / `git_user_email` を自分の値に変更します。

4. プロファイルを選んで実行します。実行の冒頭で macOS のログインパスワードを尋ねられます。

   ```bash
   make dev        # 開発用（playbook + npm + uv）
   make personal   # 普段使い用（playbook のみ）
   ```

### 2.2 実行後の手作業

| 作業 | 対象 | 内容 |
| --- | --- | --- |
| Pleiades のインストール | `dev` | `~/Downloads/pleiades-*.dmg` を開いてインストールする |
| FileZilla の配置 | 共通 | `~/Downloads/FileZilla_*.app.tar.bz2` を展開し、`.app` を `/Applications` へ移動する |
| 秘密情報の復元 | `dev` | Vault にログインし、`cd ~/dotfiles && ./install.sh --restore-secrets` を実行する（KI-08）。`personal` は自動 |
| 新しいシェルを開く | 共通 | dotfiles の `.zprofile` が Homebrew の PATH などを設定する |
| MCP の確認 | 共通 | `claude mcp list` で、登録されたサーバと接続状態を確認する |
| Xcode 依存 formula | `dev` | `swiftlint` が入っていなければ、Xcode の導入後に `make dev` を再実行する |

## 3. 日常運用

### 3.1 定義の変更を反映する

YAML を編集して、同じコマンドを再実行します。再実行しても、導入済みのものは変更されません。

```bash
make dev        # または make personal
```

### 3.2 部分的に実行する

`make <target>` の部分実行はプロファイルを引き継ぎません（KI-03）。プロファイルを保つには `ansible-playbook` を直接使います。

| 対象 | 推奨コマンド | 補足 |
| --- | --- | --- |
| Homebrew | `ansible-playbook site.yml --tags homebrew -e @vars/dev.yml` | `xcode` role も実行される |
| App Store | `ansible-playbook site.yml --tags mas -e @vars/dev.yml` | |
| Xcode 依存 formula | `ansible-playbook site.yml --tags xcode -e @vars/dev.yml` | `make xcode` は何もしない（KI-04） |
| Pleiades | `ansible-playbook site.yml --tags pleiades -e @vars/dev.yml` | `dev` のみ有効 |
| FileZilla | `make filezilla` | 共通で有効 |
| macOS 設定 | `ansible-playbook site.yml --tags macos -e @vars/dev.yml` | プロファイルを付けないとホスト名の用途名が消える |
| Git | `make git` | |
| dotfiles | `ansible-playbook site.yml --tags dotfiles -e @vars/personal.yml` | `personal` は `--restore-secrets` 付き |
| MCP | `ansible-playbook site.yml --tags mcp` | `make` ターゲットはない |
| アプリ設定の取り込み | `make import-settings` | 3.6 を参照 |
| npm / uv | `make npm` / `make uv` | `make dev` でも実行される |

`sudo` が不要な対象（`git`、`dotfiles` など）は、パスワードの入力で空のまま Enter でも動きます。

### 3.3 ドライランを使う

`make check-dev` / `make check-personal` は、全体では完走しません（KI-02）。role を絞って使ってください。

```bash
# パスワード入力を省略し、git role だけを確認する例
ansible-playbook site.yml --check --tags git -e @vars/dev.yml -e ansible_become_password=
```

`homebrew` モジュールの結果は常に changed になるため、差分の確認には向きません。
実機への反映前の確認は、変更が小さいうちに実行して出力を読む運用になります。

### 3.4 パッケージ・アプリを追加・削除する

| 追加したいもの | 追記先 |
| --- | --- |
| 両プロファイルに入れる formula | `group_vars/all.yml` の `homebrew_packages_common` |
| 両プロファイルに入れる cask | `group_vars/all.yml` の `homebrew_casks_common` |
| 両プロファイルに入れる App Store アプリ | `group_vars/all.yml` の `mas_apps_common`（`id` と `name`） |
| `dev` だけ | `vars/dev.yml` の `homebrew_packages_dev_extra` / `homebrew_casks_dev_extra` / `mas_apps_dev_extra` |
| `personal` だけ | `vars/personal.yml` の `homebrew_casks_personal_extra` / `mas_apps_personal_extra` |

手順は次のとおりです。

1. 追記先の YAML を編集する（コメントで分類を揃える）
2. `yamllint .` と `ansible-playbook site.yml --syntax-check -e @vars/dev.yml`（`personal` も）で検査する
3. `ansible-playbook site.yml --tags homebrew -e @vars/dev.yml` などで反映する
4. 件数が変わったら、[catalog.md](catalog.md) の件数サマリと一覧を更新する

**YAML から消しても、アンインストールはされません。** 不要になったものは `brew uninstall`（cask は `--cask`）で手動削除します。

### 3.5 MCP サーバを追加・変更する

- **追加**: `roles/mcp/defaults/main.yml` の `mcp_servers` に `name` と `config` を足し、`ansible-playbook site.yml --tags mcp` を実行します。
  トークンはコマンドに書かず、`sh -c 'set -a; . "$HOME/.secrets.env"; set +a; exec ...'` の形で実行時に読み込ませます
- **変更**: 登録済みのサーバは更新されません。`claude mcp remove <name> --scope user` で削除してから、再実行します
- 行長が 120 文字を超えると `ansible-lint` が失敗します（KI-05）。長いコマンドは折り返します

### 3.6 アプリ設定を dotfiles に取り込む

```bash
make dotfiles          # ~/dotfiles を用意
make import-settings   # 現環境の設定を ~/dotfiles/home/ へコピー
cd ~/dotfiles
git status && git diff # 秘密情報が含まれていないことを確認
```

確認後、dotfiles リポジトリ側でコミットします。`import-settings` は、対象のディレクトリをコピー先で一度削除してから置き換えます。
取り込み対象は [catalog.md](catalog.md) の 7 章にあります。

### 3.7 Wiki への反映

`docs/` の変更を `main` にマージすると、ワークフロー `Sync docs to Wiki` が [Wiki](https://github.com/YukiOno-1015/ansible-mac/wiki) を自動で更新します。
**Wiki 上の編集は次の同期で上書きされる**ため、文書の修正は `docs/` に対して行ってください。

- **確認**: Actions タブで `Sync docs to Wiki` の結果を見る。PR では `Validate Wiki pages` が、変換とリンクを検査する
- **手動で反映**: Actions タブから `Sync docs to Wiki` を実行する（`workflow_dispatch`）。または下のコマンド
- **ローカルで試す**: 空のディレクトリへ出力して、変換結果とリンク検査を確認する（Wiki には書かない）

```bash
gh workflow run sync-wiki.yml --repo YukiOno-1015/ansible-mac    # 手動で反映
mkdir -p /tmp/wiki-check && scripts/sync-wiki.sh /tmp/wiki-check   # ローカルで試す
```

`docs/` 内のリンクは、`xxx.md`、`xxx.md#見出し`、`../README.md` の形だけを使います。
文書を追加・改名したときは、`scripts/sync-wiki.sh` の `PAGE_ORDER`（サイドバーの順序）も直します。
前提として、Wiki の最初のページが作成済みであること。

書き込みは `GITHUB_TOKEN` だけで動きます（初回の同期で確認済み）。Secrets に `WIKI_TOKEN` があると、そちらを優先して使うため、通常は登録不要です。
登録している場合は、PAT の失効やスコープ不足で同期が失敗する点に注意してください（不要なら削除すると `GITHUB_TOKEN` に戻ります）。
失敗時の対処は、6 章のトラブルシューティングを参照してください。

## 4. 版数の更新（Pleiades / FileZilla）

### 4.1 自動（通常）

1. Jenkins の Mirror Pipeline が新版を Nexus に置き、`repository_dispatch` を送る
2. 更新ワークフローが `group_vars/all.yml` を書き換えた PR（`auto/filezilla-<version>` または `auto/pleiades-<release>-<buildDate>`）を作る
3. PR をレビューして、マージする
4. 各 Mac で再実行して新版を取得する（`ansible-playbook site.yml --tags filezilla`、`--tags pleiades -e @vars/dev.yml`）

現在は `RELEASE_PAT` が未登録のため、手順 2 が失敗します（KI-01）。Wiki ミラーの `WIKI_TOKEN` とは別のシークレットです。
`repo` スコープの PAT を、次のコマンドで登録します。値は対話プロンプトに貼り付け、コマンドラインや会話には書きません。

```bash
gh secret set RELEASE_PAT --repo YukiOno-1015/ansible-mac
```

### 4.2 手動

1. 取得先に新版のファイルがあることを確認します（HTTP 200 になること）。

   ```bash
   curl -sfI "https://nexus.sk4869.info/repository/raw-tools/filezilla/<version>/FileZilla_<version>_macos-arm64.app.tar.bz2" | head -1
   ```

2. `group_vars/all.yml` の `filezilla_version`（または `pleiades_release` と `pleiades_version`）を書き換えます
3. PR を作ってマージし、各 Mac で再実行します。ファイル名に版数が含まれるため、新版は別のファイルとして取得されます

### 4.3 追従の動作確認（テスト用 dispatch）

`RELEASE_PAT` を登録したあと、PR が作られることを確認できます。**実際に PR が作られる**ため、確認後は閉じてください。

```bash
echo '{"event_type":"update-filezilla","client_payload":{"version":"<現在と異なる版>","jenkins":"manual-test"}}' \
  | gh api repos/YukiOno-1015/ansible-mac/dispatches --input -
```

## 5. 変更の進め方

1. `main` から作業ブランチを作ります。`main` へ直接コミットしません
2. 変更して、ローカルで検査します。

   ```bash
   yamllint .
   ansible-playbook site.yml --syntax-check -e @vars/dev.yml
   ansible-playbook site.yml --syntax-check -e @vars/personal.yml
   ansible-lint                                   # 要インストール（brew install ansible-lint）
   shfmt -d -i 2 -ci scripts/import-app-settings.sh
   ```

3. コミットメッセージは `<type>: <日本語の説明>` にします（`feat` / `fix` / `chore` / `docs` / `refactor` / `test` / `style` / `perf`）
4. push して PR を作ります。CI の結果を確認します。ansible-lint は既知の 3 件で失敗します（KI-05）。それ以外の新しい違反がないことを見てください
5. squash マージします
6. 設計に関わる変更なら、[docs/README.md](README.md) の「更新ルール」に従って文書も更新します

## 6. トラブルシューティング

| 症状 | 原因 | 対処 |
| --- | --- | --- |
| `sudo: a terminal is required to read the password` / `sudo: a password is required`（cask の導入中） | パスワードを空で実行した、または `sudo make` で実行した | 通常ユーザーで `make dev` を実行し、冒頭でパスワードを入力する。特定の cask だけ失敗するときは `brew install --cask docker-desktop webex-meetings` を手動で実行してから再実行する |
| cask が失敗しているのに play が止まらない | `Install Homebrew casks` は `ignore_errors: true` | 出力の `...ignoring` を確認し、該当の cask を手動で導入する |
| `Error running command 'install' on app '<app-id>':`（以降が空） | App Store の状態 | App Store アプリでサインインしているか、利用規約・支払い情報の確認が残っていないか、`mas config` で `store` / `region` が表示されるかを確認する。`mas list` が固まる場合は App Store アプリを開いて状態を直すか `mas reset` を実行する。直したら `make mas` を再実行する |
| `command not found: brew` / `ansible-playbook` | PATH に Homebrew がない | `eval "$(/opt/homebrew/bin/brew shellenv)"` を実行する |
| `Do not run this Makefile with sudo.` | root で実行した | `sudo` を外して実行する |
| `make xcode` が何も起きない | ターゲットがない（KI-04） | `ansible-playbook site.yml --tags xcode -e @vars/dev.yml` |
| `make macos` の後にホスト名が変わった | プロファイルが引き継がれない（KI-03） | `ansible-playbook site.yml --tags macos -e @vars/dev.yml` で戻す |
| `make pleiades` で何も取得されない | `pleiades_enabled` が `false`（KI-03） | `ansible-playbook site.yml --tags pleiades -e @vars/dev.yml` |
| `Type mismatch. Type in defaults: float` | Dock の `tilesize` が float で保存されている（KI-14） | `defaults delete com.apple.dock tilesize` を実行して再実行する |
| `--check` で `object of type 'dict' has no attribute 'path'` | check モードで askpass の一時ディレクトリが作られない（KI-02） | パスワードを空にして実行する。ただし `/etc/hosts` のタスクが失敗する |
| `--check` で `sudo: a password is required`（`/etc/hosts`） | 昇格に必要なパスワードがない（KI-02） | role を絞った `--check` を使う（3.3 を参照） |
| `curl: (22) The requested URL returned error: 404` | Nexus に該当の版数・ファイルがない、または到達できない | 4.2 の `curl -sfI` で URL を確認する。`*_version` / `*_release` を Nexus の内容に合わせる |
| FileZilla が Intel Mac で動かない | 取得するのは arm64 用 | `filezilla_filename` と `filezilla_url` を x86 用（`..._macos-x86.app.tar.bz2`）に差し替える。Nexus にも x86 用が格納されている（2026-10-24 に確認） |
| `claude CLI が見つからないため MCP 登録をスキップします` | `claude-code` cask が未導入、または PATH にない | `homebrew` を実行して導入し、新しいシェルで `mcp` を再実行する |
| MCP サーバが認証エラー、または起動しない | `~/.secrets.env` がない（KI-08）、または Docker がない（KI-09） | 2.2 の手順で復元する。`claude mcp list` で状態を見る |
| MCP の定義を変えたのに反映されない | 登録済みは更新しない仕様 | `claude mcp remove <name> --scope user` の後に再実行する |
| CI が赤い | 既知の `yaml[line-length]` 3 件（KI-05） | ログで違反箇所が 3 件のままか確認する。増えていれば新しい違反 |
| 更新ワークフローが `Input required and not supplied: token` で失敗 | `RELEASE_PAT` が未登録（KI-01） | 4.1 の手順で登録する |
| 中断した後、`ansible.*askpass` というディレクトリが残っている | クリーンアップされなかった（KI-10） | `ls -d "${TMPDIR%/}"/ansible.*askpass` で確認し、内容を見て削除する |
| `Sync docs to Wiki` が `Wiki を clone できません` で失敗 | Wiki の最初のページが未作成、またはトークンに権限がない | Web 画面で Wiki の最初のページを作る。権限エラー（403）のときは、`repo` スコープの PAT を `gh secret set WIKI_TOKEN --repo YukiOno-1015/ansible-mac` で登録して再実行する。すでに `WIKI_TOKEN` を登録している場合は、PAT の有効期限とスコープを確認する（削除すれば `GITHUB_TOKEN` に戻る） |
| PR の `Validate Wiki pages` が `link to a missing page` / `relative file link remains` で失敗 | `docs/` 内のリンクが、Wiki に変換できない形 | リンクを `xxx.md`、`xxx.md#見出し`、`../README.md` の形にする。存在しない文書へのリンクを直す。リンク記法をコードとして書いている箇所は、書き方を変える |
| Wiki の表示が `docs/` と違う | Wiki 上で直接編集した（次の同期で上書きされる） | `docs/` を直し、`Sync docs to Wiki` を手動で実行して戻す |

## 7. 元に戻す

この playbook は「入れる」ことだけを宣言します。戻すときは、対象ごとに手動で行います。

| 対象 | 方法 |
| --- | --- |
| Homebrew のパッケージ | `brew uninstall <formula>` / `brew uninstall --cask <cask>` |
| macOS 設定 | `defaults delete <domain> <key>` の後 `killall Dock Finder` |
| ホスト名 | `sudo scutil --set ComputerName <旧名>`（`HostName` / `LocalHostName` も同様） |
| `/etc/hosts` | 下記 |
| Git 設定 | `git config --global --unset user.name`（`user.email` なども同様） |
| dotfiles | リンクを削除し、`~/.dotfiles-backup/<timestamp>/` に退避された元のファイルを戻す |
| MCP サーバ | `claude mcp remove <name> --scope user` |

`/etc/hosts` の管理ブロックは、`macos_internal_dns_entries` を空にしても削除されません。
バックアップを取ってから、マーカーの間を削除します。

```bash
sudo cp /etc/hosts /etc/hosts.bak
sudo sed -i '' '/BEGIN ANSIBLE MANAGED: internal sk4869.info/,/END ANSIBLE MANAGED: internal sk4869.info/d' /etc/hosts
```
