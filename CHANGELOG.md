# 変更履歴

形式は [Keep a Changelog](https://keepachangelog.com/ja/1.1.0/) に準拠する。
分類: 追加 / 変更 / 修正 / 削除 / セキュリティ

## [Unreleased]

### 追加

- 2026-10-24: 最初の版。
  - ユーザー全体の安全設定（`global/settings.json`）と安全フック（`global/hooks/guard-bash.sh`）
  - `/new-project` スキル：ドキュメント一式・サンドボックス・git のブランチ運用付きのプロジェクトを作る
  - `/safety-rules` スキル：安全ルールの一覧・追加・削除・点検、`docs/05_safety.md` の自動生成
  - 安全フックのテスト（92 件）
  - このリポジトリ自体のブランチ保護（`.githooks/`、`.github/rulesets/`）
- 2026-11-01: `github-setup.sh`：新しいプロジェクトを GitHub に上げ、ブランチ保護・シークレットスキャンの push 保護・Actions の権限・既定のブランチ・自動マージを 1 回で設定するスクリプト（ユーザーが実行）。管理用のログインはスクリプトの間だけ。トークンの対象への追加はブラウザを開いて案内する。Private（無料プラン）では使えない設定を飛ばして続ける。

### 変更

- 2026-10-24: line-bot で行っていた相談の記録（`docs/setup_plan.md`、`docs/qa_log_line-bot.md`）を、このリポジトリに移した。
- 2026-10-24: `/new-project` の手順を、`.githooks` の作成と `git config core.hooksPath` をユーザーが行う形に変更（Claude はサンドボックスと安全設定により行えないため）。雛形の `.gitignore` に、サンドボックスの目印のファイルを追加。

- 2026-11-01: 設計書に「GitHub 側の守りと、その確認」（6 章）を追加。
- 2026-11-01: この PC の gh を、Claude 用の権限を絞ったトークン（Fine-grained PAT）でログインする運用に変更。`/new-project` の GitHub の手順を、リポジトリの作成・リモートの追加・ブランチ保護をユーザーが行う形に変更。README に「Claude 用のトークン」を追加。
- 2026-11-01: `/safety-rules` の一覧表示に「GitHub」欄を追加（push 先の保護、トークンの残り日数）。
- 2026-11-01: 安全フックの時間切れを 10 秒から 30 秒に延長（GitHub への問い合わせのため）。
- 2026-11-01: `/new-project` の GitHub の手順を、`github-setup.sh` を使う形に変更。Private も選べるようにした。

### セキュリティ

- 2026-10-24: 安全フックで止めるもの：権限昇格、ディスク操作、電源操作、取得したスクリプトの即実行、再帰的な削除・ワイルドカード付きの削除・ゴミ箱、git の破壊的な操作、git のフックを飛ばす操作、main / develop への直接の push・commit・取り込み、PR のマージ、リポジトリやブランチ保護の変更、認証情報の読み取り。
- 2026-10-24: 権限チェックを飛ばすモードを禁止。利用状況の送信を停止。
- 2026-11-01: push / PR 作成の前に、安全フックが GitHub 側のブランチ保護（PR 必須・強制 push 禁止・削除禁止、Active、自分が例外でない、Public）を確認する（`check-remote-protection.sh`）。足りないとき・確認できないときは止める。
- 2026-11-01: 安全フックと権限ルールで止めるものを追加：`gh auth token / login / logout` など、`gh secret / variable`、`gh api` の書き込み（GET 以外、`-f` / `-F` / `--input` を含む）、リリースの作成・変更・削除、ワークフローの実行、`gh repo set-default`、`gh ruleset`、リモートの追加・変更、git の認証情報・push 先 URL の設定。テストは 141 件。
- 2026-11-01: 読み取りだけの gh（PR・CI の結果・Issue の閲覧）を許可。PR のコメント・編集・ready は確認を出す。プロジェクトのサンドボックスの外で動かすコマンドに、これらを追加し、`gh repo create` を外した。
- 2026-11-01: 雛形の git の pre-push フックで、gitleaks による秘密情報の検査を行う（ユーザーが入れる）。
- 2026-11-01: Private で GitHub 側の保護がないリポジトリでは、Claude の push / PR 作成を止めずに、毎回確認を出す（`check-remote-protection.sh` の終了コード 3）。ruleset がある Private（有料プラン）は Public と同じに扱う。
- 2026-11-01: 安全フックと権限ルールで、gh を別のログインやトークンで動かす指定（`GH_CONFIG_DIR=`、`GH_TOKEN=` など）と、`github-setup.sh` の実行を止める。テストは 157 件。
- 2026-11-01: 安全フックのすり抜けを修正（実地の検証で見つかったもの）。判定の前に、引用符・バックスラッシュ・コマンドのパス・git の全体オプション（`-C` / `-c` / `--no-pager` など）を取り除いてから調べる。これまで `git -C . push` は push と判定されず、main / develop の確認と GitHub 側の保護の確認を飛ばしていた。あわせて `$(gh auth token)` のような書き方、`gh auth status --show-token`、`git credential`、`gh alias set / import`、`gh extension install / upgrade / exec`、`git -c` での認証情報・push 先の指定を止める。権限ルールにも同じ禁止と、`git -C * push *` / `git -c * push *` の確認を追加。テストは 196 件。
