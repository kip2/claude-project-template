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
