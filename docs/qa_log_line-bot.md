# line-bot で行った相談の記録（移管）

テンプレートリポジトリを作るまでの相談は、最初は line-bot プロジェクトの中で行っていた。
その Q&A ログを、line-bot から 2026-10-24 にここへ移した。計画書は [setup_plan.md](setup_plan.md)。

---

## Q-001: 進め方の取り決め（2026-10-24）

- **相談**: 作りたいものを相談する前に、進め方を決めたい。
  - 必ずドキュメントを残すこと
  - 要件定義・各種設計書・使い方・Q&A ログ・変更履歴を残すこと
  - 危険な操作をしないためのルール、またはサンドボックスで起動する方法を組み込むこと
- **回答/検討**:
  - ドキュメントはリポジトリ内に Markdown で置く（コードと一緒に管理できるため）。
  - 安全対策は 4 層にした: ①CLAUDE.md のルール ②権限の拒否・確認ルール ③危険コマンドを止めるフック ④OS レベルのサンドボックス（bubblewrap）。
- **決定**: 上記の構成で準備する。作るものは次回以降に相談。
- **反映先**: line-bot の CLAUDE.md, line-bot の docs/05_safety.md, line-bot の README.md

## Q-002: 安全ルールの管理を skill で自動化したい（2026-10-24）

- **相談**: 権限ルールの「実行できないもの」などは、skill を作って自動化できそうなのでしてほしい。
- **回答/検討**:
  - ルールを 1 つ変えると、`settings.json`・安全フック・テスト・`05_safety.md`・`CHANGELOG.md` の複数ファイルを揃えて直す必要がある。手作業だと漏れが出やすい。
  - そこで次の 2 つで自動化する。
    1. skill `safety-rules`: 追加・削除・一覧・点検の手順をまとめる。`/safety-rules` か「〇〇を禁止にして」のような依頼で起動する。
    2. 自動追従: 安全設定ファイルを編集したら、フックで `05_safety.md` のルール一覧を自動生成し直し、安全フックのテストを自動で実行する。
  - `settings.json` と `.claude/hooks/` はサンドボックス内から書き換えられないので、スクリプトからは書き換えない。編集は Claude の Edit ツールで行い、その都度ユーザーの確認を通す。
- **決定**: 上記の構成で実装する。
- **反映先**: line-bot の docs/05_safety.md, line-bot の CLAUDE.md, `.claude/skills/safety-rules/`
- **追記（同日）**: Q-003 の方針に変わったため、実装は途中（手順書とスクリプトまで）で止めている。ユーザー全体の設定に移すときに仕上げる。

## Q-003: 毎回ルールを作るのが手間。テンプレートはないか（2026-10-24）

- **質問1**: 同じようなことをしているリポジトリやテンプレートは GitHub にないか。
  - **回答**: 部分的なものはあるが、ドキュメント一式と安全設定をまとめたものは見つからなかった。
    - [anthropics/claude-code の .devcontainer](https://github.com/anthropics/claude-code/tree/main/.devcontainer)（公式。コンテナで隔離する方式）
    - [trailofbits/claude-code-config](https://github.com/trailofbits/claude-code-config)（権限ルールとフック。今回のものに一番近い）
    - git の誤操作を止める skill、危険コマンドを止めるツール（Destructive Command Guard、Dippy）など
  - 今回作ったものを自分用のテンプレートにすることを提案した。
- **質問2**: ユーザー全体の設定は、このPCを使えば共有されるか。
  - **回答**: このPCの同じ Linux ユーザー（kip2）で使う Claude Code すべて（ターミナル・VS Code）に効く。別の Linux ユーザー、別のPC、ブラウザ版には効かない。別のPCでも使うには GitHub に置いておくとよい。
- **決定**:
  - テンプレートを GitHub の Private リポジトリ `claude-project-template` に置く。
  - Trail of Bits の設定の良いところを取り込む。
  - `~/.claude` に入れる前に、入れる内容をすべてドキュメントにし、ユーザーが確認してから導入する。シェルスクリプト（install.sh）は使わない。
  - サンドボックスはユーザー全体ではなくプロジェクトごとに入れる（omarchy の作業が壊れるため）。
- **未決**: 計画書の判断事項 Q1〜Q6。
- **反映先**: [setup_plan.md](setup_plan.md)

## Q-004: 計画書の判断事項への回答と質問（2026-10-24）

- **回答**:
  - git 操作はある程度やってよい。最初に見つけた、git の危険な操作を防ぐルール（git-guardrails）を取り込んでほしい。
  - main への直接の push は止める。必ず develop ブランチを作って保護し、作業は個別のブランチを切って develop に PR で取り込む。
  - シェル設定の編集は拒否でよい。
  - 会話の履歴は半年くらい残す。
  - `rm -rf` は全部止める。
- **質問1**: 権限チェックを飛ばすモードとは何か。
  - **回答**: `claude --dangerously-skip-permissions`（または権限モード `bypassPermissions`）で起動すると、Claude がファイルの編集やコマンドの実行をするときに確認を一切出さなくなるモード。「確認」にしたルールも確認なしで実行される。
    - 今の `~/.claude/settings.json` にある `skipDangerousModePermissionPrompt: true` は、以前このモードを起動したときに出る警告に同意した記録。
    - 今使っている「auto モード」とは別物。auto モードは、Claude Code が操作ごとに危険かどうかを判定し、危険そうなものは止める。
    - `disableBypassPermissionsMode` を入れると、このモードを使えなくなる。auto モードには影響しない。
- **質問2**: ToB の「利用状況の送信」とは何か。
  - **回答**: Claude Code が Anthropic に送っている次の 3 つを止める環境変数。
    - `DISABLE_TELEMETRY`: 利用状況の統計（どの機能をどれくらい使ったか、応答の速さなど）
    - `DISABLE_ERROR_REPORTING`: Claude Code がエラーを起こしたときの報告
    - `CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY`: 「Claude の調子はどうですか」というアンケートの表示
    - どれも会話の内容そのものではない（会話は Claude に答えさせるために、もともと送られている）。止めても使い勝手はほぼ変わらない。安全とは別の、プライバシーの好みの問題。
- **質問3**: trash コマンドは安全か。
  - **回答**: `rm -rf` よりずっと安全。消すのではなくゴミ箱に移すので、ゴミ箱を空にしない限り戻せる。ただし容量は減らず、秘密情報のファイルは中身が残る。このPCには trash-cli はないが、`gio trash` が最初から使える。詳しくは計画書の 8 章。
- **調べてわかったこと**:
  - git-guardrails は、今の mattpocock/skills リポジトリからは削除されていて、スクリプト本体は確認できなかった。何を止めているか（`git push` すべて、`reset --hard`、`clean -f`、`branch -D`、`checkout .`、`restore .`）は確認できたので、それを自前のフックに取り込む。push は「すべて止める」ではなく「main / develop だけ止める」に変えた。
  - GitHub の無料プランでは、Private リポジトリにブランチ保護（rulesets）を設定できない（[GitHub Docs](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)）。そのため、Claude のフックと git 自体のフック（pre-push / pre-commit）の二重でガードする案にした。
  - 安全フックは、読み取りだけの `pacman -Qi` も止める。「pacman」という文字列だけで判定しているため。
- **決定**: 計画書を 0.2 に更新した（Q2・Q3・Q5・Q6 が決定）。
- **未決**: Q1（権限チェックを飛ばすモード）、Q4（利用状況の送信）、Q7（GitHub 側の保護）、Q8（trash-cli）、Q9（PR を取り込むのは誰か）。
- **反映先**: [setup_plan.md](setup_plan.md)

## Q-005: 残りの判断事項への回答（2026-10-24）

- **回答**:
  - 権限チェックを飛ばすモードは使用禁止。
  - ToB の利用状況の送信は止める。
  - trash も禁止。とにかく、消すときはフォルダ単位などで確認してから消すようにする。
  - GitHub の制約があるなら Public でもよい。
  - PR のマージは自分（ユーザー）が行う。
- **検討**:
  - 削除の方針は「ファイルは Claude が 1 つずつ確認を取って消す。フォルダは Claude が中身（ファイル数・サイズ・git で管理しているか・未コミットの変更の有無）を示し、ユーザーが消す」と解釈した。→ Q10 で確認待ち。
  - Public にすると、コミットに記録されるメールアドレスも公開される。git にはまだ名前とメールアドレスが設定されていないので、GitHub の公開用のメールアドレス（noreply）を使う手順を入れた。
  - 一人で開発するため、ブランチ保護の「必要な承認の数」は 0 にする（GitHub では自分の PR を自分で承認できない）。
  - ブランチ保護と公開範囲の変更は、Claude ではなくユーザーが行う（`gh api *rulesets*`、`gh repo edit` は拒否）。
- **決定**: 計画書を 0.3 に更新した。Q1〜Q9 は決定。
- **未決**: Q10（削除の方針の解釈が合っているか）。
- **反映先**: [setup_plan.md](setup_plan.md)

## Q-006: 計画の承認と導入（2026-10-24）

- **回答**: 「これでいい」（Q10 の削除の方針の解釈も含めて承認）。
- **実施**:
  - テンプレートリポジトリ `~/Programfiles/Claude/claude-project-template` を作った。
  - `~/.claude` に設定・安全フック・2 つの skill を入れた。変更前の設定は `~/.claude/backups/settings.json.20261024` に控えた。
  - line-bot の設定を、プロジェクト固有の分だけにした。`git init` を実行した。
- **導入時に分かったこと**: Claude は `.githooks` の作成と `git config` ができない（安全設定とサンドボックスによる。意図どおり）。そのため、この 2 つはユーザーが行う手順にした。詳しくは計画書の 14 章。
- **決定**: 計画書を 1.0（導入済み）にした。
- **残り**: 計画書の 14.3（ユーザーが行うこと）。
- **反映先**: [setup_plan.md](setup_plan.md), line-bot の docs/05_safety.md, line-bot の CLAUDE.md
