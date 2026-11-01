# 安全ルールとサンドボックス

Claude Code が危険な操作をしないように、次の仕組みを重ねて防いでいる。上ほど「お願い」、下ほど「強制」。

| 層 | 仕組み | 場所 | 効く範囲 |
|---|---|---|---|
| ① ルール | Claude が毎回読む作業ルール | [CLAUDE.md](../CLAUDE.md) | このプロジェクト |
| ② 権限ルール | 特定のコマンド・ファイル操作を拒否または確認 | `~/.claude/settings.json` と `.claude/settings.json` | 全体 + このプロジェクト |
| ③ 安全フック | 実行前にコマンド全体を検査し、危険なら止める | `~/.claude/hooks/guard-bash.sh` | 全体 |
| ④ サンドボックス | OS レベルの隔離（bubblewrap） | `.claude/settings.json` の `sandbox` | このプロジェクト |
| ⑤ git のフック | main / develop への直接の push・commit を拒否 | `.githooks/` | このリポジトリ（Claude 以外の操作にも効く） |
| ⑥ GitHub のブランチ保護 | main / develop は PR でしか変更できない | GitHub の Rulesets（`.github/rulesets/`） | GitHub 上（Public か有料プランのみ） |
| ⑦ push 前の保護の確認 | push / PR 作成の前に⑥が有効かを確かめ、足りないとき・確認できないときは止める | `~/.claude/hooks/check-remote-protection.sh`（③から呼ぶ） | 全体 |
| ⑧ 権限を絞ったトークン | gh / git が使うトークンは、選んだリポジトリの push と PR 作成だけができる | GitHub の Fine-grained token | GitHub 上 |

ユーザー全体の層（②の一部と③）は、テンプレートリポジトリ `claude-project-template` から `~/.claude` に入れたもの。

## 1. ルールの一覧

以下は自動生成。ルールを変えたら safety-rules スキル（`/safety-rules`）で作り直す。

<!-- BEGIN:rules -->
<!-- END:rules -->

## 2. サンドボックスの中身

Claude が実行する Bash コマンドは 1 つずつ bubblewrap の中で動く。

| 項目 | 制限 |
|---|---|
| 書き込み | プロジェクトディレクトリと一時ディレクトリのみ。`.claude/settings.json` はサンドボックス内から書き換え不可 |
| 読み取り | `.env`、SSH・GPG・クラウド・gh などの認証情報は読めない |
| ネットワーク | 許可リストのドメインのみ（1 章）。それ以外は確認が出る（安全モード起動では即拒否） |
| サンドボックス外での実行 | 禁止。ただし `git push` / `fetch` / `pull` と、`gh` の PR の作成・閲覧・コメント・編集、CI の結果や Issue の閲覧は、GitHub の認証情報を使うために外で動かす（読み取り以外は確認が出る） |
| サンドボックスが起動できない場合 | Claude Code を起動しない |

## 3. 削除のルール

- ファイルは Claude が 1 つずつ `rm <ファイル名>` で消す。毎回確認が出るので、ファイル名を見て許可する。
- フォルダは Claude が消さない。消す候補ごとに中身（ファイル数・サイズ・git で管理しているか・コミットしていない変更があるか）を示すので、自分のターミナルで消す。
- `rm -r`、ワイルドカード付きの `rm`、ゴミ箱に入れるコマンド、`find -delete` などは止まる。

## 4. 起動方法

| 方法 | 内容 |
|---|---|
| `claude` | ①〜⑤がすべて効く |
| `./scripts/claude-safe.sh`（推奨） | 上に加えて、許可リストにないドメインへの通信を確認なしで拒否する。権限チェックを飛ばすモードも使えない |

## 5. 設定を変えたいとき

- `/safety-rules` で、一覧の表示・追加・削除・点検ができる。
- 自分で編集する場合：許可ドメインは `.claude/settings.json` と `.claude/strict-settings.json` の **両方** に追加する。
- 自分だけの設定は `.claude/settings.local.json` に書く（git 管理外）。
- 変更したら [CHANGELOG.md](../CHANGELOG.md) の「セキュリティ」に記録する。

## 6. 限界（これで防げないもの）

- 権限ルールとフックは文字列の照合なので、難読化されたコマンドは見逃す可能性がある。その場合はサンドボックスが最後の砦になる。
- サンドボックスは **Bash コマンド** にかかる。Claude の Read / Edit ツールは権限ルールで制御している。
- サンドボックスの外で動かすコマンド（git の通信系と一部の gh）は、どのホストにも通信できる。
- Private リポジトリ（無料プラン）では、GitHub の画面からの直接の変更は防げない。
