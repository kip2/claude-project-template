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

### セキュリティ

- 2026-10-24: 安全フックで止めるもの：権限昇格、ディスク操作、電源操作、取得したスクリプトの即実行、再帰的な削除・ワイルドカード付きの削除・ゴミ箱、git の破壊的な操作、git のフックを飛ばす操作、main / develop への直接の push・commit・取り込み、PR のマージ、リポジトリやブランチ保護の変更、認証情報の読み取り。
- 2026-10-24: 権限チェックを飛ばすモードを禁止。利用状況の送信を停止。
