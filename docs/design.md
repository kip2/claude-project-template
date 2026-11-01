# 設計

| 項目 | 内容 |
|---|---|
| 最終更新 | 2026-11-01 |

## 1. 目的

- 新しいプロジェクトを始めるたびに、安全ルールやドキュメントの雛形を作る手間をなくす。
- 別の PC でも同じ環境を再現できるようにする。
- git のブランチ運用（main / develop の保護、作業ブランチから PR）を、すべてのプロジェクトで守らせる。

## 2. 2 層構成

| 層 | 置き場所 | 効く範囲 | 中身 |
|---|---|---|---|
| ユーザー全体 | `~/.claude/` | その PC のそのユーザーの、すべての Claude Code | どこで効いても困らないルール |
| プロジェクト | 各プロジェクトの `.claude/`、`.githooks/` | そのプロジェクトだけ | プロジェクトに合わせたより厳しいルール |

**サンドボックスをユーザー全体で有効にしない理由**

- Linux のサンドボックス内では Unix ソケットが遮断されるため、`hyprctl` などのデスクトップの設定作業が動かない。
- サンドボックス内で書き込めるのは作業中のディレクトリだけなので、`~/.config` などを直す作業が失敗する。
- ユーザー全体の設定で「サンドボックスの外での実行を禁止」にすると、プロジェクト側では解除できない。

## 3. 守りの仕組み

| 仕組み | 強さ | 防げないもの |
|---|---|---|
| CLAUDE.md のルール | お願い | 守らない可能性がある |
| 権限ルール（deny / ask） | 強制。コマンドの **先頭** だけを見る | `cd x && rm -rf y` のような途中のもの |
| 安全フック（`guard-bash.sh`） | 強制。コマンド全体を正規表現で見る | 書き方を工夫した（難読化した）コマンド |
| サンドボックス（プロジェクト） | 強制。OS レベル | サンドボックスの外で動かすコマンド（git の通信系と一部の gh） |
| git のフック（`.githooks/`） | 強制。Claude 以外の操作にも効く | `--no-verify`（Claude には使わせない） |
| GitHub のブランチ保護 | 強制。GitHub 上 | 無料プランの Private リポジトリでは使えない |
| push 前の保護の確認（安全フック） | 強制。GitHub の設定を実行の直前に確認する | 確認したあとに GitHub の設定が変わった場合 |

## 4. 主な決定事項

| 決定 | 理由 |
|---|---|
| 再帰的な削除（`rm -r`）・ワイルドカード付きの `rm`・ゴミ箱に入れるコマンドを禁止。ファイルは 1 つずつ確認して消し、フォルダはユーザーが消す | 元に戻せない一括削除を防ぐ。ゴミ箱も、消す前に確認することに統一するため使わない |
| main / develop への直接の push・commit を禁止。作業ブランチから develop への PR で取り込み、マージは人が行う | 変更を必ず PR で見てから取り込むため |
| main / develop にいるときの merge / cherry-pick / revert / am / rebase も禁止 | 手元の main / develop に直接変更を入れないため（`git pull` は許可） |
| 最初のコミット（コミットが 1 つもないリポジトリ）だけは main で許可 | develop を作るため |
| main / develop の最初の push はユーザーが `--no-verify` で行う | git のフックが止めるため。Claude には `--no-verify` を使わせない |
| `core.hooksPath` は `.githooks` にだけ設定できる | git のフックを Claude が外せないようにするため |
| `.githooks` の作成と `git config core.hooksPath .githooks` はユーザーが行う | ユーザー全体で `Edit(./.githooks/**)` を拒否しているため、サンドボックスがそのパスを塞ぎ、Claude は作れない。また、サンドボックスは `.git/config` への書き込みを保護している。どちらも、Claude が git のフックを外せないようにする仕組みとして意図どおり |
| 雛形の `.gitignore` に「サンドボックスの目印」（`.bashrc`、`.gitconfig`、`.vscode` など）を入れる | サンドボックスは書き換えを禁止したファイルを空の特殊ファイルで塞ぐ。git がこれを拾うと `git add -A` が失敗するため |
| PR のマージ、リポジトリの削除・設定変更、ブランチ保護の変更は Claude に禁止 | 取り込みや公開範囲・保護の判断は人が行うため |
| 権限チェックを飛ばすモードを禁止 | すべての確認が素通りになるため |
| テンプレートリポジトリは Public にする | 無料プランで GitHub のブランチ保護を使うため |
| プロジェクトのサンドボックスで、`git push` / `fetch` / `pull` と、`gh` の一部（PR の作成・閲覧、リポジトリの作成、ログイン状態の確認）は外で動かす | サンドボックス内では gh の認証情報を読めないため。広い指定（`gh *`）は避けた |
| `pacman` / `yay` / `systemctl` は、ユーザー全体では「確認」、プロジェクトでは「拒否」 | デスクトップの設定作業では必要になるため |
| 環境変数の例ファイルは `env.example`（`.env.example` ではない） | `.env.*` を一律に読み書き禁止にしているため |
| 利用状況の送信を停止、履歴は 180 日 | ユーザーの希望 |

## 5. Trail of Bits の設定から取り込まなかったもの

- macOS 用のパス（`~/Library/...`）。Linux なので意味がない。Linux のパスワード保管庫（`~/.local/share/keyrings`）に置き換えた。
- `~/.npm/**` の読み取り禁止。npm のエラーログの確認に必要なため。認証情報の入る `~/.npmrc` は禁止した。
- エージェントチームの実験的な設定と、ステータスライン。安全とは関係ないため。

## 6. GitHub 側の守りと、その確認

### 6.1 考え方

- **本当の守りは GitHub 側に置く**：ブランチ保護（ruleset）と、権限を絞った Claude 用のトークン。PC 側の設定がすり抜けられても、ここで止まる。
- **ローカルは、それを確認して補う**：GitHub 側の守りが有効なことを、Claude が push する前に安全フックで確かめる。
- **トークンを Claude から隠し切ろうとしない**：Claude は、トークンを使う道具（gh / git）を実行できる。そのため、トークンの文字列を完全に隠すことは難しい。トークンを渡す仕組み（ラッパー）は入れず、「漏れても被害が小さいトークン」にする。

### 6.2 push 前の保護の確認（安全フック）

- **対象**：`git push`、`gh pr create`。
- **確認する内容**（push 先リポジトリの main と develop）：

  | 確認項目 | 足りないときに起きること |
  |---|---|
  | `pull_request`・`non_fast_forward`・`deletion` のルールがかかっている | PR を経ずに入れる。強制 push やブランチ削除ができる |
  | ruleset が `active`（`evaluate` ではない） | ルールがあっても何も止めない |
  | 自分が例外（bypass）になっていない（`current_user_can_bypass` が `never`） | 管理者が例外だと、Claude の操作も素通りする |
  | 無料プランの Private リポジトリではない | ルールが効かない |

- **使う API**：ブランチにかかっているルールは `GET /repos/{owner}/{repo}/rules/branches/{branch}` で取る（読み取り権限で使える）。
- **足りないとき**：コマンドを止め、GitHub の画面のどこで何を設定すればよいかを表示する。Claude はそれをユーザーに伝える。
- **確認できないとき**（オフライン、認証切れ、API のエラー）：コマンドを止め、ユーザーに聞く。黙って通さない。
- **頻度**：毎回確認する。
- **限界**：確認するのは実行の直前の状態。そのあとに GitHub の設定が変わった場合は追えない。

### 6.3 Claude 用のトークン（Fine-grained PAT）

- ユーザーが GitHub の画面で発行する。Claude にトークンの文字列を見せない。
- **対象**：Claude に作業させるリポジトリだけ。
- **権限**：Contents（読み書き）、Pull requests（読み書き）、Metadata（読み取り）だけ。Administration と Workflows は付けない。
- **有効期限**：30〜90 日。
- **できなくなること**：リポジトリの作成、設定やブランチ保護の変更、ワークフローの変更。これらはユーザーが行う。
- ユーザー自身の gh のログイン情報（`~/.config/gh`）は権限が広いので、これまでどおり Claude には読ませない。

### 6.4 GitHub 側で追加する設定（ユーザーが画面で行う）

| 設定 | 場所 | 理由 |
|---|---|---|
| シークレットスキャンの push 保護 | Settings → Code security | トークンなどを含む push を GitHub が止める |
| Actions の既定の権限を読み取りのみにする。Actions による PR の作成・承認を許可しない | Settings → Actions → General | ワークフロー経由で権限が広がるのを防ぐ |
| 既定のブランチを develop にする | Settings → General | PR の向き先の間違いを防ぐ |
| 自動マージをオフにする | Settings → General | Claude が PR に自動マージを仕込めないようにする |
| メールアドレスを含む push を拒否する | 個人の Settings → Emails | 個人のメールアドレスの公開を防ぐ |

これらは `/new-project` の手順に入れ、`/safety-rules` の点検で確認できるものは確認する。

### 6.5 ローカルの権限ルールの追加

| 区分 | コマンド |
|---|---|
| 許可（読み取りだけ） | `gh pr view` / `gh pr list` / `gh pr checks` / `gh run view` / `gh issue view` |
| 確認を出す | `git push`（作業ブランチだけ）、`gh pr create`、`gh pr comment`、`gh pr edit`、`gh pr ready` |
| 禁止（追加） | `gh auth token`・`gh auth login`・`gh auth logout`、`gh secret`、`gh api` の書き込み（`-X` / `--method` で GET 以外）、`gh release delete`、`gh workflow run`、`gh repo set-default`、`gh ruleset`、`git remote add` / `set-url`、`git config credential.*` |
| 禁止（今までどおり） | PR のマージ、リポジトリの削除・設定変更、ブランチ保護を変える API、強制 push、main / develop への push |

### 6.6 その他

- **pre-push でのシークレット検査**：`.githooks/pre-push` で gitleaks を動かす。GitHub 側の push 保護と二重にする。gitleaks のインストールと `.githooks` の変更はユーザーが行う。
- **トークンの期限の管理**：GitHub の API の応答には、トークンの期限（`github-authentication-token-expiration`）が入る。`/safety-rules` の点検で残りの日数を表示し、7 日を切ったら知らせる。

### 6.7 トークンの使わせ方

- この PC の gh のログインそのものを、Claude 用のトークンにする（`gh auth login --with-token`）。git も gh 経由で同じトークンを使う。
- ユーザーはローカルの gh をほとんど使わないため、ユーザー側の権限も狭くてよい。リポジトリの作成、ブランチ保護の登録、設定の変更は GitHub の画面で行う。
- トークンの対象は「選んだリポジトリだけ」なので、新しいリポジトリを作るたびに、ユーザーが GitHub の画面でトークンの対象に足す。

### 6.8 実装の形

- 保護の確認は `check-remote-protection.sh`（`~/.claude/hooks/`）にまとめ、安全フックと `/safety-rules` の点検の両方から呼ぶ。
- 確認する相手は、`git push` なら push 先のリモート（指定がなければ現在のブランチの upstream、なければ origin）、`gh pr create` なら `-R` で指定したリポジトリ（指定がなければ gh の既定、upstream、origin の順）。
- 安全フックの時間切れ（タイムアウト）は 10 秒から 30 秒に延ばす。GitHub への問い合わせを毎回行うため。時間切れのときもコマンドは止まる。
- Private リポジトリは、無料プランかどうかを確かめられないため、常に止める（ユーザーに聞く）。
- 見るのは ruleset だけ。昔からのブランチ保護（classic branch protection）は読むのに Administration の権限が要るため、見ない（ruleset がなければ「足りない」と判定する）。
- テストでは、本物の gh の代わりに偽の gh（`PATH` の先頭に置く）を使い、ネットワークに出ずに GitHub 側の状態を切り替える。
- `gh api` の書き込みは、`-X` / `--method` で GET・HEAD 以外を指定した場合に加え、`-f` / `-F` / `--input` で値を渡した場合（gh が自動で POST にする）も止める。

### 6.9 要検証（実際の環境で確かめる）

- 安全フックの中から gh を使えるか。フックはサンドボックスの外で動くはずだが、プロジェクト（サンドボックスあり）で実際に試す。
- `current_user_can_bypass` が、Claude 用のトークン（Administration なし）でも読めるか。読めないときは「確認できない」として止まるので、トークンに Administration（読み取りだけ）を足すかを決める。
