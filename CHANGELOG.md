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

### 変更

- 2026-10-24: line-bot で行っていた相談の記録（`docs/setup_plan.md`、`docs/qa_log_line-bot.md`）を、このリポジトリに移した。
- 2026-10-24: `/new-project` の手順を、`.githooks` の作成と `git config core.hooksPath` をユーザーが行う形に変更（Claude はサンドボックスと安全設定により行えないため）。雛形の `.gitignore` に、サンドボックスの目印のファイルを追加。

- 2026-11-01: 設計書に「GitHub 側の守りと、その確認」（6 章）を追加。
- 2026-11-01: この PC の gh を、Claude 用の権限を絞ったトークン（Fine-grained PAT）でログインする運用に変更。`/new-project` の GitHub の手順を、リポジトリの作成・リモートの追加・ブランチ保護をユーザーが行う形に変更。README に「Claude 用のトークン」を追加。
- 2026-11-01: `/safety-rules` の一覧表示に「GitHub」欄を追加（push 先の保護、トークンの残り日数）。
- 2026-11-01: 安全フックの時間切れを 10 秒から 30 秒に延長（GitHub への問い合わせのため）。

### セキュリティ

- 2026-10-24: 安全フックで止めるもの：権限昇格、ディスク操作、電源操作、取得したスクリプトの即実行、再帰的な削除・ワイルドカード付きの削除・ゴミ箱、git の破壊的な操作、git のフックを飛ばす操作、main / develop への直接の push・commit・取り込み、PR のマージ、リポジトリやブランチ保護の変更、認証情報の読み取り。
- 2026-10-24: 権限チェックを飛ばすモードを禁止。利用状況の送信を停止。
- 2026-11-01: push / PR 作成の前に、安全フックが GitHub 側のブランチ保護（PR 必須・強制 push 禁止・削除禁止、Active、自分が例外でない、Public）を確認する（`check-remote-protection.sh`）。足りないとき・確認できないときは止める。
- 2026-11-01: 安全フックと権限ルールで止めるものを追加：`gh auth token / login / logout` など、`gh secret / variable`、`gh api` の書き込み（GET 以外、`-f` / `-F` / `--input` を含む）、リリースの作成・変更・削除、ワークフローの実行、`gh repo set-default`、`gh ruleset`、リモートの追加・変更、git の認証情報・push 先 URL の設定。テストは 141 件。
- 2026-11-01: 読み取りだけの gh（PR・CI の結果・Issue の閲覧）を許可。PR のコメント・編集・ready は確認を出す。プロジェクトのサンドボックスの外で動かすコマンドに、これらを追加し、`gh repo create` を外した。
- 2026-11-01: 雛形の git の pre-push フックで、gitleaks による秘密情報の検査を行う（ユーザーが入れる）。
