#!/usr/bin/env bash
# プロジェクトの docs/05_safety.md の「BEGIN:rules」〜「END:rules」の間を、設定ファイルから作り直す。
# 使い方（プロジェクトのディレクトリで実行）:
#   bash ~/.claude/skills/safety-rules/scripts/sync-safety-doc.sh          # 作り直す
#   bash ~/.claude/skills/safety-rules/scripts/sync-safety-doc.sh --check  # 点検だけ（問題があれば終了コード 1）

set -euo pipefail
proj="$PWD"
check=false
[ "${1:-}" = "--check" ] && check=true

user_settings="$HOME/.claude/settings.json"
hook="$HOME/.claude/hooks/guard-bash.sh"
settings="$proj/.claude/settings.json"
strict="$proj/.claude/strict-settings.json"
doc="$proj/docs/05_safety.md"

problems=()
for f in "$user_settings" "$settings" "$strict"; do
  if [ -f "$f" ]; then
    jq -e . "$f" >/dev/null 2>&1 || problems+=("$f の JSON が壊れています")
  else
    problems+=("$f がありません")
  fi
done
if [ ${#problems[@]} -gt 0 ]; then
  printf '問題: %s\n' "${problems[@]}" >&2
  exit 1
fi

if ! diff -q <(jq -r '.sandbox.network.allowedDomains[]?' "$settings" | sort) \
             <(jq -r '.sandbox.network.allowedDomains[]?' "$strict" | sort) >/dev/null; then
  problems+=("許可ドメインが settings.json と strict-settings.json で一致していません")
fi
for f in "$user_settings" "$settings"; do
  if jq -e '[.permissions.deny[]?, .permissions.ask[]?] | any(test("\\(!"))' "$f" >/dev/null; then
    problems+=("$f の権限ルールに「!」で除外する書き方があります（使えません）")
  fi
done

bullets() { jq -r "$1"' | "- `" + . + "`"' "$2"; }

generate() {
  echo "<!-- BEGIN:rules（自動生成。手で編集しない。safety-rules スキルの sync-safety-doc.sh で作り直す） -->"
  echo
  echo "### ユーザー全体（~/.claude/settings.json）"
  echo
  echo "拒否:"
  echo
  bullets '.permissions.deny[]?' "$user_settings"
  echo
  echo "確認:"
  echo
  bullets '.permissions.ask[]?' "$user_settings"
  echo
  echo "### 安全フック（~/.claude/hooks/guard-bash.sh）の検出ルール"
  echo
  echo "コマンドの途中（\`&&\` や \`|\` の後）に紛れていても止める。"
  echo
  grep -E "^check(_del)? '" "$hook" | sed -E "s/^check(_del)? '.*' ['\"](.*)['\"]$/- \2/; s/。\\\$PROTECT_MSG//"
  echo "- git restore .（作業中の変更をすべて捨てる。--staged だけなら許可）"
  echo "- core.hooksPath の変更（.githooks 以外）"
  echo "- main / develop にいるときの push・commit・merge・cherry-pick・revert・am・rebase"
  echo "- gh api の書き込み（GET 以外。-f / -F / --input で値を渡すものも含む）"
  echo "- push / PR 作成の前に GitHub 側の保護を確認し、足りないとき・確認できないときは止める（Private で保護がないときは毎回確認を出す）"
  echo
  echo "### このプロジェクト（.claude/settings.json）"
  echo
  echo "拒否:"
  echo
  bullets '.permissions.deny[]?' "$settings"
  echo
  echo "確認:"
  echo
  bullets '.permissions.ask[]?' "$settings"
  echo
  echo "通信を許可しているドメイン:"
  echo
  bullets '.sandbox.network.allowedDomains[]?' "$settings"
  echo
  echo "サンドボックスの外で動かすコマンド（確認は出る）:"
  echo
  bullets '.sandbox.excludedCommands[]?' "$settings"
  echo
  echo "<!-- END:rules -->"
}

if [ ! -f "$doc" ] || ! grep -q '<!-- BEGIN:rules' "$doc" || ! grep -q '<!-- END:rules -->' "$doc"; then
  problems+=("docs/05_safety.md に BEGIN:rules / END:rules の目印がありません")
else
  new_block="$(generate)"
  tmp="$(mktemp)"
  trap 'command rm -f -- "$tmp"' EXIT
  awk -v block="$new_block" '
    /<!-- BEGIN:rules/ { print block; skip = 1; next }
    /<!-- END:rules -->/ { skip = 0; next }
    !skip { print }
  ' "$doc" > "$tmp"

  if cmp -s "$tmp" "$doc"; then
    echo "docs/05_safety.md のルール一覧は最新です"
  elif $check; then
    problems+=("docs/05_safety.md のルール一覧が古くなっています（sync-safety-doc.sh を実行してください）")
  else
    cat "$tmp" > "$doc"
    echo "docs/05_safety.md のルール一覧を更新しました"
  fi
fi

if [ ${#problems[@]} -gt 0 ]; then
  printf '問題: %s\n' "${problems[@]}" >&2
  exit 1
fi
