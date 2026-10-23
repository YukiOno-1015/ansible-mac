# テスト・品質

| 項目 | 内容 |
| --- | --- |
| 最終更新 | 2026-10-24（`main` @ `a5e36ad` 時点） |
| 対応する要件 | [requirements.md](requirements.md) の FR-xx / NFR-xx / AC-xx |
| 関連 | CI の設計は [basic-design.md](basic-design.md) の 8 章、既知の不具合は [known-issues.md](known-issues.md) |

## 1. 方針

このリポジトリの処理の大半は macOS 固有です（Homebrew、App Store、`defaults`、`scutil`、`/etc/hosts`）。
CI は Ubuntu 上で動くため、**実機での適用は CI では検証されません**。そこで、検証を 3 層に分けます。

| 層 | 内容 | 実行 | 現状 |
| --- | --- | --- | --- |
| 1. 静的検査 | 書式・lint・構文 | CI（自動）とローカル | `ansible-lint` が既知の 3 件で失敗（KI-05） |
| 2. ドライラン | `--check` による事前確認 | 手動 | 全体では完走しない。role 単位なら使える（KI-02） |
| 3. 実機検証 | 実際に適用して結果を確認 | 手動 | テストケースを 4 章に定義 |

自動化された実機テストはありません。実機の検証は、変更の影響範囲に応じて 4 章のケースを選んで行います。

## 2. 静的検査（層 1）

CI と同じ検査をローカルで再現できます。

| ID | 検査 | コマンド | 期待結果 | 現状 |
| --- | --- | --- | --- | --- |
| TC-01 | YAML の書式・インデント | `yamllint .` | 終了コード 0（行長の warning は許容） | warning 3 件（行長） |
| TC-02 | シェルの書式 | `shfmt -d -i 2 -ci scripts/import-app-settings.sh` | 差分なし | 通る |
| TC-03 | Ansible の静的検査 | `ansible-lint` | 違反なし | **3 件で失敗**（`yaml[line-length]`、KI-05） |
| TC-04 | Playbook の構文 | `ansible-playbook site.yml --syntax-check -e @vars/dev.yml`（`personal` も） | エラーなし | 通る |

CI は TC-04 をプロファイルなしで実行します。ローカルでは両プロファイルで確認してください。

## 3. ドライラン（層 2）

`make check-dev` / `make check-personal` は、全体では完走しません（KI-02）。

| ID | 検査 | コマンド | 期待結果 | 現状 |
| --- | --- | --- | --- | --- |
| TC-05 | ドライラン | `make check-dev` / `make check-personal` | 完走する | **未達**（KI-02、KI-14） |

代わりに、role を絞って使います。`homebrew` モジュールの結果は常に changed になるため、差分の確認に向くのは
`git`、`dotfiles`、`macos`（`/etc/hosts` 以外）などです。

```bash
ansible-playbook site.yml --check --tags git -e @vars/dev.yml -e ansible_become_password=
ansible-playbook site.yml --list-tasks --tags git     # 実行されるタスクの確認
```

実効の変数は、実行せずに確認できます。

```bash
ansible localhost -m ansible.builtin.debug -a 'var=homebrew_packages' -e @vars/dev.yml
ansible localhost -m ansible.builtin.debug -a 'msg={{ homebrew_casks | length }}' -e @vars/personal.yml
```

## 4. 実機検証（層 3）

テストケースの一覧です。「対応」は [requirements.md](requirements.md) の要件です。

| ID | 観点 | 対応 |
| --- | --- | --- |
| TC-06 | 前提ツールの導入 | FR-03 |
| TC-07 | formula / cask / tap と AI ツールの導入 | FR-04、FR-14、NFR-04 |
| TC-08 | OpenJDK と jenv | FR-05、NFR-07 |
| TC-09 | ホスト名 | FR-10 |
| TC-10 | macOS 設定 | FR-09 |
| TC-11 | `/etc/hosts` | FR-11 |
| TC-12 | Git 設定 | FR-12 |
| TC-13 | dotfiles | FR-13 |
| TC-14 | MCP サーバの登録 | FR-15 |
| TC-15 | App Store アプリ | FR-06 |
| TC-16 | Xcode 依存 formula | FR-07 |
| TC-17 | 配布物の取得 | FR-08 |
| TC-18 | npm / uv ツール | FR-16 |
| TC-19 | アプリ設定の取り込み | FR-17 |
| TC-20 | プロファイルの差分 | FR-01、FR-02 |
| TC-21 | 冪等性 | NFR-01 |
| TC-22 | 部分実行 | FR-18 |
| TC-23 | pkg 系 cask の sudo（askpass） | FR-20 |
| TC-24 | 版数の自動追従 | FR-22 |
| TC-25 | 秘密情報の非残存 | NFR-02 |

### TC-06 前提ツールの導入

```bash
make init
brew --version && ansible --version
ansible-galaxy collection list community.general
```

期待: `==> init complete` が表示され、各コマンドが版数を返す。

### TC-07 formula / cask / tap と AI ツール

実効の一覧と突き合わせます（例: `dev`）。

```bash
brew tap                                   # hashicorp/tap を含む
brew list --formula                        # catalog.md の 1.2 / 1.3 の formula を含む
brew list --cask                           # catalog.md の 1.6 / 1.7 の cask を含む（claude, claude-code, chatgpt, codex, copilot-cli, github-copilot-for-xcode）
```

期待: プロファイルの実効リストがすべて含まれる。cask の失敗は `ignore_errors` で無視されるため、実行ログの `...ignoring` も確認する。

### TC-08 OpenJDK と jenv

```bash
jenv versions
brew list --formula | grep '^openjdk'
```

期待: `openjdk`、`openjdk@11`、`@17`、`@21` が jenv に登録されている。`openjdk@8` は Intel Mac のときだけ。

### TC-09 ホスト名

```bash
scutil --get ComputerName; scutil --get HostName; scutil --get LocalHostName
```

期待: 3 つとも同じ値で、`<デバイス名><用途名><シリアル>` の形式（大文字英数字のみ）。`dev` は `...DEV...`、`personal` は `...OA...` を含む。
あわせて、**`sudo` の資格情報がない状態で `scutil --set` が通ること**を確認する（`become` を指定していないため）。

### TC-10 macOS 設定

```bash
defaults read com.apple.finder AppleShowAllFiles                     # 1
defaults read NSGlobalDomain AppleShowAllExtensions                  # 1
defaults read NSGlobalDomain NSAutomaticSpellingCorrectionEnabled    # 0
defaults read NSGlobalDomain KeyRepeat                               # 2
defaults read NSGlobalDomain InitialKeyRepeat                        # 15
defaults read com.apple.dock autohide                                # 1
defaults read com.apple.dock tilesize                                # 48
defaults read com.apple.screencapture location                       # ~/Desktop/screenshots の絶対パス
```

### TC-11 `/etc/hosts`

```bash
sed -n '/BEGIN ANSIBLE MANAGED/,/END ANSIBLE MANAGED/p' /etc/hosts
dscacheutil -q host -a name nexus-cli.sk4869.info
```

期待: 管理ブロックに VIP と 2 つの FQDN があり、名前解決の結果が VIP になる。再実行してもブロックが重複しない。

### TC-12 Git 設定

```bash
git config --global --get user.name
git config --global --get user.email
git config --global --get init.defaultBranch    # main
git config --global --get core.editor           # vim
```

注意: dotfiles 展開後は `~/.gitconfig` が dotfiles 側のファイルになるため、値は dotfiles の内容で決まる（KI-07）。

### TC-13 dotfiles

```bash
git -C ~/dotfiles status -sb
ls -l ~/.zshrc                  # ~/dotfiles/home/.zshrc へのシンボリックリンク
ls -l ~/.secrets.env            # personal: 存在する。dev: 手動の復元後に存在する（KI-08）
```

期待: 取得したブランチが `dotfiles_version` と一致し、設定ファイルがリンクされている。既存ファイルは `~/.dotfiles-backup/<timestamp>/` に退避されている。

### TC-14 MCP サーバの登録

```bash
claude mcp list                                                       # 11 サーバが表示される
ansible-playbook site.yml --tags mcp                                   # 2 回目は changed=0
grep -n '\.secrets\.env' ~/.claude.json                                # $HOME/.secrets.env が展開されずに残っている
```

期待: 11 サーバが登録され、再実行しても追加されない。`github` は Docker、`backlog` / `qiita` / `n8n-mcp` は `~/.secrets.env` が必要（KI-08、KI-09）。

### TC-15 App Store アプリ

```bash
mas list
```

期待: [catalog.md](catalog.md) の 2 章のうち、プロファイルに該当するアプリが含まれる（Xcode は容量が大きく、時間がかかる）。

### TC-16 Xcode 依存 formula

```bash
test -d /Applications/Xcode.app && brew list --formula swiftlint
```

期待: `dev` で Xcode があるとき、`swiftlint` が入っている。

### TC-17 配布物の取得

```bash
ls -l ~/Downloads/pleiades-*.dmg ~/Downloads/FileZilla_*_macos-arm64.app.tar.bz2
hdiutil imageinfo ~/Downloads/pleiades-*.dmg > /dev/null && echo "dmg ok"
tar -tjf ~/Downloads/FileZilla_*_macos-arm64.app.tar.bz2 | head -1
```

期待: `dev` は両方、`personal` は FileZilla だけが取得され、壊れていない（KI-13）。

### TC-18 npm / uv ツール

```bash
npm list -g --depth=0
uv tool list
```

期待: `dev` で [catalog.md](catalog.md) の 4 章のツールがすべて入っている。`personal` では入らない。

### TC-19 アプリ設定の取り込み

```bash
make dotfiles && make import-settings
git -C ~/dotfiles status -sb
```

期待: [catalog.md](catalog.md) の 7 章の対象だけが `~/dotfiles/home/` に入る。Thunderbird のパスワード DB・証明書 DB、VS Code の `globalStorage` が含まれない。

### TC-20 プロファイルの差分

`personal` の Mac で、`dev` 専用のものが入っていないことを確認します（逆も同様）。

```bash
brew list --formula gh                  # personal: 見つからない
brew list --cask docker-desktop         # personal: 見つからない
mas list | grep -i xcode                # personal: 出力なし
```

期待: [basic-design.md](basic-design.md) の 4.4 の表のとおり。ホスト名の用途名も確認する（TC-09）。

### TC-21 冪等性

同じプロファイルで 2 回続けて実行し、2 回目の changed を確認します。

| role | 2 回目の changed の期待値 |
| --- | --- |
| `homebrew` | `brew update` で更新があったときだけ changed。導入済みの formula / cask は ok |
| `mas` | 取得済みでも changed と表示される（KI-06） |
| `xcode` | `brew update` 由来の changed のみ |
| `pleiades` / `filezilla` | ok（取得済み） |
| `macos` | ok（設定が一致していれば） |
| `git` | ok |
| `dotfiles` | ok（リンク済み） |
| `mcp` | ok（登録済み） |

期待値は設計から導いたもので、通し実行での実測ではありません。

### TC-22 部分実行

```bash
ansible-playbook site.yml --list-tasks --tags git       # git role の 4 タスクだけ
ansible-playbook site.yml --list-tasks --tags homebrew  # homebrew と xcode の role
```

期待: 指定したタグのタスクだけが対象になる。`make <target>` ではプロファイルが引き継がれないことも確認する（KI-03）。

### TC-23 pkg 系 cask の sudo（askpass）

パスワードを入力して、pkg ベースの cask（例: `microsoft-word`、`docker-desktop`）を導入します。

```bash
ansible-playbook site.yml --tags homebrew -e @vars/dev.yml
ls -d "${TMPDIR%/}"/ansible.*askpass       # 実行後は存在しない
```

期待: `sudo: a terminal is required to read the password` が出ない。実行後に askpass の作業ディレクトリが残らない。

### TC-24 版数の自動追従

`RELEASE_PAT` を登録したあとに、[operations.md](operations.md) の 4.3 のテスト用 dispatch を送ります。

期待: `auto/filezilla-<version>` のブランチと PR が作られ、変更が `group_vars/all.yml` の 1 行だけである。確認後は PR を閉じる。
現状は `RELEASE_PAT` が未登録のため未達（KI-01）。

### TC-25 秘密情報の非残存

```bash
grep -n '\.secrets\.env' ~/.claude.json       # リテラルの $HOME/.secrets.env のみ。トークンの値がない
ls -d "${TMPDIR%/}"/ansible.*askpass          # 存在しない
```

期待: 実行ログにパスワードが出ない（`no_log`）。`~/.claude.json` にトークンの値が焼き込まれていない。

## 5. 変更の種類ごとの確認

| 変更 | 最低限の確認 |
| --- | --- |
| パッケージ・アプリの追加削除 | TC-01、TC-04、該当の TC-07 / TC-15、`catalog.md` の更新 |
| role のタスク変更 | TC-01、TC-03、TC-04、該当 role の TC、TC-21 |
| プロファイルの変更 | TC-04（両プロファイル）、TC-20 |
| MCP サーバの追加・変更 | TC-03（行長）、TC-14、TC-25 |
| `Makefile` の変更 | TC-22、`make -n <target>` |
| ワークフローの変更 | TC-01、TC-03、TC-24 |
| ドキュメントのみ | PR の Markdown プレビューで、Mermaid の描画・表・リンクを確認する |

## 6. 検証の記録

この文書を作成した 2026-10-24 に確認した事項です。

| 実施内容 | 結果 |
| --- | --- |
| `ansible-playbook site.yml --syntax-check -e @vars/dev.yml`（`personal` も） | 成功 |
| `yamllint .` | warning 3 件（`roles/mcp/defaults/main.yml` の 25・102 行目、更新ワークフローの 107 行目） |
| 変数展開の件数 | formula は共通 21 / `dev` 38 / `personal` 21、cask は 24 / 28 / 27、MAS は 4 / 8 / 6 |
| `make -n xcode`、`make -n mcp` | `Nothing to be done` / `No rule to make target` |
| `ansible-playbook site.yml --check -e @vars/dev.yml`（検証に使った Mac） | `macos : Set Dock icon size` で失敗（KI-14） |
| `--check --tags git` / `dotfiles` / `mcp` | 完走 |
| `--check` で非空パスワードを渡して `homebrew` | askpass の書き込みで失敗（KI-02） |
| `--check` で空パスワードを渡して `macos`（`/etc/hosts`） | `sudo: a password is required` で失敗（KI-02） |
| 更新ワークフローの実行履歴 | 4 件すべて失敗。`gh secret list` は空（KI-01） |
| `main` のブランチ保護 | なし（ruleset もなし） |

新規の Mac での通し実行（`make init` → `make dev` / `make personal`）は、この時点では実施していません。
