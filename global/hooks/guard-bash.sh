#!/usr/bin/env bash
# Claude Code PreToolUse フック（ユーザー全体用）: 危険な Bash コマンドを実行前に止める。
# 権限ルール（settings.json）はコマンドの先頭しか見ないため、
# && や | でつないだ途中に紛れた危険な操作をここで正規表現で検出する。
# あわせて、main / develop への直接の push・commit を止める（ブランチ運用の保護）。
# push / PR 作成の前には、GitHub 側の保護が有効かを check-remote-protection.sh で確かめる。
#
# 入力: stdin に {"tool_input":{"command":"..."},"cwd":"..."} 形式の JSON
# 出力: 止めるときは permissionDecision=deny の JSON を出力する
#
# ルールを足すときは check / check_del の行を足し、
# ~/.claude/skills/safety-rules/scripts/test-guard.sh にテストを足すこと。

set -euo pipefail

input="$(cat)"
cmd="$(jq -r '.tool_input.command // ""' <<<"$input")"
cwd="$(jq -r '.cwd // ""' <<<"$input")"
[ -d "$cwd" ] || cwd="$PWD"

FOLDER_MSG='フォルダや複数ファイルの削除はユーザーが行う。消す候補ごとに、ファイル数・サイズ・git で管理しているか・コミットしていない変更があるかを示し、削除コマンドをユーザーに渡すこと'

deny() {
  jq -n --arg r "安全フックによりブロック: $1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

# 止めずに、ユーザーに確認を出す（理由を表示する）
ask() {
  jq -n --arg r "安全フックからの確認: $1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

has() { printf '%s' "$cmd" | grep -Eq -- "$1"; }
check() { if has "$1"; then deny "$2"; fi; }
check_del() { if has "$1"; then deny "$2。$FOLDER_MSG"; fi; }

# ---- 権限昇格・システム ----
check '(^|[;&|(`[:space:]])(sudo|su|doas)([[:space:]]|$)' '権限昇格（sudo / su / doas）は禁止'
check '(^|[;&|(`[:space:]])(mkfs(\.[a-z0-9]+)?|fdisk|parted|wipefs)([[:space:]]|$)' 'ディスク操作は禁止'
check '(^|[;&|(`[:space:]])dd[[:space:]].*of=/dev/' 'デバイスへの dd 書き込みは禁止'
check '>[[:space:]]*/dev/(sd|nvme|hd|mmcblk)' 'デバイスへの直接書き込みは禁止'
check ':\(\)[[:space:]]*\{' 'fork 爆弾は禁止'
check 'chmod[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*0?777' 'chmod 777 は禁止'
check '(^|[;&|(`[:space:]])(shutdown|reboot|poweroff|halt)([[:space:]]|$)' '電源操作は禁止'
check 'systemctl[[:space:]]+([^;&|]*[[:space:]])?(reboot|poweroff|halt|suspend|hibernate)([[:space:]]|$)' 'systemctl による電源操作は禁止'
check '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|fi|da)?sh([[:space:]]|$)' 'ダウンロードしたスクリプトの即実行は禁止'

# ---- 削除（ファイルを 1 つずつ確認して消す。フォルダはユーザーが消す） ----
check_del '(^|[;&|(`[:space:]])rm[[:space:]]([^;&|]*[[:space:]])?(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)([[:space:]]|$)' '再帰的な削除（rm -r / -rf）は禁止'
check_del '(^|[;&|(`[:space:]])rm[[:space:]][^;&|]*[*?]' 'ワイルドカードを使った rm は禁止（1 ファイルずつ確認できないため）'
check_del '(^|[;&|(`[:space:]])rmdir([[:space:]]|$)' 'rmdir は禁止'
check_del '(^|[;&|(`[:space:]])find[[:space:]][^;&|]*(-delete|-exec(dir)?[[:space:]]+(rm|shred|unlink|rmdir))' 'find による一括削除は禁止'
check_del 'xargs[[:space:]]+([^;&|]*[[:space:]])?(rm|shred|unlink|rmdir)([[:space:]]|$)' 'xargs による一括削除は禁止'
check_del '(^|[;&|(`[:space:]])(gio[[:space:]]+(trash|remove)|trash|trash-put|trash-empty|trash-rm|shred|unlink)([[:space:]]|$)' 'ゴミ箱に入れる・完全に消すコマンドは禁止'
check_del 'git[[:space:]]+rm[[:space:]]([^;&|]*[[:space:]])?(-[a-zA-Z]*[rRf][a-zA-Z]*|--force)([[:space:]]|$)' 'git rm -r / -f は禁止'

# ---- git の破壊的な操作 ----
check 'git[[:space:]]+push([[:space:]][^;&|]*)?[[:space:]](--force(-with-lease)?(=[^[:space:]]*)?|-[a-zA-Z]*f[a-zA-Z]*|\+[^[:space:]]+)([[:space:]]|$)' '強制 push は禁止'
check 'git[[:space:]]+reset([[:space:]][^;&|]*)?[[:space:]]--hard' 'git reset --hard は禁止'
check 'git[[:space:]]+clean([[:space:]]|$)' 'git clean は禁止'
check 'git[[:space:]]+branch[[:space:]]([^;&|]*[[:space:]])?(-[a-zA-Z]*D[a-zA-Z]*([[:space:]]|$)|--delete[[:space:]]+([^;&|]*[[:space:]])?(--force|-f)([[:space:]]|$)|(--force|-f)[[:space:]]+([^;&|]*[[:space:]])?(--delete|-d)([[:space:]]|$))' 'git branch -D（強制削除）は禁止'
check 'git[[:space:]]+checkout[[:space:]]+(--[[:space:]]+)?\.(/)?([[:space:]]|$)' 'git checkout .（作業中の変更をすべて捨てる）は禁止'
check 'git[[:space:]]+checkout[[:space:]]([^;&|]*[[:space:]])?(-f|--force)([[:space:]]|$)' 'git checkout -f（作業中の変更を捨てる）は禁止'
check 'git[[:space:]][^;&|]*--no-verify' '--no-verify（git のフックを飛ばす）は禁止'
check 'git[[:space:]]+commit[[:space:]]([^;&|]*[[:space:]])?-n([[:space:]]|$)' 'git commit -n（git のフックを飛ばす）は禁止'

# git restore .（--staged だけなら取り消しではないので許可）
if has 'git[[:space:]]+restore[[:space:]]([^;&|]*[[:space:]])?\.(/)?([[:space:]]|$)'; then
  if ! has 'git[[:space:]]+restore[[:space:]][^;&|]*(--staged|-S)([[:space:]]|$)' \
     || has 'git[[:space:]]+restore[[:space:]][^;&|]*(--worktree|-W)([[:space:]]|$)'; then
    deny 'git restore .（作業中の変更をすべて捨てる）は禁止'
  fi
fi

# git のフックの場所（core.hooksPath）は .githooks 以外にさせない
if printf '%s' "$cmd" | grep -Eqi -- 'core\.hookspath'; then
  if ! has '^git[[:space:]]+config[[:space:]]+(--local[[:space:]]+)?core\.hooksPath[[:space:]]+\.githooks[[:space:]]*$'; then
    deny 'core.hooksPath の変更は禁止（設定できるのは git config core.hooksPath .githooks だけ）'
  fi
fi

# ---- GitHub ----
check '(^|[;&|(`[:space:]])gh[[:space:]]+pr[[:space:]]+merge' 'PR のマージはユーザーが行う（gh pr merge は禁止）'
check '(^|[;&|(`[:space:]])gh[[:space:]]+repo[[:space:]]+(delete|edit)' 'リポジトリの削除・設定変更（公開範囲など）は禁止'
check '(^|[;&|(`[:space:]])gh[[:space:]]+api[[:space:]][^;&|]*(rulesets|protection)' 'ブランチ保護の設定変更はユーザーが行う'
check '(^|[;&|(`[:space:]])gh[[:space:]]+ruleset([[:space:]]|$)' 'ブランチ保護（ruleset）の操作はユーザーが行う'
check '(^|[;&|(`[:space:]])gh[[:space:]]+auth[[:space:]]+(token|login|logout|refresh|switch|setup-git)([[:space:]]|$)' 'gh のログイン情報の表示・変更は禁止'
check '(^|[;&|(`[:space:]])gh[[:space:]]+(secret|variable)([[:space:]]|$)' 'GitHub の Secrets / Variables の操作は禁止'
check '(^|[;&|(`[:space:]])gh[[:space:]]+release[[:space:]]+(create|delete|delete-asset|edit|upload)([[:space:]]|$)' 'リリースの作成・変更・削除はユーザーが行う'
check '(^|[;&|(`[:space:]])gh[[:space:]]+workflow[[:space:]]+(run|enable|disable)([[:space:]]|$)' 'ワークフローの実行・有効化・無効化はユーザーが行う'
check '(^|[;&|(`[:space:]])gh[[:space:]]+repo[[:space:]]+set-default' 'gh の既定のリポジトリの変更は禁止'
check 'git[[:space:]]+remote[[:space:]]+(add|set-url|rename)([[:space:]]|$)' 'push 先（リモート）の追加・変更はユーザーが行う'
check 'git[[:space:]]+config[[:space:]][^;&|]*(credential|[Ii]nstead[Oo]f|remote\.[^[:space:]]+\.(push)?url)' 'git の認証情報・push 先の URL の設定は禁止'
check '(^|[;&|(`[:space:]])(GH_CONFIG_DIR|GH_TOKEN|GITHUB_TOKEN|GH_ENTERPRISE_TOKEN|GITHUB_ENTERPRISE_TOKEN)=' 'gh を別のログインやトークンで動かす指定は禁止'
check '(^|[;&|(`[:space:]])((ba|z|da)?sh|source|exec|\.)[[:space:]]+([^;&|]*[[:space:]])?[^[:space:];&|]*github-setup\.sh' 'GitHub のセットアップスクリプトはユーザーが自分のターミナルで実行する'
check '(^|[;&|(`])[[:space:]]*[^[:space:];&|]*github-setup\.sh' 'GitHub のセットアップスクリプトはユーザーが自分のターミナルで実行する'

# gh api の書き込み（GET / HEAD 以外）。-f / -F / --input で値を渡すと、gh は自動で POST にする
api_seg="$(printf '%s' "$cmd" | grep -Eo '(^|[;&|(`[:space:]])gh[[:space:]]+api([[:space:]][^;&|]*)?' || true)"
if [ -n "$api_seg" ]; then
  methods="$(printf '%s' "$api_seg" | grep -Eo -- '(-X|--method)([[:space:]]+|=)?[A-Za-z]+' | sed -E 's/^(-X|--method)([[:space:]]+|=)?//' | tr '[:lower:]' '[:upper:]' || true)"
  if printf '%s\n' "$methods" | grep -Evq '^(GET|HEAD|)$'; then
    deny 'gh api の書き込み（GET 以外）は禁止'
  fi
  if [ -z "$methods" ] && printf '%s' "$api_seg" | grep -Eq -- '[[:space:]](-[fF]|--field|--raw-field|--input)([[:space:]=]|[^[:space:]]|$)'; then
    deny 'gh api の書き込み（-f / -F / --input で値を渡すと POST になる）は禁止。読み取りなら -X GET を付ける'
  fi
fi

# ---- 秘密情報 ----
check '(cat|less|more|head|tail|bat|grep|cp|scp|curl|source|base64|xxd)[[:space:]].*\.env([[:space:]]|$|\.[a-z]+)' '.env の読み取り・送信は禁止'
check '(cat|less|more|head|tail|bat|grep|cp|scp|curl|base64|xxd|tar|zip)[[:space:]][^;&|]*(\.ssh/|\.gnupg/|\.aws/|\.azure/|\.kube/|\.git-credentials|\.config/gh/|\.claude/\.credentials|\.npmrc|\.pypirc|\.docker/config|\.local/share/keyrings)' '認証情報の読み取りは禁止'
check '(~|\$HOME)/\.ssh|/\.ssh/id_' 'SSH 鍵へのアクセスは禁止'

# ---- ブランチ運用: main / develop には直接 push・commit・取り込みをしない ----
PROTECT_MSG='main / develop には直接変更しない。develop から作業ブランチ（feature/〜, fix/〜, docs/〜）を切り、develop への PR を作ること。マージはユーザーが行う'

check 'git[[:space:]]+push[[:space:]]([^;&|]*)([[:space:]:]|refs/heads/)(main|develop)([[:space:]]|$)' "main / develop への push は禁止。$PROTECT_MSG"

branch=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch="$(git -C "$cwd" symbolic-ref --short -q HEAD 2>/dev/null || true)"
fi
if [ "$branch" = "main" ] || [ "$branch" = "develop" ]; then
  if has 'git[[:space:]]+push([[:space:]]|$)'; then
    deny "いま $branch ブランチにいるため push は禁止。$PROTECT_MSG"
  fi
  if has 'git[[:space:]]+(merge|cherry-pick|revert|am|rebase)([[:space:]]|$)'; then
    deny "いま $branch ブランチにいるため、merge / cherry-pick / revert / am / rebase は禁止。$PROTECT_MSG"
  fi
  # コミットが 1 つもないリポジトリの最初のコミットだけは許可（develop を作るため）
  if has 'git[[:space:]]+commit([[:space:]]|$)' && git -C "$cwd" rev-parse --verify -q HEAD >/dev/null 2>&1; then
    deny "いま $branch ブランチにいるため commit は禁止。$PROTECT_MSG"
  fi
fi

# ---- GitHub 側の保護の確認: push / PR 作成の前に、main / develop の保護が有効かを確かめる ----
PROTECT_HOWTO='ユーザーに次を頼むこと：GitHub の Settings → Rules → Rulesets で、main と develop に「Restrict deletions」「Require a pull request before merging」「Block force pushes」をかけ、Enforcement を Active、Bypass list を空にする（.github/rulesets/protect-main-develop.json を「Import a ruleset」で読み込める）'
checker="$(dirname "${BASH_SOURCE[0]}")/check-remote-protection.sh"

protect_check() { # protect_check <push|pr> [リモート名 | URL | owner/repo]
  local out rc
  [ -f "$checker" ] || deny "GitHub 側の保護を確認できないため止めた（$checker がない）。ユーザーに状況を伝え、どうするか聞くこと"
  out="$(bash "$checker" "$cwd" "$1" "${2:-}")"
  rc=$?
  case $rc in
    0) ;;
    1) deny "GitHub 側の保護が足りないため止めた：$out。$PROTECT_HOWTO" ;;
    3) ask "$out。GitHub 側では止まらないので、push 先・PR の向き先が main / develop でないことを確かめてから許可すること" ;;
    *) deny "GitHub 側の保護を確認できないため止めた：${out:-原因不明}。ユーザーに状況を伝え、どうするか聞くこと" ;;
  esac
}

if has 'git[[:space:]]+push([[:space:]]|$)'; then
  # git push [オプション] [リモート] … の、最初のオプションでない語をリモートとみなす
  push_target=""
  read -ra words <<<"$(printf '%s' "$cmd" | grep -Eo 'git[[:space:]]+push([[:space:]][^;&|]*)?' | head -1)"
  for w in "${words[@]:2}"; do
    case "$w" in -*) ;; *) push_target="$w"; break ;; esac
  done
  set +e
  protect_check push "$push_target"
  set -e
fi

if has '(^|[;&|(`[:space:]])gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$)'; then
  pr_target="$(printf '%s' "$cmd" | grep -Eo -- '(-R|--repo)([[:space:]]+|=)[^[:space:];&|]+' | head -1 | sed -E 's/^(-R|--repo)([[:space:]]+|=)//' || true)"
  set +e
  protect_check pr "$pr_target"
  set -e
fi

exit 0
