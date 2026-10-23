# 既知の課題と改善候補

| 項目 | 内容 |
| --- | --- |
| 最終更新 | 2026-10-24（`main` @ `666591a` 時点） |
| 確認環境 | ansible-core 2.21.5、community.general 12.6.1、macOS（検証に使った 1 台の Mac） |
| 扱い | ドキュメント作成時の調査で確認した事項です。**コードは変更していません**。直したら、該当の項目を削除してください |

重要度の基準は次のとおりです。

- **高**: 実行が止まる、または意図した動作をしない
- **中**: 動くが、誤解や見落としにつながる
- **低**: 影響が小さい、または将来の問題

## 一覧

| ID | 重要度 | 概要 |
| --- | --- | --- |
| [KI-01](#ki-01-版数追従ワークフローが毎回失敗する) | 高 | 版数追従ワークフローが毎回失敗する（`RELEASE_PAT` 未登録） |
| [KI-02](#ki-02-ドライランが完走しない) | 高 | ドライラン（`make check-*`）が完走しない |
| [KI-03](#ki-03-部分実行ターゲットがプロファイルを引き継がない) | 高 | 部分実行ターゲットがプロファイルを引き継がない |
| [KI-14](#ki-14-dock-の-tilesize-が-float-だと-macos-role-が失敗する) | 高 | Dock の `tilesize` が float だと `macos` role が失敗する |
| [KI-04](#ki-04-make-xcode-が何もしないmake-mcp-がない) | 中 | `make xcode` が何もしない / `make mcp` がない |
| [KI-05](#ki-05-ci-の-ansible-lint-が赤main-に保護がない) | 中 | CI の ansible-lint が赤、`main` に保護がない |
| [KI-06](#ki-06-mas-get-が常に-changed-になりsudo-要求を握りつぶす) | 中 | `mas get` が常に changed になり、sudo 要求を握りつぶす |
| [KI-07](#ki-07-gitconfig-が二重管理になっている) | 中 | `~/.gitconfig` が二重管理になっている |
| [KI-08](#ki-08-dev-では-secretsenv-が自動配置されない) | 中 | `dev` では `~/.secrets.env` が自動配置されない |
| [KI-09](#ki-09-github-mcp-は-docker-前提だが-personal-に-docker-がない) | 中 | `github` MCP は Docker 前提だが `personal` に Docker がない |
| [KI-10](#ki-10-askpass-の一時ディレクトリが中断時に残る) | 中 | askpass の一時ディレクトリが中断時に残る |
| [KI-11](#ki-11-homebrew_upgrade_all-は未使用) | 低 | `homebrew_upgrade_all` は未使用 |
| [KI-12](#ki-12-homebrew-の存在判定が-apple-silicon-固定) | 低 | Homebrew の存在判定が Apple Silicon 固定 |
| [KI-13](#ki-13-ダウンロードの完全性を検証しない) | 低 | ダウンロードの完全性を検証しない |

## KI-01 版数追従ワークフローが毎回失敗する

| 項目 | 内容 |
| --- | --- |
| 事象 | `Update mac app version` が `repository_dispatch` で起動するものの、最初の checkout で `##[error]Input required and not supplied: token` となり失敗する |
| 確認 | 実行履歴 4 件（2026-07-15、2026-08-19、2026-08-26、2026-10-16）がすべて失敗。後の 2 件はログでエラー文言を確認 |
| 原因 | `secrets.RELEASE_PAT` が未登録。2026-10-24 時点で Secrets にあるのは `WIKI_TOKEN`（Wiki ミラー用）だけで、`RELEASE_PAT` とは別のシークレット（`gh secret list` で確認） |
| 影響 | Jenkins が Nexus に新版を置いても追従 PR が作られない。2026-10-24 時点で、Nexus には FileZilla 3.71.0 / 3.71.1 と Pleiades 2026-06 / 2026-09 があるが、`group_vars/all.yml` は FileZilla 3.70.6 と Pleiades 2026-03 のまま（失敗した 4 回の実行は、これらの格納時刻と一致する）。Jenkins は dispatch が GitHub に受理された時点で成功と見なし、受信側（Actions）の失敗を知らないため、気付きにくい |
| 対応 | `RELEASE_PAT`（`repo` スコープの PAT）を登録する。値はコマンドラインや会話に書かず、対話入力で貼り付ける<br/>`gh secret set RELEASE_PAT --repo YukiOno-1015/ansible-mac` |
| 確認方法 | [operations.md](operations.md) の「版数の更新」にあるテスト用 dispatch で PR が作られること |
| 参考 | 追従の仕組みは [basic-design.md](basic-design.md) の 8.2 |

登録したあと、取り残された更新は、最新の版を指定して dispatch すれば反映できます。失敗した実行の再実行は、30 日を過ぎたものにはできません。
次の値は 2026-10-24 時点の Nexus の最新です。実行前に Nexus と `group_vars/all.yml` を見直してください。

```bash
echo '{"event_type":"update-filezilla","client_payload":{"version":"3.71.1","jenkins":"manual"}}' \
  | gh api repos/YukiOno-1015/ansible-mac/dispatches --input -
echo '{"event_type":"update-pleiades","client_payload":{"release":"2026-09","buildDate":"20261016","jenkins":"manual"}}' \
  | gh api repos/YukiOno-1015/ansible-mac/dispatches --input -
```

## KI-02 ドライランが完走しない

`make check-dev` / `make check-personal`（`--check`）は、現状では検証手段として使えません。
2026-10-24 に、実際の role を使って次を確認しました。

| # | 事象 | 原因 |
| --- | --- | --- |
| 1 | パスワードを入力すると `Write sudo password file and askpass helper` が `object of type 'dict' has no attribute 'path'` で失敗する | check モードでは `tempfile` がスキップされ、`homebrew_cask_askpass.path` が未定義になる |
| 2 | パスワードを空にすると `Manage internal *.sk4869.info entries in /etc/hosts` が `sudo: a password is required` で失敗する | `become: true` のタスクは check モードでも昇格が必要で、パスワードがない |
| 3 | `Install Homebrew packages` などが常に `changed` になり、差分が分からない | `update_homebrew: true` のとき、`homebrew` モジュールは check モードで `Homebrew would be updated.` を返して終了し、パッケージの状態を調べない |
| 4 | ホスト名・jenv・MCP・dotfiles・MAS の差分が見えない | `command` / `shell` は check モードでスキップされる（`mas` は明示的にスキップ） |

| 項目 | 内容 |
| --- | --- |
| 影響 | 変更を実機に適用する前の確認ができない |
| 回避 | 対象を絞った `--check` は使える（例: `ansible-playbook site.yml --check --tags git -e @vars/dev.yml`）。cask の導入状況は `Install Homebrew casks` の結果で分かる |
| 対応案 | askpass 系タスクに `when: not ansible_check_mode` を付ける。読み取り専用の `command` に `check_mode: false` を付ける。`update_homebrew` を check モードで外す。`/etc/hosts` の昇格をどう扱うか決める |

## KI-03 部分実行ターゲットがプロファイルを引き継がない

| 項目 | 内容 |
| --- | --- |
| 事象 | `make homebrew` / `mas` / `pleiades` / `filezilla` / `macos` / `git` / `dotfiles` は `-e @vars/<profile>.yml` を渡さない |
| 影響 | **`make macos` を実行すると、用途名（`DEV` / `OA`）が消えてホスト名が変わる**<br/>`make pleiades` は `pleiades_enabled: false` のため何もしない<br/>`make homebrew` / `make mas` は共通セットだけを導入する<br/>`make dotfiles` は `personal` でも `--restore-secrets` を付けない |
| 回避 | プロファイルを付けて直接実行する<br/>`ansible-playbook site.yml --tags macos -e @vars/dev.yml` |
| 対応案 | `make macos PROFILE=dev` のように `PROFILE` 変数を受け取り、`-e @vars/$(PROFILE).yml` を付ける |
| 参考 | [detailed-design.md](detailed-design.md) の 1.3 |

## KI-14 Dock の `tilesize` が float だと `macos` role が失敗する

| 項目 | 内容 |
| --- | --- |
| 事象 | `Set Dock icon size` が `Type mismatch. Type in defaults: float` で失敗する |
| 確認 | 2026-10-24、検証に使った Mac で `--check` を実行して確認。この Mac の `defaults read-type com.apple.dock tilesize` は `float` |
| 原因 | `osx_defaults` は、指定した型（`type: int`）と既存値の型が違うと失敗する（`check_type` の既定は `true`）。Dock が `tilesize` を float で保存している環境で起きる |
| 影響 | play が停止し、`macos` role の残り（スクリーンショット、ホスト名、`/etc/hosts`）と、後続の `git` / `dotfiles` / `mcp` が実行されない。check モードでも実行時でも同じ |
| 回避 | `defaults delete com.apple.dock tilesize` を実行してから再実行する（Dock のサイズが既定に戻る） |
| 対応案 | `type: float` にする。既存値が int の環境では逆に不一致になるため、`check_type: false` も選択肢。要検証 |

## KI-04 `make xcode` が何もしない／`make mcp` がない

| 項目 | 内容 |
| --- | --- |
| 事象 | `make xcode` は何も実行せずに成功する（`make: Nothing to be done for 'xcode'.`）。`make mcp` は `No rule to make target` になる |
| 原因 | コミット `07da4e8` で `xcode:` のレシピが削除されたが、`.PHONY`、`help`、README の記載が残った。`mcp` role は後から追加され、ターゲットが作られていない |
| 回避 | `ansible-playbook site.yml --tags xcode -e @vars/dev.yml`<br/>`ansible-playbook site.yml --tags mcp` |
| 対応案 | ターゲットを復活させる、または記載を削除する |

## KI-05 CI の ansible-lint が赤、`main` に保護がない

| 項目 | 内容 |
| --- | --- |
| 事象 | `ansible-lint` が `yaml[line-length]`（120 文字超）3 件で失敗し続けている |
| 違反箇所 | `roles/mcp/defaults/main.yml` の 25 行目（140 文字）と 102 行目（133 文字）、`.github/workflows/ansible-mac-update-mac-app-version.yml` の 107 行目（132 文字） |
| 原因 | `.yamllint` は行長を warning にしているが、`ansible-lint` の `basic` プロファイルは同じ違反をエラーにする。`mcp` role の追加（PR #5）以降ずっと赤 |
| 影響 | `main` の CI が常に赤で、新しい違反が埋もれる。`main` にブランチ保護も ruleset もなく、CI は必須チェックになっていない（2026-10-24 時点） |
| 対応案 | 長い行を折り返す。または `.ansible-lint` の `warn_list` に `yaml[line-length]` を加える。そのうえで CI を必須チェックにする |

## KI-06 `mas get` が常に changed になり、sudo 要求を握りつぶす

| 項目 | 内容 |
| --- | --- |
| 事象 | `changed_when: rc == 0` のため、取得済みでも常に changed と表示される。`failed_when` が `sudo: a password is required` を失敗扱いから除外するため、取得できていなくても成功になる |
| 影響 | 冪等性の確認が難しい。失敗を見落とす |
| 回避 | 実行後に `mas list` で導入状況を確認する |
| 対応案 | `mas list` の結果から未導入のものだけ `mas get` する |

## KI-07 `~/.gitconfig` が二重管理になっている

| 項目 | 内容 |
| --- | --- |
| 事象 | `git` role は `git config --global` で `user.name` / `user.email` / `init.defaultBranch` / `core.editor` を設定する。一方、dotfiles の `home/.gitconfig` も同じキーを持ち、`dotfiles` role（`git` の後）が `~/.gitconfig` をそのファイルへのシンボリックリンクにする |
| 影響 | 展開後の実効値は dotfiles 側の内容で決まる。値が食い違うと、どちらが効くか分かりにくい |
| 対応案 | どちらかに一本化する（例: ユーザー情報を `group_vars/all.yml` だけに置き、dotfiles 側から外す） |

## KI-08 `dev` では `~/.secrets.env` が自動配置されない

| 項目 | 内容 |
| --- | --- |
| 事象 | `vars/dev.yml` は `dotfiles_install_command` を上書きしないため、`./install.sh` だけが走り、Vault からの復元がない。`personal` は `--restore-secrets` を付ける。一方 `mcp` role は全プロファイルで走り、`github` / `backlog` / `qiita` / `n8n-mcp` が `~/.secrets.env` を読み込む |
| 影響 | 新しい `dev` の Mac では、これらの MCP サーバが認証情報なしで起動する |
| 回避 | Vault にログインしたあと `cd ~/dotfiles && ./install.sh --restore-secrets` を手動で実行する |
| 対応案 | `dev` でも `--restore-secrets` を付ける。意図した運用なら、手順として [operations.md](operations.md) に残す |

## KI-09 `github` MCP は Docker 前提だが `personal` に Docker がない

| 項目 | 内容 |
| --- | --- |
| 事象 | `github` MCP は `docker run ... ghcr.io/github/github-mcp-server` で起動する。`docker` / `docker-desktop` は `dev` 専用の cask |
| 影響 | `personal` では登録されても起動できない |
| 回避 | `personal` で使うなら Docker を別途導入する |
| 対応案 | `mcp_servers` をプロファイル別にする。または Docker を共通セットへ移す |

## KI-10 askpass の一時ディレクトリが中断時に残る

| 項目 | 内容 |
| --- | --- |
| 事象 | 作業ディレクトリの削除（`Remove askpass work directory`）は通常のタスクで、`block` / `always` ではない。実行を中断（Ctrl-C）するなどして play が止まると、パスワードを平文で含む `secret`（0600）が、ディレクトリ（0700）ごと残る |
| 影響 | 平文のパスワードが一時領域に残る（所有ユーザーだけが読める） |
| 回避 | 中断した後は、存在を確認して削除する<br/>`ls -d "${TMPDIR%/}"/ansible.*askpass`（内容を確認してから `rm -rf`） |
| 対応案 | `block` / `always` で確実に削除する |

## KI-11 `homebrew_upgrade_all` は未使用

| 項目 | 内容 |
| --- | --- |
| 事象 | `roles/homebrew/defaults/main.yml` で定義されているが、どのタスクも参照しない。以前の README にも説明があった |
| 影響 | `true` にしても何も起きない。`update_homebrew: true` は Homebrew 本体の更新で、導入済みパッケージのアップグレードではない |
| 対応案 | 変数を削除する。または `homebrew` モジュールの `upgrade_all` に渡す |

## KI-12 Homebrew の存在判定が Apple Silicon 固定

| 項目 | 内容 |
| --- | --- |
| 事象 | `homebrew` role は `/opt/homebrew/bin/brew` の有無で導入済みかを判定する |
| 影響 | Intel Mac（`/usr/local/bin/brew`）では毎回インストーラが走る。実際には `make init` が先に導入するため、影響は小さい |
| 対応案 | 両方のパスを調べる |

## KI-13 ダウンロードの完全性を検証しない

| 項目 | 内容 |
| --- | --- |
| 事象 | `pleiades` / `filezilla` role の取得は `creates` だけで判定する。`curl --output` が途中で中断すると部分ファイルが残り、以降は取得がスキップされる |
| 影響 | 壊れた DMG / アーカイブが残る |
| 回避 | 該当ファイルを `~/Downloads` から削除して再実行する |
| 対応案 | 一時ファイルに取得してから移動する。またはチェックサムで検証する |

## 改善候補

不具合ではないが、手を入れる価値のある項目です。

| 項目 | 内容 |
| --- | --- |
| GitHub Actions のバージョン | CI のログに「`actions/checkout@v4`・`actions/setup-go@v5`・`actions/setup-python@v5` は Node.js 20 を対象としており非推奨」という警告が出ている。更新する |
| CI で使うツールの固定 | `shfmt` は `@latest`、`ansible` / `ansible-lint` / `yamllint` は版指定なし。更新で CI が突然赤くなりうる |
| `RELEASE_PAT` の権限 | 現状は `repo` スコープの PAT。必要最小限の権限（このリポジトリに限定した PAT など）を検討する |
| `WIKI_TOKEN` | 登録されていると、Wiki への書き込みはこの PAT を優先して使う。`GITHUB_TOKEN` だけで書き込めることは確認済みなので、通常は不要。PAT の失効で同期が止まるリスクもあるため、削除を検討する |
| MCP パッケージの固定 | `playwright` と `chrome-devtools` は `@latest`、他も版を固定していない |
| `Makefile` の `.PHONY` | `check-dev` / `check-personal` / `ensure-not-root` が含まれず、存在しない `check` が含まれている |
