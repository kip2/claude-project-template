---
name: new-project
description: 新しいプロジェクトを、ドキュメント一式（要件定義・設計書・使い方・Q&A ログ・変更履歴・安全ルール）、Claude Code の安全設定（サンドボックス・権限ルール）、git のブランチ運用（main / develop の保護、作業ブランチから PR）付きで始める。「新しいプロジェクトを始めたい」「プロジェクトの雛形を作って」と頼まれたとき、または /new-project で起動された時に使う。
---

# 新しいプロジェクトを始める

雛形は `~/.claude/skills/new-project/template/`（プロジェクトのファイル一式）と `~/.claude/skills/new-project/template-claude/`（`.claude/` に入れる安全設定）にある。

## 0. 前提の確認

1. 今いるディレクトリが **空** であることを確認する（`ls -A`）。何かファイルがあれば、上書きせずに中止して、ユーザーに伝える。
2. git の名前とメールアドレスが設定されているか確認する（`git config user.name`、`git config user.email`）。
   - 未設定なら中止し、次をユーザーに伝える。Claude は設定しない。
     - GitHub の Settings → Emails で「Keep my email addresses private」をオンにし、表示される公開用のアドレス（`番号+ユーザー名@users.noreply.github.com`）を確認する。
     - 自分のターミナルで `git config --global user.name "名前"` と `git config --global user.email "公開用のアドレス"` を実行する。
     - Public リポジトリでは、コミットに記録されたメールアドレスを誰でも見られるため。
3. `command -v gitleaks` で gitleaks が入っているか確認する。入っていなければ、自分のターミナルで `sudo pacman -S gitleaks` を実行するよう伝える（git の pre-push フックが、秘密情報の検査に使う。ないと push が止まる）。

## 1. 質問する

AskUserQuestion などで、まとめて聞く。

- プロジェクト名（ディレクトリ名と同じでよいか）
- 何を作るかの一言説明（あとで要件定義で詳しくする。未定でもよい）
- 通信を許可するドメインで、標準（npm・PyPI・GitHub）以外に必要なもの（例：LINE なら `api.line.me`、`api-data.line.me`）
- GitHub に上げるか。上げるなら Public か Private か
  - Public：GitHub のブランチ保護も使える。ただし、コード・ドキュメント・Q&A ログがすべて公開される
  - Private：無料プランでは GitHub のブランチ保護とシークレットスキャンの push 保護が使えない。守りはローカルだけになり、Claude の push と PR 作成のたびに確認が出る

## 2. ファイルを作る

1. 雛形をコピーし、実行権限を付ける。`.githooks` は除く（Claude は作れない。3 章でユーザーが作る）。

   ```bash
   tar -C ~/.claude/skills/new-project/template --exclude=./.githooks -cf - . | tar -xf -
   chmod +x scripts/claude-safe.sh
   ```

2. 雛形の中の目印を置き換える。対象は `{{PROJECT_NAME}}`（プロジェクト名）、`{{SUMMARY}}`（一言説明。未定なら「（未定）」）、`{{DATE}}`（今日の日付 `YYYY-MM-DD`）。

   ```bash
   grep -rl '{{' --exclude-dir=.git . | xargs sed -i -e "s/{{PROJECT_NAME}}/<名前>/g" -e "s/{{SUMMARY}}/<説明>/g" -e "s/{{DATE}}/$(date +%F)/g"
   ```

   - 説明に `/` や `&` が入るときは、`sed` で使えるようにエスケープするか、Edit ツールで直す。

3. 安全設定をコピーする。

   ```bash
   cp -r ~/.claude/skills/new-project/template-claude .claude
   ```

   - **これ以降はサンドボックスが有効になる**。`.claude/settings.json` と `.claude/strict-settings.json` はサンドボックスの中から書き換えられないので、以後の編集は Edit ツールで行う（確認が出る）。

4. 追加のドメインがあれば、Edit ツールで `.claude/settings.json` と `.claude/strict-settings.json` の **両方** の `sandbox.network.allowedDomains` に足す。

5. `docs/05_safety.md` のルール一覧を作る。

   ```bash
   bash ~/.claude/skills/safety-rules/scripts/sync-safety-doc.sh
   ```

## 3. git を始める

1. Claude がリポジトリを作る。

   ```bash
   git init -b main
   ```

2. **ユーザーが自分のターミナルで** git のフックを入れる。次のコマンドを渡して、実行してもらう。

   ```bash
   cd <プロジェクトのディレクトリ>
   cp -r ~/.claude/skills/new-project/template/.githooks .
   chmod +x .githooks/pre-push .githooks/pre-commit
   git config core.hooksPath .githooks
   ```

   - Claude が行えない理由：ユーザー全体の設定で `.githooks/` の編集を禁止している（Claude が git のフックを外せないようにするため）。また、サンドボックスが `.git/config` への書き込みを保護している。

3. `bash ~/.claude/skills/safety-rules/scripts/show-rules.sh` で「git のフック: 有効」になっていることを確認してから、Claude が続ける。

   ```bash
   git add -A
   git commit -m "chore: プロジェクトの雛形を作成"
   git switch -c develop
   git switch -c docs/requirements
   ```

   - 最初のコミットだけは main に直接行う（コミットが 1 つもないリポジトリでは、安全フックも git のフックも許可する）。
   - `git add -A` が「can only add regular files」で失敗したら、サンドボックスの目印のファイル（`.bashrc` などの空の特殊ファイル）が原因。`.gitignore` の「サンドボックスの目印」の欄に、そのファイル名を足す。

## 4. GitHub に上げる（上げる場合だけ）

この PC の gh は、Claude 用の権限を絞ったトークン（Contents・Pull requests の読み書き、Metadata の読み取りだけ）でログインしている前提。リポジトリの作成や設定の変更はこのトークンではできないので、**ユーザーがセットアップスクリプトを自分のターミナルで実行する**。Claude はこのスクリプトを実行しない（安全フックが止める）。

1. `gh auth status` でログインしているか確認する。未ログインなら、README の「Claude 用のトークン」の手順で入れるよう伝えて待つ。
2. **上げる前に**、上げるファイルの一覧（`git ls-files`）を示し、個人情報（メールアドレス、ホームディレクトリのパス、秘密情報）が入っていないか点検した結果を伝える。ユーザーの OK をもらう。
3. ユーザーに、自分のターミナルで次を実行してもらう（Private なら `--private` を付ける）。

   ```
   cd <プロジェクトのディレクトリ>
   bash ~/.claude/skills/new-project/scripts/github-setup.sh            # Public
   bash ~/.claude/skills/new-project/scripts/github-setup.sh --private  # Private
   ```

   スクリプトが行うこと（途中でブラウザでの操作が 2 回ある）：
   - 全履歴の秘密情報の検査（gitleaks）と、上げる内容の確認
   - 管理用の一時ログイン（ブラウザで承認。終わったら消える）
   - リポジトリの作成と origin の追加
   - Claude 用のトークンの対象への追加（ブラウザが開き、手順が表示される）と、main / develop の最初の push
   - ブランチ保護（ruleset）、シークレットスキャンの push 保護、Actions の権限、既定のブランチ（develop）、自動マージのオフ。Private（無料プラン）では、ruleset と push 保護は飛ばして続ける
   - 最後に、Claude の push 前の確認と同じものを実行して結果を表示する
4. ユーザーが「終わった」と言ったら、`bash ~/.claude/skills/safety-rules/scripts/show-rules.sh` の「GitHub」欄で、push 先の保護を確かめる。Public なら「有効」、Private なら「なし」になっていればよい。サンドボックスの中で「確認できない」と出たら、ユーザーに自分のターミナルで同じコマンドを実行してもらう。スクリプトが「うまくいかなかったもの」を表示していたら、その内容を聞いて対処する。
5. 作業ブランチは Claude が push してよい（`git push -u origin docs/requirements`。確認が出る）。push の前に、安全フックが GitHub 側の保護を確かめる。足りなければ止まるので、表示された内容をユーザーに伝える。Private で保護がない場合は、毎回確認が出る。

## 5. 仕上げ

1. `docs/04_qa_log.md` の Q-001 に、質問の答え（プロジェクト名、説明、ドメイン、公開範囲）を書き足す。
2. `CHANGELOG.md` は雛形の記述のままでよい。ドメインを足した場合は「セキュリティ」に追記する。
3. 作業ブランチでコミットする。
4. ユーザーに報告する。
   - 作ったもの
   - ブランチの状態（main / develop / 作業ブランチ）
   - 次にやること（要件定義の相談から始める）
   - Claude Code を再起動するか `/hooks` を開くと、プロジェクトの設定が確実に読み込まれること

## 注意

- 雛形のファイルを削除したいと言われても、フォルダは Claude が消さない（安全フックが止める）。消す候補を示して、ユーザーに消してもらう。
- 安全設定を緩めたいと言われたら、safety-rules スキルの手順に従う。
