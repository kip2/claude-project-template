#!/usr/bin/env bash
# Claude Code を安全モードで起動する。
#   - 必要なツール（bwrap / socat / jq）があるか確認
#   - .claude/strict-settings.json を --settings で渡す
#     （プロジェクト設定より優先され、通信は許可ドメインのみに厳格化される）
#
# 使い方: ./scripts/claude-safe.sh [claude の引数...]

set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

missing=()
for bin in claude bwrap socat jq; do
  command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "必要なコマンドが見つかりません: ${missing[*]}" >&2
  echo "インストール例: sudo pacman -S bubblewrap socat jq" >&2
  exit 1
fi

for arg in "$@"; do
  case "$arg" in
    --dangerously-skip-permissions|--permission-mode=bypassPermissions)
      echo "安全モードでは $arg は使えません。" >&2
      exit 1
      ;;
  esac
done

cd "$project_dir"
exec claude --settings "$project_dir/.claude/strict-settings.json" "$@"
