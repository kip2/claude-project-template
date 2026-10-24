# {{PROJECT_NAME}}

{{SUMMARY}}

## ドキュメント一覧

| ドキュメント | 内容 |
|---|---|
| [docs/01_requirements.md](docs/01_requirements.md) | 要件定義（何を作るか・なぜ作るか） |
| [docs/02_design/basic_design.md](docs/02_design/basic_design.md) | 基本設計（全体構成・技術選定） |
| [docs/02_design/detailed_design.md](docs/02_design/detailed_design.md) | 詳細設計（モジュール・データ・処理の流れ） |
| [docs/03_usage.md](docs/03_usage.md) | 使い方（セットアップ・起動・運用） |
| [docs/04_qa_log.md](docs/04_qa_log.md) | Q&A ログ（相談内容と決定事項） |
| [docs/05_safety.md](docs/05_safety.md) | 安全ルールとサンドボックス |
| [CHANGELOG.md](CHANGELOG.md) | 変更履歴 |
| [CLAUDE.md](CLAUDE.md) | Claude Code 向けの作業ルール |

## ブランチ運用

`main` と `develop` には直接変更せず、`develop` から作業ブランチ（`feature/〜`、`fix/〜`、`docs/〜`）を切って、`develop` への PR で取り込む。

## Claude Code の起動方法（安全モード）

```bash
./scripts/claude-safe.sh
```

詳しくは [docs/05_safety.md](docs/05_safety.md) を参照。
