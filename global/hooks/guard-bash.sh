#!/usr/bin/env bash
# Claude Code PreToolUse フック（ユーザー全体用）: 危険な Bash コマンドを実行前に止める。
# 権限ルール（settings.json）はコマンドの先頭しか見ないため、
# && や | でつないだ途中に紛れた危険な操作をここで正規表現で検出する。
# あわせて、main / develop への直接の push・commit を止める（ブランチ運用の保護）。
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

exit 0
