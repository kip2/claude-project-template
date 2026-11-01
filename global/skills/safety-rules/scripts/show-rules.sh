#!/usr/bin/env bash
# 安全ルールを、ユーザー全体（~/.claude）とプロジェクト（./.claude）に分けて一覧表示する。
# 使い方: bash ~/.claude/skills/safety-rules/scripts/show-rules.sh [プロジェクトのディレクトリ]

set -euo pipefail
proj="${1:-$PWD}"
user_settings="$HOME/.claude/settings.json"
proj_settings="$proj/.claude/settings.json"
strict_settings="$proj/.claude/strict-settings.json"
hook="$HOME/.claude/hooks/guard-bash.sh"

print_perms() {
  local f="$1"
  echo "  [拒否]"
  jq -r '.permissions.deny[]? | "    " + .' "$f"
  echo "  [確認]"
  jq -r '.permissions.ask[]? | "    " + .' "$f"
}

echo "== ユーザー全体（~/.claude/settings.json） =="
if [ -f "$user_settings" ]; then
  print_perms "$user_settings"
  echo "  [設定]"
  jq -r '
    "    権限チェックを飛ばすモード: " + (if .permissions.disableBypassPermissionsMode == "disable" then "禁止" else "使える" end),
    "    会話の履歴を残す日数: \(.cleanupPeriodDays // 30)",
    "    利用状況の送信: " + (if .env.DISABLE_TELEMETRY == "1" then "止めている" else "送っている" end),
    "    プロジェクトの MCP サーバーの自動有効化: " + (if .enableAllProjectMcpServers == false then "しない" else "する" end)
  ' "$user_settings"
else
  echo "  （ファイルがありません）"
fi

echo
echo "== 安全フック（~/.claude/hooks/guard-bash.sh）の検出ルール =="
if [ -f "$hook" ]; then
  grep -E "^check(_del)? '" "$hook" | sed -E "s/^check(_del)? '.*' ['\"](.*)['\"]$/  - \2/; s/。\\\$PROTECT_MSG//"
  echo "  - git restore .（作業中の変更をすべて捨てる。--staged だけなら許可）"
  echo "  - core.hooksPath の変更（.githooks 以外）"
  echo "  - main / develop にいるときの push・commit・merge・cherry-pick・revert・am・rebase"
  echo "  - gh api の書き込み（GET 以外。-f / -F / --input で値を渡すものも含む）"
  echo "  - push / PR 作成の前に GitHub 側の保護を確認し、足りないとき・確認できないときは止める（Private で保護がないときは毎回確認を出す）"
  echo "  ※ 削除に関するルールに引っかかったときは、フォルダの中身を示してユーザーに削除を依頼する"
else
  echo "  （フックがありません）"
fi

echo
echo "== プロジェクト（$proj） =="
if [ -f "$proj_settings" ]; then
  print_perms "$proj_settings"
  echo "  [サンドボックス]"
  jq -r '.sandbox // {} |
    "    有効: " + (if .enabled == true then "はい" else "いいえ" end)
    + " / 起動できなければ止める: " + (if .failIfUnavailable == true then "はい" else "いいえ" end)
    + " / サンドボックスの外での実行: " + (if .allowUnsandboxedCommands == false then "禁止" else "可" end)' "$proj_settings"
  echo "  [通信を許可するドメイン]"
  jq -r '.sandbox.network.allowedDomains[]? | "    " + .' "$proj_settings"
  if [ -f "$strict_settings" ] && ! diff -q \
      <(jq -r '.sandbox.network.allowedDomains[]?' "$proj_settings" | sort) \
      <(jq -r '.sandbox.network.allowedDomains[]?' "$strict_settings" | sort) >/dev/null; then
    echo "    ※ settings.json と strict-settings.json で一致していません"
  fi
  echo "  [サンドボックスの外で動かすコマンド]"
  jq -r '.sandbox.excludedCommands[]? | "    " + .' "$proj_settings"
else
  echo "  （.claude/settings.json がありません）"
fi

echo
echo "== git のフック（ブランチ保護） =="
if git -C "$proj" rev-parse --git-dir >/dev/null 2>&1; then
  hp="$(git -C "$proj" config --get core.hooksPath 2>/dev/null || true)"
  if [ "$hp" = ".githooks" ] && [ -x "$proj/.githooks/pre-push" ] && [ -x "$proj/.githooks/pre-commit" ]; then
    echo "  有効（.githooks/pre-push, pre-commit）"
  else
    echo "  無効（core.hooksPath=${hp:-未設定}。git config core.hooksPath .githooks と chmod +x .githooks/* が必要）"
  fi
  echo "  現在のブランチ: $(git -C "$proj" symbolic-ref --short -q HEAD 2>/dev/null || echo 不明)"
else
  echo "  git リポジトリではありません"
fi

echo
echo "== GitHub（push 先の保護と、gh のトークン） =="
checker="$HOME/.claude/hooks/check-remote-protection.sh"
SANDBOX_NOTE="サンドボックスの中では gh を使えないことがある。自分のターミナルでこのスクリプトを実行すると確認できる"
if ! git -C "$proj" rev-parse --git-dir >/dev/null 2>&1 || [ -z "$(git -C "$proj" remote 2>/dev/null)" ]; then
  echo "  リモートがありません（GitHub に上げていない）"
elif [ ! -f "$checker" ]; then
  echo "  確認できません（$checker がありません）"
else
  rc=0
  out="$(bash "$checker" "$proj" push)" || rc=$?
  case $rc in
    0) echo "  push 先の保護: 有効（main / develop に PR 必須・強制 push 禁止・削除禁止。自分は例外ではない）" ;;
    1) echo "  push 先の保護: 足りない（$out）" ;;
    3) echo "  push 先の保護: なし（$out）。Claude の push と PR 作成のたびに確認が出る" ;;
    *) echo "  push 先の保護: 確認できない（$out）。$SANDBOX_NOTE" ;;
  esac

  rc=0
  headers="$(timeout 8 gh api -i rate_limit 2>/dev/null | tr -d '\r')" || rc=$?
  if [ $rc -ne 0 ]; then
    echo "  トークンの期限: 確認できない。$SANDBOX_NOTE"
  else
    exp="$(sed -nE 's/^github-authentication-token-expiration: *//Ip' <<<"$headers" | head -1)"
    if [ -z "$exp" ]; then
      echo "  トークンの期限: なし（Claude 用の期限付きトークンではない可能性がある）"
    else
      days=$(( ($(date -d "$exp" +%s) - $(date +%s)) / 86400 ))
      if [ "$days" -lt 7 ]; then
        echo "  トークンの期限: $exp（残り $days 日）※ 7 日を切っています。GitHub の画面で作り直し、gh auth login --with-token で入れ直す"
      else
        echo "  トークンの期限: $exp（残り $days 日）"
      fi
    fi
  fi
fi
