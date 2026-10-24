# 使い方

| 項目 | 内容 |
|---|---|
| 最終更新 | {{DATE}} |

## 1. 開発環境で Claude Code を使う

安全モードで起動する（推奨）:

```bash
./scripts/claude-safe.sh
```

`claude` をそのまま起動しても、`.claude/settings.json` の安全設定（サンドボックス・権限ルール）は効く。
`claude-safe.sh` はそれに加えて、起動前のチェックと、より厳しいネットワーク制限をかける。違いは [05_safety.md](05_safety.md) を参照。

## 2. git の作業の流れ

```bash
git switch develop
git pull
git switch -c feature/<内容>   # 作業ブランチを切る
# … 作業・コミット …
git push -u origin feature/<内容>
gh pr create --base develop --fill
```

- PR のマージは GitHub の画面で自分が行う。
- `main` / `develop` に直接 push・commit しようとすると、git のフック（`.githooks/`）が止める。

## 3. 前提ソフトウェア

| ソフト | 用途 | 確認コマンド |
|---|---|---|
| Claude Code | 開発支援 | `claude --version` |
| bubblewrap | サンドボックス | `bwrap --version` |
| socat | サンドボックスのネットワーク中継 | `socat -V` |
| jq | 安全フックの JSON 解析 | `jq --version` |
| gh | GitHub の操作 | `gh --version` |
| （アプリ用は未定） | | |

## 4. セットアップ

（アプリの内容が決まったら記入）

1. `env.example` を `.env` にコピーし、値を設定する（`.env` はコミットしない）。
2. （未定）

## 5. 起動・停止

（未定）

## 6. よくあるトラブル

| 症状 | 原因 | 対処 |
|---|---|---|
| 「安全フックによりブロック」と表示される | 危険と判定されるコマンドを実行しようとした | [05_safety.md](05_safety.md) の一覧を確認する。本当に必要なら自分のターミナルで実行する |
| フォルダを消してほしいのに Claude が消さない | フォルダの削除はユーザーが行うルール | Claude が示す候補と中身を確認し、自分のターミナルで消す |
| 起動時にサンドボックスのエラーで終了する | `bwrap` / `socat` がない | `sudo pacman -S bubblewrap socat`（自分で実行） |
| 新しいドメインへの通信で確認が出る（安全モードでは失敗する） | 許可リストにないドメイン | 必要なら safety-rules スキルで許可ドメインに追加する |
| `pre-push: develop への直接の push は禁止です` | ブランチ運用の保護 | 作業ブランチから PR を出す |
