# ユーザー全体設定とテンプレートリポジトリの導入計画

| 項目 | 内容 |
|---|---|
| 版 | 1.0 |
| 作成日 | 2026-10-24 |
| 更新日 | 2026-10-24（導入した。導入時に分かったことを 14 章に追記） |
| 状態 | **導入済み**（`~/.claude` とテンプレートリポジトリ。GitHub への push は未実施） |
| 関連 | [line-bot での Q&A ログ](qa_log_line-bot.md) |

この文書は、`~/.claude`（このPCのユーザー kip2 全体に効く Claude Code の設定）に **何を入れるか** を、導入前にすべて書き出したものである。
内容を確認し、「判断事項」（11 章）の残りに答えてもらってから導入する。

---

## 1. 目的

- 新しいプロジェクトを始めるたびに安全ルールやドキュメントの雛形を作る手間をなくす。
- 作った設定と雛形を GitHub（**Public** リポジトリ `claude-project-template`）に置き、別のPCでも同じ環境を再現できるようにする。
- git のブランチ運用（main / develop を保護し、作業ブランチから PR で取り込む）を、すべてのプロジェクトで守らせる。

## 2. 全体の構成（2 層）

| 層 | 置き場所 | 効く範囲 | 中身 |
|---|---|---|---|
| **ユーザー全体** | `~/.claude/` | このPCの kip2 が使う **すべての** Claude Code（omarchy の作業なども含む） | どこで効いても困らないルールだけ：権限昇格・ディスク操作・git の破壊的操作・認証情報の読み取りの禁止、ブランチ運用のガード、安全フック、skill 2 つ |
| **プロジェクトごと** | 各プロジェクトの `.claude/settings.json` と `.githooks/` | そのプロジェクトだけ | プロジェクトに合わせたより厳しいルール：サンドボックス、通信してよいドメイン、パッケージ操作の禁止、git 自体のフック（pre-push / pre-commit） |

**サンドボックスをユーザー全体で有効にしない理由**：

- omarchy の作業で使う `hyprctl` などは Unix ソケットで通信するが、Linux のサンドボックス内ではこれが遮断される。
- サンドボックス内で書き込めるのは作業中のディレクトリだけなので、`~/.config/hypr` などを直すコマンドが失敗する。
- ユーザー全体の設定で「サンドボックスの外での実行を禁止」にすると、プロジェクト側の設定では解除できない。

そのため、サンドボックスはプロジェクトの雛形の側に入れる。

## 3. 現在の `~/.claude/settings.json`（2026-10-24 時点）

```json
{
  "enabledPlugins": {
    "claude-obsidian@claude-obsidian-marketplace": true
  },
  "extraKnownMarketplaces": {
    "claude-obsidian-marketplace": {
      "source": { "source": "github", "repo": "AgriciDaniel/claude-obsidian" }
    }
  },
  "tui": "fullscreen",
  "skipDangerousModePermissionPrompt": true
}
```

- `enabledPlugins` / `extraKnownMarketplaces` / `tui` は **そのまま残す**。
- `skipDangerousModePermissionPrompt` は **削除する**（Q1：権限チェックを飛ばすモードは使用禁止）。
- `~/.claude/settings.local.json` は **変更しない**。

## 4. 追加・変更するファイルの一覧

| パス | 新規/変更 | 内容 |
|---|---|---|
| `~/.claude/settings.json` | 変更（追記） | 5 章の内容に置き換える（既存の項目は残す） |
| `~/.claude/hooks/guard-bash.sh` | 新規 | 安全フック（6 章） |
| `~/.claude/skills/new-project/` | 新規 | プロジェクトの雛形を作る skill（9.1） |
| `~/.claude/skills/safety-rules/` | 新規 | 安全ルールを一覧・追加・点検する skill（9.2） |
| `~/.claude/backups/settings.json.2026MMDD` | 新規 | 変更前の settings.json の控え（戻すとき用） |

既存の skill（`omarchy`、`mulmoterminal-*`、`diagnose-crash`、`synced`）には触れない。

## 5. 導入後の `~/.claude/settings.json`（全文）

出典の凡例：【今回】＝今回作ったもの、【ToB】＝Trail of Bits の推奨設定、【GG】＝git-guardrails skill（mattpocock/skills、MIT ライセンス）。

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "enabledPlugins": {
    "claude-obsidian@claude-obsidian-marketplace": true
  },
  "extraKnownMarketplaces": {
    "claude-obsidian-marketplace": {
      "source": { "source": "github", "repo": "AgriciDaniel/claude-obsidian" }
    }
  },
  "tui": "fullscreen",
  "cleanupPeriodDays": 180,
  "enableAllProjectMcpServers": false,
  "env": {
    "DISABLE_TELEMETRY": "1",
    "DISABLE_ERROR_REPORTING": "1",
    "CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY": "1"
  },
  "permissions": {
    "disableBypassPermissionsMode": "disable",
    "deny": [
      "Bash(sudo *)",
      "Bash(su *)",
      "Bash(doas *)",
      "Bash(mkfs *)",
      "Bash(dd *)",
      "Bash(fdisk *)",
      "Bash(parted *)",
      "Bash(wipefs *)",
      "Bash(shutdown *)",
      "Bash(reboot *)",
      "Bash(poweroff *)",
      "Bash(halt *)",
      "Bash(chmod -R 777 *)",
      "Bash(npm publish *)",

      "Bash(rm -r *)",
      "Bash(rm -R *)",
      "Bash(rm -rf *)",
      "Bash(rm -fr *)",
      "Bash(rm --recursive *)",
      "Bash(rmdir *)",
      "Bash(gio trash *)",
      "Bash(gio remove *)",
      "Bash(trash *)",
      "Bash(trash-put *)",
      "Bash(trash-empty *)",
      "Bash(shred *)",
      "Bash(git rm -r *)",
      "Bash(git rm -rf *)",
      "Bash(git rm -f *)",

      "Bash(git push --force *)",
      "Bash(git push -f *)",
      "Bash(git push * --force *)",
      "Bash(git push * -f *)",
      "Bash(git reset --hard *)",
      "Bash(git clean *)",
      "Bash(git branch -D *)",
      "Bash(git checkout .)",
      "Bash(git checkout -- .)",
      "Bash(git restore .)",
      "Bash(gh pr merge *)",
      "Bash(gh repo delete *)",
      "Bash(gh repo edit *)",
      "Bash(gh api *branches*protection*)",
      "Bash(gh api *rulesets*)",

      "Read(~/.ssh/**)",
      "Read(~/.gnupg/**)",
      "Read(~/.aws/**)",
      "Read(~/.azure/**)",
      "Read(~/.kube/**)",
      "Read(~/.config/gh/**)",
      "Read(~/.git-credentials)",
      "Read(~/.docker/config.json)",
      "Read(~/.npmrc)",
      "Read(~/.pypirc)",
      "Read(~/.gem/credentials)",
      "Read(~/.local/share/keyrings/**)",
      "Read(~/.claude/.credentials.json)",
      "Read(./.env)",
      "Read(./.env.*)",

      "Edit(~/.ssh/**)",
      "Edit(~/.bashrc)",
      "Edit(~/.bash_profile)",
      "Edit(~/.zshrc)",
      "Edit(~/.profile)",
      "Edit(~/.config/fish/**)",
      "Edit(~/.gitconfig)",
      "Edit(//etc/**)",
      "Edit(//usr/**)",
      "Edit(./.env)",
      "Edit(./.env.*)",
      "Edit(./.githooks/**)"
    ],
    "ask": [
      "Bash(rm *)",
      "Bash(git rm *)",
      "Bash(git push *)",
      "Bash(git branch -d *)",
      "Bash(git checkout -- *)",
      "Bash(git restore *)",
      "Bash(git rebase *)",
      "Bash(git stash drop *)",
      "Bash(git stash clear *)",
      "Bash(git config *)",
      "Bash(gh pr create *)",
      "Bash(gh repo create *)",
      "Bash(pacman *)",
      "Bash(yay *)",
      "Bash(paru *)",
      "Bash(systemctl *)",
      "Bash(docker *)",
      "Edit(~/.claude/settings.json)",
      "Edit(~/.claude/hooks/**)",
      "Edit(~/.claude/skills/**)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/guard-bash.sh",
            "timeout": 10,
            "onFailure": "block",
            "statusMessage": "安全チェック中..."
          }
        ]
      }
    ]
  }
}
```

※ 判断事項の回答はすべて反映済み（11 章）。

### 5.1 各ルールの説明と出典

| ルール | 種類 | 理由 | 出典 |
|---|---|---|---|
| `sudo` / `su` / `doas` | 拒否 | 権限昇格。システム全体を壊せる | 今回・ToB |
| `mkfs` / `dd` / `fdisk` / `parted` / `wipefs` | 拒否 | ディスクを消す可能性がある | 今回・ToB |
| `shutdown` / `reboot` / `poweroff` / `halt` | 拒否 | 作業中に PC が止まる | 今回 |
| `chmod -R 777` | 拒否 | 誰でも書き換えられる状態になる | 今回 |
| `npm publish` | 拒否 | 意図せずパッケージを公開してしまう | 今回 |
| **`rm -r` / `rm -rf` など再帰的な削除すべて、`rmdir`** | 拒否 | 元に戻せない一括削除を防ぐ。フォルダの削除はユーザーが行う（8 章） | ToB（ToB は `rm -rf` だけ。今回は `-r` 単独も対象に広げた） |
| **ゴミ箱に入れるコマンド**（`gio trash`、`trash`、`trash-put`）、`gio remove`、`shred` | 拒否 | 削除はすべて「ファイルを 1 つずつ確認」に統一するため（8 章） | 今回 |
| `git rm -r` / `git rm -f` | 拒否 | 再帰的な削除、変更の強制破棄になる | 今回 |
| 1 ファイルの `rm`、`git rm` | 確認 | 毎回、消すファイルを示して確認する | 今回 |
| `git push --force` 系 | 拒否 | リモートの履歴を書き換えてしまう | 今回・ToB・GG |
| `git reset --hard` | 拒否 | コミットしていない変更が消える | 今回・ToB・GG |
| `git clean` | 拒否 | git 管理外のファイルを一括で消す | GG |
| `git branch -D` | 拒否 | マージしていないブランチを強制的に消す（`-d` は、マージ済みでないと消せないので確認止まりにする） | GG |
| `git checkout .` / `git restore .` | 拒否 | 作業中の変更を全部捨てる | GG |
| 1 ファイルの `git restore` / `git checkout --`、`git rebase`、`git stash drop` / `clear` | 確認 | 変更を捨てる・履歴を書き換える操作。必要な場面もある | 今回 |
| **main / develop への直接の push と commit** | 拒否（フック） | ブランチ運用（7 章）を守る | 今回（GG は push をすべて止める。今回は作業ブランチの push は許可する形にした） |
| `gh pr merge` | 拒否 | PR を develop に取り込むのはユーザーが行う（7 章） | 今回 |
| `gh repo delete`、`gh repo edit`、ブランチ保護（rulesets）の設定変更 | 拒否 | リポジトリを消したり、公開範囲や保護を変えたりできてしまう。保護の設定はユーザーが行う（7.4） | 今回 |
| `git push`、`gh pr create`、`gh repo create`、`git config` | 確認 | 外部に送る操作と、git の設定変更 | 今回 |
| `~/.gitconfig`、`.githooks/` の編集 | 拒否 | git の安全装置（7.3）を Claude が外せないようにする | 今回 |
| 認証情報の読み取り（`~/.ssh` `~/.gnupg` `~/.aws` `~/.config/gh`） | 拒否 | 鍵・認証情報 | 今回・ToB |
| 同（`~/.azure` `~/.kube` `~/.git-credentials` `~/.docker/config.json` `~/.npmrc` `~/.pypirc` `~/.gem/credentials`） | 拒否 | 各種サービスの認証情報 | ToB |
| `~/.local/share/keyrings` の読み取り | 拒否 | Linux のパスワード保管庫（ToB が macOS で Keychains を禁止しているのと同じ考え方） | ToB を Linux 向けに置き換え |
| `~/.claude/.credentials.json` の読み取り | 拒否 | Claude Code 自体のログイン情報 | 今回 |
| `.env` / `.env.*` の読み書き | 拒否 | アプリの秘密情報 | 今回 |
| シェルの設定ファイル（`.bashrc`、fish の設定など）、`/etc`、`/usr` の編集 | 拒否 | 次回ログイン時に勝手なコマンドが動く仕掛けを防ぐ | 今回・ToB |
| `pacman` / `yay` / `paru` / `systemctl` | 確認 | omarchy の作業では必要になる。プロジェクト側では拒否にする | 今回 |
| `docker` | 確認 | コンテナ経由でサンドボックスを抜けられるため | 今回 |
| `~/.claude` の設定・フック・skill の編集 | 確認 | 安全設定を勝手に緩められないようにする | 今回 |
| `enableAllProjectMcpServers: false` | 設定 | 他人のリポジトリを clone したとき、その中の MCP サーバーが勝手に有効にならないようにする | ToB |
| `env` の 3 つ（`DISABLE_TELEMETRY` など） | 設定 | 利用状況の統計・エラー報告・アンケートを Anthropic に送らない | ToB |
| `cleanupPeriodDays: 180` | 設定 | 会話の履歴を約半年残す（標準は 30 日） | ToB（ToB は 365 日。回答により 180 日） |
| `disableBypassPermissionsMode` | 設定 | 権限チェックを飛ばすモードを使えなくする（判断事項 Q1） | 今回 |

## 6. 安全フック `~/.claude/hooks/guard-bash.sh`

権限ルールはコマンドの **先頭** しか見ないので、`cd x && rm -rf y` のように途中に紛れたものはフックで止める。
今プロジェクトにある [.claude/hooks/guard-bash.sh](../global/hooks/guard-bash.sh) をもとに、次のように変える。

**そのまま残す検出ルール**：`sudo` の紛れ込み、`curl | sh`、デバイスへの書き込み、fork 爆弾、`chmod 777`、強制 push、`reset --hard`、`git clean`、電源操作、`.env` の読み取り、SSH 鍵へのアクセス。

**外すもの**：`pacman` / `yay` / `paru` を止めるルール（ユーザー全体では「確認」にしたため。omarchy の作業で使う）。

**追加・強化するもの**：

| 検出するもの | 例 |
|---|---|
| 再帰的な `rm` すべて（オプションの順番や書き方を問わない） | `rm -r x`、`rm -Rf x`、`rm --recursive x`、`cd a && rm -fr b` |
| `rm` 以外で一括削除するもの | `find . -delete`、`find . -exec rm`、`xargs rm`、`rmdir` |
| ゴミ箱に入れる・完全に消すコマンドの紛れ込み | `gio trash`、`trash-put`、`shred` |
| ワイルドカードを使った `rm` | `rm *.log`、`rm build/*`（1 つずつ確認できなくなるため） |
| `git branch -D`、`git branch --delete --force` | |
| 作業中の変更を全部捨てる | `git checkout .`、`git checkout -- .`、`git restore .`（`git restore --staged .` は取り消しではないので許可） |
| main / develop への push（行き先を書いた場合） | `git push origin main`、`git push origin HEAD:develop`、`git push origin --delete develop` |
| main / develop にいるときの push（行き先を省いた場合） | main にいる状態での `git push` |
| main / develop にいるときの commit | develop にいる状態での `git commit` |
| `gh pr merge` の紛れ込み | |

- 現在のブランチは、フックの中で `git rev-parse --abbrev-ref HEAD` を実行して調べる。
- 例外：コミットが 1 つもない新しいリポジトリでの最初のコミットは許可する（develop ブランチを作るため）。
- テスト（`test-guard.sh`）をテンプレートリポジトリに移し、上の変更に合わせて期待値を直してケースを足す。git のテストは、一時ディレクトリに作ったテスト用のリポジトリで行う。

## 7. git のブランチ運用

### 7.1 ルール

```
main ─────────────●──────────────●─────   リリース用。直接 push・commit しない
                   ↑ PR（ユーザーがマージ）
develop ──●───●───●───●───●──────●─────   開発の本線。直接 push・commit しない
           ↑ PR    ↑ PR
feature/xxx ●─●    fix/yyy ●               作業用。Claude はここで作業する
```

1. リポジトリを作ったら、すぐに `develop` ブランチを作る。
2. 作業は必ず `develop` から個別のブランチを切って行う。名前は `feature/内容`、`fix/内容`、`docs/内容` のようにする。
3. 作業ブランチは push してよい（確認が出る）。
4. 終わったら Claude が `develop` に向けた PR を作る（`gh pr create --base develop`。確認が出る）。
5. **PR を取り込む（マージする）のはユーザー**。Claude はマージしない（`gh pr merge` は拒否）。
6. `develop` から `main` へも PR で取り込む。

### 7.2 Claude に守らせる仕組み

- 権限ルールと安全フック（5・6 章）で、main / develop への直接の push・commit、`gh pr merge` を止める。
- `CLAUDE.md`（プロジェクトの雛形）に、上の運用ルールを書く。

### 7.3 Claude 以外（自分のターミナルでの操作）も守る仕組み

Claude のフックは Claude にしか効かない。自分のターミナルでうっかり main に push するのも防ぐため、**git 自体のフック** を各プロジェクトに入れる。

| ファイル | 内容 |
|---|---|
| `.githooks/pre-push` | main / develop への push を拒否する |
| `.githooks/pre-commit` | main / develop にいるときの commit を拒否する（最初のコミットは除く） |

- `/new-project` が `.githooks/` を作り、`git config core.hooksPath .githooks` を設定する（この 1 回だけ確認が出る）。
- どうしても必要なときは、自分のターミナルで `git push --no-verify` を使えば回避できる（Claude には `--no-verify` を使わせない。フックで止める）。

### 7.4 GitHub 側の保護（ブランチ保護 = rulesets）

GitHub の無料プランでは、**Private リポジトリにブランチ保護（rulesets）を設定できない**。使えるのは Public リポジトリか、有料プラン（GitHub Pro 以上）の場合だけ。
参考：[GitHub Docs: About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)

**決定（Q7）**：テンプレートリポジトリ `claude-project-template` は **Public** にして、GitHub のブランチ保護を使う。

main と develop に設定する保護の内容：

| 設定 | 値 | 意味 |
|---|---|---|
| 対象のブランチ | `main`、`develop` | |
| PR を必須にする | オン | 直接の push を GitHub 側でも拒否する |
| 必要な承認の数 | 0 | 一人で開発しているため（自分の PR は自分で承認できない仕様） |
| 強制 push を禁止 | オン | |
| ブランチの削除を禁止 | オン | |
| 保護を無視できる人 | なし | |

- 保護の設定は Claude ではなく **ユーザーが行う**（Claude の `gh api *rulesets*` は拒否）。Claude は、GitHub の画面での設定手順を示すか、設定用のコマンドを書いて渡す。それを自分のターミナルで実行する。
- これで「GitHub の画面から直接 main に変更を入れる」ことも防げる。7.2・7.3 と合わせて三重のガードになる。

**新しいプロジェクトは Public か Private か**：プロジェクトごとに `/new-project` が質問する。

- Public：GitHub のブランチ保護も使える。ただし、コード・ドキュメント・Q&A ログがすべて公開される。
- Private：GitHub 側の保護は使えない（ローカルの二重のガードのみ）。秘密にしたい内容があるプロジェクトはこちら。line-bot は内容が決まってから決める。

### 7.5 Public にするときの注意（個人情報）

- **コミットに残るメールアドレス**：git のコミットには、作った人の名前とメールアドレスが記録され、Public リポジトリでは誰でも見られる。いま git には名前もメールアドレスも設定されていない。
  - GitHub が用意する、公開用のメールアドレス（`<番号>+<ユーザー名>@users.noreply.github.com`）を使う。GitHub の設定画面の「Emails」で確認でき、「Keep my email addresses private」をオンにする。
  - 設定は自分のターミナルで行う（`git config --global user.email ...`。Claude の `git config` は確認が出る）。
- **リポジトリに入れないもの**：個人のプラグイン設定、`~/.claude/settings.local.json`、ホームディレクトリのパス（ドキュメント中では `~` と書く）。
- push の前に、上げるファイルの一覧と、個人情報が含まれていないかの点検結果を示し、ユーザーの確認を取る。

## 8. ファイルとフォルダの削除の方針

**決定（Q6・Q8）**：`rm -rf` もゴミ箱に入れるコマンド（trash）も使わない。削除は、必ず消すものを示して確認してから行う。

| 消すもの | 誰が | 手順 |
|---|---|---|
| ファイル（1 つずつ） | Claude | `rm <ファイル名>` を 1 ファイルずつ実行する。毎回確認が出るので、ファイル名を見て許可する。ワイルドカード（`*`）は使わない |
| git で管理しているファイル | Claude | `git rm <ファイル名>` を 1 ファイルずつ（確認が出る）。コミット済みなら履歴から戻せる |
| フォルダ | **ユーザー** | Claude は消さない。代わりに、フォルダごとに次の内容をまとめて示す。それを見て、自分のターミナルで消す |

フォルダを消したいときに Claude が示す内容：

```
削除の候補: build/
  - 中身: ファイル 128 個、サイズ 45 MB
  - git の管理: 管理外（.gitignore 対象）→ 消しても git に影響なし
  - 主な中身: build/index.js, build/assets/ ...
  - 消すコマンド: rm -r build/
```

- 「git で管理しているか」と「コミットしていない変更があるか」を必ず示す（消すと戻せないものかどうかの判断材料）。
- 消してよいかどうかの判断と、実際の削除はユーザーが行う。
- `node_modules` や `build` のように何度も作り直すフォルダは、言われればその都度この手順を踏む。

この方針は、ユーザー全体の `CLAUDE.md`（雛形）にも書く。

## 9. skill

### 9.1 `new-project`（新規）

空のディレクトリで `/new-project`、または「新しいプロジェクトを始めたい」と頼むと、次のファイルを作る。

```
<プロジェクト>/
├── CLAUDE.md                    # 作業ルール（ドキュメント駆動 + 安全ルール + ブランチ運用）
├── README.md
├── CHANGELOG.md
├── env.example
├── .gitignore
├── .githooks/
│   ├── pre-push                 # main / develop への push を拒否
│   └── pre-commit               # main / develop での commit を拒否
├── .claude/settings.json        # プロジェクト用の厳しい設定（下記）
├── docs/
│   ├── 01_requirements.md
│   ├── 02_design/basic_design.md
│   ├── 02_design/detailed_design.md
│   ├── 03_usage.md
│   ├── 04_qa_log.md
│   └── 05_safety.md
└── scripts/claude-safe.sh       # 安全モードでの起動
```

作る順番：

1. プロジェクト名と、通信を許可するドメイン（例：LINE の API）を質問する。
2. ファイル一式を作る。すでにファイルがあるディレクトリでは、上書きせずに中止する。
3. `git init`、git のフックの設定（`core.hooksPath`）、main で最初のコミット、`develop` ブランチの作成、最初の作業ブランチの作成。
4. GitHub に上げるか、上げるなら Public か Private かを質問する（7.4）。
   ※ 最初の push だけは、main / develop への push が必要になる。このときは Claude ではなく、表示するコマンドを **ユーザーが自分のターミナルで実行する**。
   ※ Public の場合は、続けてブランチ保護の設定手順を示す（設定はユーザーが行う）。

プロジェクト用の `.claude/settings.json` に入れるもの：

- サンドボックスを有効にする。起動できない環境では Claude Code を起動しない。サンドボックスの外での実行は禁止する。
- 通信してよいドメインのリスト（プロジェクトごとに決める。GitHub に上げる場合は `api.github.com` も入れる）。
- `pacman` / `yay` / `paru` / `systemctl` を拒否する（ユーザー全体では「確認」のものを、ここでは禁止に上げる）。
- `curl` / `wget`、パッケージの追加、`git commit` を確認対象にする。
- プロジェクトの `.claude/` と `CLAUDE.md` の編集を確認対象にする。

### 9.2 `safety-rules`（作りかけのものを移す）

line-bot で作りかけの [.claude/skills/safety-rules/](../global/skills/safety-rules/) を、2 層構成に合わせて直したうえでユーザー全体に移す。

- 一覧表示：ユーザー全体とプロジェクトの両方のルールを、どちらの層のものか分けて表示する。
- 追加・削除：まず「ユーザー全体に入れるか、このプロジェクトだけか」を確認してから編集する。
- 点検：設定ファイルの JSON が壊れていないか、フックのテスト、`05_safety.md` が最新か、git のフックが有効か（`core.hooksPath`）を確認する。
- ルールを緩める変更は、ユーザーの明示的な OK がないと行わない。

## 10. 他の作業への影響

| 作業 | 影響 |
|---|---|
| omarchy・Hyprland のカスタマイズ | `pacman` / `yay` / `systemctl` は確認が出るようになる（止まりはしない）。`sudo` は使えなくなるので、必要なときは自分のターミナルで実行する |
| fish の設定を Claude に直してもらう | できなくなる（拒否） |
| フォルダの削除 | Claude は消さない。消す候補と中身を示すので、自分で消す（8 章） |
| `node_modules` などの作り直し | フォルダの削除がユーザーの作業になるため、少し手間が増える |
| git のブランチ運用ルールがない既存のリポジトリ | main / develop への直接の push・commit が、Claude からはできなくなる。そのリポジトリでも作業ブランチと PR を使う |
| `claude --dangerously-skip-permissions` | 使えなくなる |
| 利用状況の統計・エラー報告・アンケート | Anthropic に送られなくなる |
| 他人のリポジトリを clone して使う | そのリポジトリの MCP サーバーは、自動では有効にならない |
| Read ツールで `~/.npmrc` などを読む | 読めなくなる |
| 読み取りだけの `pacman -Qi` なども確認が出る | 権限ルールはサブコマンドまで区別しないため |
| 既存の line-bot | 設定が二重になる（害はない）。導入後に、プロジェクト固有の分だけ残すよう整理する（12 章）。まだ git リポジトリではないので、ブランチ運用はこれから始める |

**このしくみで防げないもの**：

- 拒否のルールとフックは文字列を照合しているだけなので、書き方を工夫したコマンドは見逃す可能性がある。
- `Read` の拒否は Claude の Read ツールにしか効かない。Bash の `cat` で読むのを確実に防ぐのは、サンドボックスだけ（つまりプロジェクト層）である。
- Private リポジトリでの、GitHub の画面からの直接の変更（7.4。Public なら防げる）。

## 11. 判断事項

| No | 内容 | 回答 / 案 | 状態 |
|---|---|---|---|
| Q1 | 権限チェックを飛ばすモード | 使用禁止（`disableBypassPermissionsMode`。`skipDangerousModePermissionPrompt` は削除） | 決定 |
| Q2 | main への直接の push | 止める。develop も保護し、作業ブランチから develop へ PR で取り込む（7 章） | 決定 |
| Q3 | シェル設定の編集 | 拒否する | 決定 |
| Q4 | 利用状況の送信 | 止める（`env` に 3 つ追加） | 決定 |
| Q5 | 会話の履歴を残す期間 | 180 日（約半年） | 決定 |
| Q6 | `rm -rf` | 再帰的な削除はすべて止める | 決定 |
| Q7 | GitHub 側のブランチ保護 | テンプレートリポジトリは Public にして、ブランチ保護を使う。新しいプロジェクトはその都度選ぶ（7.4） | 決定 |
| Q8 | trash（ゴミ箱に入れるコマンド） | これも禁止。ファイルは 1 つずつ確認して消し、フォルダはユーザーが消す（8 章） | 決定 |
| Q9 | PR を develop に取り込む（マージする）のは誰か | ユーザー（Claude の `gh pr merge` は拒否） | 決定 |
| Q10 | 削除の方針（8 章）の理解が合っているか | 「ファイルは Claude が 1 つずつ確認して消す。フォルダは Claude が中身を示し、ユーザーが消す」 | **確認待ち** |

ToB から **取り込まないもの**：

- macOS 用のパス（`~/Library/...`）。このPCは Linux なので意味がない。
- `~/.npm/**` の読み取り禁止。npm のエラーログの確認に必要なため。認証情報の入る `~/.npmrc` は禁止する。
- エージェントチームの実験的な設定と、ステータスライン。安全とは関係ないため。

git-guardrails から **変えたところ**：

- `git push` をすべて止めるのではなく、作業ブランチの push は許可した（確認は出る）。main / develop への push だけ止める。

## 12. 導入の手順（シェルスクリプトは使わない）

確認が済んだら、以下を Claude が 1 つずつ行う。ファイルを書き込むたびに確認が出るので、内容を見て許可する。

1. 今の `~/.claude/settings.json` を `~/.claude/backups/` に控えとして保存する。
2. `~/.claude/settings.json` を 5 章の内容（判断事項の答えを反映したもの）に書き換える。
3. `~/.claude/hooks/guard-bash.sh` を置き、テストを実行する。
4. `~/.claude/skills/new-project/` と `~/.claude/skills/safety-rules/` を置く。
5. Claude Code を再起動して、設定が効いているか確認する（`/permissions`、`/hooks` で見られる）。
6. line-bot の `.claude/settings.json` から、ユーザー全体と重なる分を消して、プロジェクト固有の分（サンドボックス、LINE のドメインなど）だけにする。line-bot も git リポジトリにし、ブランチ運用を始める。

**戻し方**：`~/.claude/backups/` の控えを `~/.claude/settings.json` に戻し、`~/.claude/hooks/guard-bash.sh` と、追加した 2 つの skill を消す。

## 13. GitHub リポジトリ `claude-project-template`（Public）

```
claude-project-template/
├── README.md                 # 何が入っているか、別の PC への入れ方
├── docs/                     # このリポジトリ自体のドキュメント（この計画書・Q&A ログ・変更履歴）
├── global/                   # ~/.claude に入れるもの
│   ├── settings.json         #   5 章の内容から、個人の項目（プラグインなど）を除いたもの
│   ├── hooks/guard-bash.sh
│   └── skills/
│       ├── new-project/      #   雛形のファイル一式（.githooks を含む）もこの中に入れる
│       └── safety-rules/
└── tests/test-guard.sh
```

- 置き場所：`~/Programfiles/Claude/claude-project-template`（line-bot の隣）。
- このリポジトリ自体も 7 章のブランチ運用で管理する。
- 別の PC への入れ方は、README に「どのファイルをどこに置くか」の表で書く。シェルスクリプトは使わず、Claude にその README を読ませて入れてもらう。

**GitHub に上げるときに必要なこと**：

1. **自分のターミナルで `gh auth login`** を実行する（`gh` が未ログインのため。Claude はログインの操作ができない）。
2. GitHub の「Emails」設定で公開用のメールアドレスを確認し、git に名前とメールアドレスを設定する（7.5）。
3. Claude が、上げるファイルの一覧と、個人情報の点検結果を示す。ユーザーが確認する。
4. Claude が Public リポジトリを作る（`gh repo create`。確認が出る）。最初の main と develop の push は、Claude が示すコマンドをユーザーが実行する。
5. ユーザーが main と develop にブランチ保護を設定する（7.4。Claude が手順を示す）。

## 14. 導入の記録（2026-10-24）

### 14.1 導入したもの

| 場所 | 内容 | 確認 |
|---|---|---|
| `~/.claude/backups/settings.json.20261024` | 変更前の settings.json の控え | |
| `~/.claude/settings.json` | 5 章の内容 | JSON 正常。個人の項目を除けばテンプレートと一致 |
| `~/.claude/hooks/guard-bash.sh` | 安全フック | テスト 92 件すべて成功。このセッションで実際にブロックが働くことを確認 |
| `~/.claude/skills/new-project/` | 雛形を作る skill | テンプレートリポジトリと一致。一時ディレクトリで手順を通しで実行し、ブランチの保護が働くことを確認 |
| `~/.claude/skills/safety-rules/` | 安全ルールの skill | テンプレートリポジトリと一致 |
| `~/Programfiles/Claude/claude-project-template/` | テンプレートリポジトリの中身（33 ファイル） | 個人情報（ユーザー名・メールアドレス・ホームのパス）が入っていないことを確認。git はまだ初期化していない |
| line-bot の `.claude/settings.json`・`strict-settings.json` | プロジェクト固有の分（サンドボックス、LINE のドメイン、パッケージ操作の禁止）だけにした | |
| line-bot | `git init` を実行し、`.github/rulesets/`、`.gitignore`、`CLAUDE.md`、`docs/05_safety.md` を新しい構成に合わせた | |

### 14.2 導入時に分かったこと

| 分かったこと | 対応 |
|---|---|
| ユーザー全体で `Edit(./.githooks/**)` を拒否すると、サンドボックスがそのパスを塞ぐため、Claude は `.githooks` を **作ることもできない** | 意図どおり（Claude が git のフックを外せない）。`.githooks` の作成はユーザーが行う手順にした |
| サンドボックスは `.git/config` への書き込みを保護しているため、Claude は `git config` を実行できない | `git config core.hooksPath .githooks` もユーザーが行う手順にした。なお、`git push -u` と `gh repo create` はサンドボックスの外で動くので、remote の設定は書ける |
| サンドボックスは `.bashrc`、`.gitconfig`、`.vscode` などを空の特殊ファイルで塞ぐ。git がこれを拾うと `git add -A` が失敗する | 雛形の `.gitignore` に「サンドボックスの目印」の欄を追加した |
| Bash のサンドボックスが書き込めるのは作業中のディレクトリだけなので、line-bot のセッションからテンプレートリポジトリの git は操作できない | テンプレートリポジトリの git の初期化と push は、そのディレクトリで Claude Code を起動して行うか、ユーザーが行う |
| 安全フックは `core.hooksPath` の設定を、単独の `git config core.hooksPath .githooks` だけ許可する（`&&` でつなぐと止まる） | 意図どおり |
| 古いプロジェクト用の安全フックと skill（line-bot の `.claude/hooks/`、`.claude/skills/safety-rules/`、`scripts/test-guard.sh`）が残っている。skill はユーザー全体のものと名前が同じ | ユーザーに削除を依頼する（フォルダの削除はユーザーが行うルールのため） |

### 14.3 ユーザーが行うこと（残り）

1. 古いファイルを消す（line-bot で）：`.claude/hooks/`、`.claude/skills/`、`scripts/test-guard.sh`
2. line-bot に git のフックを入れる（`.githooks` の作成、`git config core.hooksPath .githooks`）
3. git に名前と公開用のメールアドレスを設定する（7.5）
4. `gh auth login`
5. Claude Code を再起動する（新しい設定・フック・skill を確実に読み込むため）
6. テンプレートリポジトリを GitHub に上げる（13 章）
