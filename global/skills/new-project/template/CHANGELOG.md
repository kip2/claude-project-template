# 変更履歴

形式は [Keep a Changelog](https://keepachangelog.com/ja/1.1.0/) に準拠する。
分類: 追加 / 変更 / 修正 / 削除 / セキュリティ

## [Unreleased]

### 追加

- {{DATE}}: プロジェクトの雛形を作成（claude-project-template の new-project スキル）。
  - ドキュメント: 要件定義・基本設計・詳細設計・使い方・Q&A ログ・安全ルール・変更履歴
  - Claude Code の作業ルール（`CLAUDE.md`）
  - git のブランチ運用（main / develop の保護、`.githooks/`）

### セキュリティ

- {{DATE}}: プロジェクト用の安全設定を追加。
  - サンドボックス（書き込みはプロジェクト内のみ、通信は許可したドメインのみ）
  - 権限ルール（パッケージ操作の禁止、通信・依存追加・commit の事前確認）
  - git のフック（main / develop への直接の push・commit を拒否）
