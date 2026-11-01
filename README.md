# claude-project-template

Claude Code を **安全に・ドキュメントを残しながら** 使うための、自分用のテンプレート一式。

- **ユーザー全体の安全設定**：権限ルール、危険なコマンドを止める安全フック
- **`/new-project` スキル**：ドキュメント一式・サンドボックス・git のブランチ運用付きのプロジェクトを作る
- **`/safety-rules` スキル**：安全ルールの一覧・追加・削除・点検

前提の環境：Linux（Arch / Omarchy で確認）、Claude Code、bubblewrap、socat、jq、git、gh。

## 何が入っているか

```text
claude-project-template/
├── README.md                         # このファイル
├── CLAUDE.md                         # このリポジトリで作業するときのルール
├── CHANGELOG.md                      # 変更履歴
├── docs/
│   ├── design.md                     # 設計（何を・なぜそうしたか）
│   ├── qa_log.md                     # 相談と決定の記録
│   ├── setup_plan.md                 # 最初の導入計画と導入の記録（line-bot から移管）
│   └── qa_log_line-bot.md            # このリポジトリを作るまでの相談の記録（line-bot から移管）
├── global/                           # ~/.claude に入れるもの
│   ├── settings.json                 #   権限ルール・フックの登録など
│   ├── hooks/
│   │   ├── guard-bash.sh             #   安全フック
│   │   └── check-remote-protection.sh #  GitHub 側の保護の確認（安全フックから呼ぶ）
│   └── skills/
│       ├── new-project/              #   /new-project（雛形一式を含む）
│       │   ├── SKILL.md
│       │   ├── scripts/github-setup.sh #   GitHub に上げて設定するスクリプト（ユーザーが実行）
│       │   ├── template/             #     プロジェクトにコピーするファイル
│       │   └── template-claude/      #     プロジェクトの .claude/ に入れる安全設定
│       └── safety-rules/             #   /safety-rules
│           ├── SKILL.md
│           └── scripts/              #     一覧表示・ドキュメント生成・フックのテスト
├── .githooks/                        # このリポジトリ自体のブランチ保護
└── .github/rulesets/                 # GitHub のブランチ保護の設定
```

## 入れ方（新しい PC など）

シェルスクリプトは使わない。Claude Code にこの README を読ませて、下の表のとおりに入れてもらう（ファイルを書くたびに確認が出るので、内容を見て許可する）。

1. このリポジトリを clone する。
2. 必要なソフトを入れる（自分のターミナルで）：`sudo pacman -S bubblewrap socat jq github-cli gitleaks`
3. Claude Code に「claude-project-template の README のとおりに ~/.claude に入れて」と頼む。

| コピー元 | コピー先 | 注意 |
|---|---|---|
| `global/settings.json` | `~/.claude/settings.json` | **上書きしない**。既にある場合は中身を統合する（既存の `enabledPlugins` などの個人の設定は残す）。統合前の控えを `~/.claude/backups/` に取る |
| `global/hooks/guard-bash.sh` | `~/.claude/hooks/guard-bash.sh` | |
| `global/hooks/check-remote-protection.sh` | `~/.claude/hooks/check-remote-protection.sh` | `guard-bash.sh` と同じフォルダに置く |
| `global/skills/new-project/` | `~/.claude/skills/new-project/` | フォルダごと。`template/` 内の `.githooks` `.github` `.gitignore` などのドットファイルも漏らさない |
| `global/skills/safety-rules/` | `~/.claude/skills/safety-rules/` | フォルダごと |

入れたあと：

1. テストを実行する：`bash ~/.claude/skills/safety-rules/scripts/test-guard.sh`（すべて成功すること）
2. Claude Code を再起動し、`/permissions` と `/hooks` で設定が効いているか見る。

**戻し方**：`~/.claude/backups/` の控えを `~/.claude/settings.json` に戻し、`~/.claude/hooks/` の 2 つのスクリプトと 2 つの skill のフォルダを消す（フォルダの削除は自分のターミナルで）。

## Claude 用のトークン

この PC の gh は、権限を絞ったトークンでログインする。Claude が使っても、できるのは「選んだリポジトリの作業ブランチへの push と PR の作成」程度になる。リポジトリの作成やブランチ保護の設定は GitHub の画面で行う。詳しくは [docs/design.md](docs/design.md) の 6 章。

1. GitHub の Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token。
   - Expiration：30〜90 日
   - Repository access：Only select repositories（Claude に作業させるリポジトリだけ）
   - Repository permissions：Contents（Read and write）、Pull requests（Read and write）。Metadata（Read-only）は自動で付く。ほかは付けない
2. 自分のターミナルで、いまのログインを消してから、トークンで入れ直す。トークンは画面に貼り付けるだけで、ファイルやチャットには残さない。

   ```bash
   gh auth logout
   gh auth login --with-token     # トークンを貼り付けて Enter、続けて Ctrl+D
   gh auth setup-git
   gh auth status
   ```

3. 期限が近づいたら（`/safety-rules` の点検で残り日数が出る）、同じ手順で作り直す。新しいリポジトリをトークンの Repository access に足す作業は、`github-setup.sh` が手順を表示して案内する。

## 使い方

| やりたいこと | 方法 |
|---|---|
| 新しいプロジェクトを始める | 空のディレクトリで Claude Code を起動し、`/new-project` |
| GitHub に上げて設定する（リポジトリの作成、ブランチ保護など） | プロジェクトのフォルダで、自分のターミナルから `bash ~/.claude/skills/new-project/scripts/github-setup.sh`（Private なら `--private`）。`/new-project` の途中で案内される |
| 安全ルールを見る・変える・点検する | `/safety-rules` |
| 安全フックのテスト | `bash ~/.claude/skills/safety-rules/scripts/test-guard.sh` |

## 安全設定の考え方（2 層）

| 層 | 場所 | 中身 |
|---|---|---|
| ユーザー全体 | `~/.claude/` | どこで効いても困らないルール：権限昇格・ディスク操作・削除・git の破壊的な操作・認証情報の読み取りの禁止、main / develop の保護、権限チェックを飛ばすモードの禁止 |
| プロジェクト | 各プロジェクトの `.claude/`、`.githooks/` | サンドボックス、通信してよいドメイン、パッケージ操作の禁止、git 自体のフック |

サンドボックスをユーザー全体で有効にしないのは、デスクトップの設定作業（`hyprctl` などの Unix ソケット、`~/.config` の編集）が動かなくなるため。詳しくは [docs/design.md](docs/design.md)。

## ブランチ運用

このリポジトリも、作ったプロジェクトも同じ運用。

- `main` と `develop` には直接 push・commit しない（安全フック・git のフック・GitHub のブランチ保護で止める）。
- `develop` から作業ブランチ（`feature/〜`、`fix/〜`、`docs/〜`）を切り、`develop` への PR で取り込む。
- PR のマージは人が行う（Claude はマージしない）。

## 参考にしたもの

- [trailofbits/claude-code-config](https://github.com/trailofbits/claude-code-config)：認証情報の読み取り禁止の範囲、MCP サーバーの自動有効化の無効化、利用状況の送信の停止、履歴の保存期間
- git-guardrails（mattpocock/skills、MIT ライセンス。現在はリポジトリから削除されている）：止める git 操作の一覧
- [Claude Code のサンドボックスのドキュメント](https://code.claude.com/docs/en/sandboxing)

## ライセンス

MIT
