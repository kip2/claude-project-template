# CLAUDE.md — claude-project-template の作業ルール

このリポジトリは、Claude Code の安全設定とプロジェクトの雛形を管理する。ここを変えると、`~/.claude` に入れた設定や、これから作るすべてのプロジェクトに影響する。

## 1. 進め方

1. 相談・要望を受けたら、まず [docs/qa_log.md](docs/qa_log.md) に追記する。
2. 設計に関わる変更は、先に [docs/design.md](docs/design.md) を更新する。
3. 変更したら [CHANGELOG.md](CHANGELOG.md) の `[Unreleased]` に追記する。
4. `global/hooks/guard-bash.sh` を変えたら、`global/skills/safety-rules/scripts/test-guard.sh` にテストを足し、必ず実行する。

   ```bash
   bash global/skills/safety-rules/scripts/test-guard.sh global/hooks/guard-bash.sh
   ```

5. `global/` を変えても `~/.claude` には自動では入らない。入れる場合は、変更点を示してユーザーの確認を取ってから入れる（README の表のとおり）。

## 2. git のブランチ運用

- `main` と `develop` には直接 push・commit しない。
- `develop` から作業ブランチ（`feature/〜`、`fix/〜`、`docs/〜`）を切り、`develop` への PR を作る。
- **PR のマージはユーザーが行う。**

## 3. 安全ルール

- 安全設定を緩める変更は、ユーザーの明示的な指示がある場合のみ行う。何が危なくなるかを先に説明する。
- **Public リポジトリなので、個人情報を入れない**：メールアドレス、ホームディレクトリの実際のパス（`~` と書く）、個人のプラグイン設定、秘密情報。
- フォルダは Claude が消さない。消す候補と中身を示して、ユーザーに消してもらう。
