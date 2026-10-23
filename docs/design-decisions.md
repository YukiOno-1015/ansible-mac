# 設計判断記録

| 項目 | 内容 |
| --- | --- |
| 最終更新 | 2026-10-24（`main` @ `a5e36ad` 時点） |
| 目的 | 「なぜそうなっているか」を残し、あとから設計を変えるときの判断材料にする |
| 書き方 | 各項目は 状況 → 決定 → 理由 → 帰結 → 根拠 の順。根拠は PR 番号とコミットです |

> 過去の判断を履歴から**後追いで**整理したものです。理由のうち、PR やコミットに明記されていない部分は「推定」と書いています。
> 判断を変えるときは、既存の項目を書き換えず、新しい項目を追加して「置き換え」と明記してください。

## 一覧

| ID | 判断 |
| --- | --- |
| ADR-01 | `localhost` への Ansible 自己適用と Makefile のラッパー |
| ADR-02 | `-e @vars/<profile>.yml` と「共通 + 差分」によるプロファイル |
| ADR-03 | sudo パスワードを `vars_prompt` で 1 回だけ取得し、become と askpass で共用 |
| ADR-04 | Pleiades / FileZilla を社内 Nexus 経由で配布 |
| ADR-05 | 版数の検知を GitHub Actions のポーリングから Jenkins Mirror Pipeline へ移管 |
| ADR-06 | 版数の反映は PR を自動作成し、マージは手動 |
| ADR-07 | MCP サーバを role 化し、冪等に登録し、秘密を埋め込まない |
| ADR-08 | AI ツールを共通セットへ集約 |
| ADR-09 | Homebrew cask を 1 件ずつ導入し、失敗を許容 |
| ADR-10 | OpenJDK を複数バージョン導入して jenv で管理し、Apple Silicon では 8 を除外 |
| ADR-11 | ホスト名を `<デバイス名><用途名><シリアル>` の大文字英数字で生成 |
| ADR-12 | `/etc/hosts` を `blockinfile` で管理し、社内 FQDN を内部 VIP へ向ける |
| ADR-13 | ターミナルを iTerm2 から wezterm へ移行 |
| ADR-14 | Ansible の出力を `default` コールバックと `result_format = yaml` にする |

## ADR-01 `localhost` への Ansible 自己適用と Makefile のラッパー

| 項目 | 内容 |
| --- | --- |
| 状況 | 自分の Mac を、自分で再現可能な状態にしたい |
| 決定 | `inventory/localhost` を `ansible_connection=local` とし、`make` から `ansible-playbook site.yml` を呼ぶ |
| 理由（推定） | 対象が実行する Mac 自身の 1 台で、SSH や別のコントロールノードが要らない。Homebrew や `defaults` には `community.general` のモジュールがあり、冪等に書ける。Makefile でコマンドを短くし、`ensure-not-root` で Homebrew の誤用を防げる |
| 帰結 | 前提として Ansible 自体を導入する必要がある（`make init`）。部分実行ターゲットがプロファイルを引き継がない（[known-issues.md](known-issues.md) の KI-03） |
| 根拠 | 初期コミット `1229373`、`07da4e8`（`ensure-not-root`） |

## ADR-02 `-e @vars/<profile>.yml` と「共通 + 差分」によるプロファイル

| 項目 | 内容 |
| --- | --- |
| 状況 | 開発用と普段使いの境界が曖昧で、意図しないツールが入りやすかった |
| 決定 | 共通要素を `group_vars/all.yml`（`*_common`）に集約し、`vars/dev.yml` と `vars/personal.yml` は差分だけを持つ。プロファイルは `-e @vars/<profile>.yml` で指定する |
| 理由 | PR #1 は「共通要素を `group_vars/all.yml` へ集約」することを挙げている。（推定）重複を排し、差分を見れば違いが分かる。extra vars は優先度が最も高く、`group_vars` の既定をプロファイル側で確実に上書きできる |
| 帰結 | プロファイルを渡さない実行では共通セットだけが見える（KI-03）。共通へ移す変更が随時起きる（Slack / Discord、Claude Code など） |
| 根拠 | PR #1、`cab51ec`（Slack / Discord を共通へ）、PR #5（AI ツールを共通へ） |

## ADR-03 sudo パスワードを `vars_prompt` で 1 回だけ取得し、become と askpass で共用

| 項目 | 内容 |
| --- | --- |
| 状況 | pkg ベースの cask（Microsoft Office など）はインストール中に `sudo` を呼ぶ。Ansible は非対話のため、パスワードが渡らず `sudo: a terminal is required` で失敗した |
| 決定 | `site.yml` の `vars_prompt` で `ansible_become_password` を取得し、Ansible の `become`（`/etc/hosts`）と、Homebrew の `SUDO_ASKPASS` の両方で使う。パスワードは別ファイルに置き、askpass は `cat` するだけにする |
| 理由 | askpass の仕組みは `ansible_become_password` 変数で有効になるが、`--ask-become-pass` はこの変数を設定しないため、常に無効だった。パスワードをスクリプトに埋め込むと `$` や `\` で壊れる |
| 帰結 | 実行の冒頭でパスワードを入力する。一時ファイルが中断時に残る余地がある（KI-10）。check モードで動かない（KI-02） |
| 根拠 | `0cd7775`（`Makefile` の `--ask-become-pass` を削除、`vars_prompt` を追加） |

## ADR-04 Pleiades / FileZilla を社内 Nexus 経由で配布

| 項目 | 内容 |
| --- | --- |
| 状況 | どちらも Homebrew cask にない。配布元からの直接取得は、FileZilla が暗号化された HTML と期限付きの署名 URL、Pleiades は API なしの HTML スクレイピングが前提で、クライアント側で安定して取れない |
| 決定 | 配布物を社内 Nexus の `raw-tools` に置き、`<prefix>/<version>/<filename>` という安定した URL から `curl` で取得する。`release` / `version` / `filename` を別の変数にし、版数を変えるだけで差し替えられるようにする |
| 理由 | 検知と取得の難しさを Jenkins に寄せ、各 Mac の取得は単純にできる |
| 帰結 | Nexus と Jenkins に依存する。インストールは手作業。配布物は Apple Silicon 用だけ |
| 根拠 | PR #1（FileZilla の取得手段が未整備）、PR #2（取得元を Nexus に変更）、`jenkins-cli` の Mirror Pipeline の設計メモ |

## ADR-05 版数の検知を GitHub Actions のポーリングから Jenkins Mirror Pipeline へ移管

| 項目 | 内容 |
| --- | --- |
| 状況 | 初版は、GitHub Actions が cron で Nexus の REST API を直接ポーリングし、最新版を検出していた |
| 決定 | 検知は Jenkins に集約する。Mirror Pipeline が新版を Nexus に置いたとき、`repository_dispatch` でこのリポジトリへ通知する |
| 理由 | PR #2 は「検出は Jenkins に集約」としている。（推定）ミラー（取得元の監視と Nexus への格納）を行う Jenkins が新版を最初に知るため、検知を 2 か所に持たなくて済む |
| 帰結 | Jenkins と GitHub の間に連携が増える。受信側の失敗は Jenkins に伝わらない（KI-01） |
| 根拠 | PR #2（`update-nexus-tools.yml` を廃案）、PR #3（Nexus 監視を Mirror Pipeline に移管） |

## ADR-06 版数の反映は PR を自動作成し、マージは手動

| 項目 | 内容 |
| --- | --- |
| 状況 | 受信した版数を `group_vars/all.yml` に反映する必要がある |
| 決定 | ワークフローが該当の 1〜2 行を書き換えた PR を作る。`RELEASE_PAT` で作成し、マージはオーナーが行う |
| 理由 | `GITHUB_TOKEN` で作った PR では、追従する CI が起動しない。PAT なら起動する |
| 帰結 | `RELEASE_PAT` が必要で、未登録だと動かない（KI-01）。初版にあった CI 通過後の自動マージは、現行のワークフローにはない |
| 根拠 | PR #2、PR #3（必要設定の節）、`6121094`（初版のコミットメッセージ） |

## ADR-07 MCP サーバを role 化し、冪等に登録し、秘密を埋め込まない

| 項目 | 内容 |
| --- | --- |
| 状況 | Claude Code の MCP サーバが 11 種類あり、環境ごとに手作業で登録していた |
| 決定 | `mcp` role が `claude mcp get` で存在を確認し、未登録のものだけ `claude mcp add-json --scope user` で登録する。トークンは設定に書かず、起動コマンドが実行時に `$HOME/.secrets.env` を読み込む。登録時は `expand_argument_vars: false` にする |
| 理由 | 再実行しても重複しない。展開を抑止しないと、トークンが `~/.claude.json` に平文で焼き込まれる。`~/.secrets.env` は dotfiles が配置するため、`mcp` は `dotfiles` の後に置く |
| 帰結 | 登録済みの定義は更新されない（変更時は `remove` してから再実行）。`dev` で `~/.secrets.env` が自動で入らない（KI-08）。`github` は Docker が必要（KI-09） |
| 根拠 | PR #5、PR #6、PR #7 |

## ADR-08 AI ツールを共通セットへ集約

| 項目 | 内容 |
| --- | --- |
| 状況 | `claude-code` と `github-copilot-for-xcode` は `dev` 専用で、`personal` には入らなかった |
| 決定 | Claude・ChatGPT・Codex・Copilot の GUI と CLI を `homebrew_casks_common` にまとめ、全プロファイルに入れる |
| 理由 | 普段使いの Mac でも AI アシスタントを使うため |
| 帰結 | 共通の cask が 24 件に増えた。`mcp` role が `claude` コマンドを使える |
| 根拠 | PR #5 |

## ADR-09 Homebrew cask を 1 件ずつ導入し、失敗を許容

| 項目 | 内容 |
| --- | --- |
| 状況 | cask の中には、sudo や配布元の都合で失敗するものがある |
| 決定 | `homebrew_cask` をループで 1 件ずつ実行し、`ignore_errors: true` にする |
| 理由（推定） | 1 つの失敗で全体を止めず、残りを導入し続ける。失敗した cask は再実行か手動導入で補う |
| 帰結 | 失敗が静かに流れる。実行ログの `...ignoring` を確認する運用になる |
| 根拠 | `roles/homebrew/tasks/main.yml`、README の「それでも特定の cask が失敗する場合は…」 |

## ADR-10 OpenJDK を複数バージョン導入して jenv で管理し、Apple Silicon では 8 を除外

| 項目 | 内容 |
| --- | --- |
| 状況 | 複数の Java バージョンを切り替えて使う。`openjdk@8` は x86_64 専用で、Apple Silicon では入らない |
| 決定 | `homebrew_java_packages` の OpenJDK をまとめて導入し、`jenv add` で登録する。`ansible_architecture` が `x86_64` 以外のときは `openjdk@8` を外す |
| 理由 | Apple Silicon で失敗する formula を最初から対象にしない |
| 帰結 | Intel Mac では 8 も入る。`jenv` を有効にするシェル設定は dotfiles 側にある |
| 根拠 | `cc3630c`（jenv で管理）、`36343cc`（アーキテクチャ別の formula） |

## ADR-11 ホスト名を `<デバイス名><用途名><シリアル>` の大文字英数字で生成

| 項目 | 内容 |
| --- | --- |
| 状況 | 複数の Mac を機種・用途・個体で見分けたい |
| 決定 | `hw.model` の接頭辞から `MACM`（mini）/ `MACB`（MacBook）/ `IMAC` / `MACS`（Studio）/ `MACP`（Pro）を決め、用途名（`DEV` / `OA`）と、シリアル番号の全体を連結する。大文字にし、英数字以外を取り除く。`ComputerName` / `HostName` / `LocalHostName` を同じ値にする |
| 理由（推定） | 機種と用途が名前から分かり、シリアルで個体が一意になる |
| 帰結 | プロファイルを渡さない `make macos` では用途名が消え、名前が変わる（KI-03）。`scutil --set` は `become` なしで実行される（[testing.md](testing.md) の TC-09 で確認） |
| 根拠 | `e83d5af`、`2b97c98`（シリアル全体を使う）、`07da4e8`（大文字・区切りなし） |

## ADR-12 `/etc/hosts` を `blockinfile` で管理し、社内 FQDN を内部 VIP へ向ける

| 項目 | 内容 |
| --- | --- |
| 状況 | 社内向けの `*.sk4869.info` を、Cloudflare を経由せず、LAN の内部 VIP に直接向けたい |
| 決定 | `macos` role が `blockinfile` で、マーカー付きのブロックを `/etc/hosts` に置く。FQDN と VIP は変数で持つ |
| 理由（推定） | 管理するのは自分のブロックだけで、他の行に触らない。再実行しても重複しない |
| 帰結 | `sudo`（become）が必要で、`macos` を単体で実行するときもパスワードが要る。`macos_internal_dns_entries` を空にしてもブロックは消えない |
| 根拠 | PR #1 |

## ADR-13 ターミナルを iTerm2 から wezterm へ移行

| 項目 | 内容 |
| --- | --- |
| 状況 | ターミナルを複数持ちたくない |
| 決定 | iTerm2 を廃止し、`wezterm@nightly` に完全移行する。設定は dotfiles（`wezterm.lua`）で管理する |
| 理由 | 記載は「完全移行」までで、詳細な理由は残っていない |
| 帰結 | 共通セットの cask は `wezterm@nightly` のみ |
| 根拠 | `group_vars/all.yml` のコメント、README の記載 |

## ADR-14 Ansible の出力を `default` コールバックと `result_format = yaml` にする

| 項目 | 内容 |
| --- | --- |
| 状況 | 当初は `stdout_callback = yaml` を使っていた |
| 決定 | `stdout_callback = default` に変え、`result_format = yaml` で YAML 形式の出力にする |
| 理由 | コミットメッセージのとおり「サポートされている YAML 出力」に合わせるため |
| 帰結 | 出力は YAML 形式のまま読みやすい |
| 根拠 | `4afb00b` |
