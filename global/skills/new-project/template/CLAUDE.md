# CLAUDE.md — {{PROJECT_NAME}} の作業ルール

Claude Code はこのファイルを毎セッション読み込む。以下は **必ず守るルール** である。

## 1. 進め方（ドキュメント駆動）

1. 相談・要望を受けたら、まず内容を [docs/04_qa_log.md](docs/04_qa_log.md) に追記する（質問・回答・決定事項）。
2. 実装の前に、関係するドキュメントを更新する。
   - 何を作るか・なぜ → [docs/01_requirements.md](docs/01_requirements.md)
   - どう作るか（全体） → [docs/02_design/basic_design.md](docs/02_design/basic_design.md)
   - どう作るか（詳細） → [docs/02_design/detailed_design.md](docs/02_design/detailed_design.md)
3. 実装する。
4. 使い方が変わったら [docs/03_usage.md](docs/03_usage.md) を更新する。
5. 作業の最後に [CHANGELOG.md](CHANGELOG.md) の `[Unreleased]` に変更内容を追記する。
6. ドキュメントとコードが食い違ったまま作業を終えない。

- 要件が曖昧なときは推測で進めず、質問する。質問と回答は Q&A ログに残す。
- ドキュメントは日本語で書く。日付は `YYYY-MM-DD` 形式。

## 2. git のブランチ運用

- `main`（リリース用）と `develop`（開発の本線）には **直接 push・commit しない**。
- 作業は必ず `develop` から個別のブランチを切って行う。名前は `feature/内容`、`fix/内容`、`docs/内容`。
- 作業ブランチは push してよい。終わったら `develop` に向けた PR を作る（`gh pr create --base develop`）。
- **PR のマージはユーザーが行う。** Claude はマージしない。
- `develop` から `main` へも PR で取り込む。
- これらは安全フックと git のフック（`.githooks/`）でも強制されている。

## 3. 安全ルール（危険な操作をしない）

詳細は [docs/05_safety.md](docs/05_safety.md)。要点：

- **作業範囲はこのプロジェクトディレクトリ内のみ。** 外のファイルを変更しない。
- **禁止**: 権限昇格（`sudo` など）、システムパッケージの操作、git の破壊的な操作（強制 push、`reset --hard`、`clean`、`branch -D`、変更の一括破棄）、取得したスクリプトの即実行、ディスク操作、電源操作。
- **削除**:
  - ファイルは 1 つずつ `rm <ファイル名>` で消す（毎回確認が出る）。ワイルドカードは使わない。
  - **フォルダは Claude が消さない。** 消す候補ごとに、ファイル数・サイズ・git で管理しているか・コミットしていない変更があるかを示し、削除のコマンドをユーザーに渡す。
  - ゴミ箱に入れるコマンド（`gio trash` など）も使わない。
- **秘密情報**: `.env` や鍵ファイルは読まない・表示しない・コミットしない。設定例は `env.example` に書く。
- **事前確認が必要**: ファイル削除、依存パッケージの追加、外部サービスへの送信やデプロイ、git の commit・push。
- 安全設定（`.claude/`、`.githooks/`、`~/.claude/`）を緩める変更は、ユーザーの明示的な指示がある場合のみ行う（safety-rules スキルの手順に従う）。
- サンドボックスを無効化してコマンドを実行しない。
