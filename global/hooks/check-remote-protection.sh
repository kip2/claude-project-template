#!/usr/bin/env bash
# GitHub 側のブランチ保護（main / develop）が有効かを確かめる。
# 安全フック（guard-bash.sh）が git push / gh pr create の前に呼ぶ。/safety-rules の点検からも呼ぶ。
#
# 使い方: check-remote-protection.sh <git のディレクトリ> <push|pr> [リモート名 | URL | owner/repo]
#   push: 3 つ目を省くと、現在のブランチの upstream のリモート、なければ origin を見る
#   pr  : 3 つ目を省くと、gh の既定（gh repo set-default）、upstream、origin の順に見る
#
# 終了コード: 0 = 保護あり / 1 = 保護が足りない / 2 = 確認できない
# 1 と 2 のときは、理由を 1 行で標準出力に出す。

set -uo pipefail

dir="${1:-.}"
mode="${2:-push}"
target="${3:-}"
BRANCHES=(main develop)
REQUIRED=(pull_request non_fast_forward deletion)
TIMEOUT=8

weak() { echo "$1"; exit 1; }
unknown() { echo "$1"; exit 2; }

command -v gh >/dev/null 2>&1 || unknown "gh が見つからない"
command -v jq >/dev/null 2>&1 || unknown "jq が見つからない"

# GitHub の URL から owner/repo を取り出す（GitHub 以外なら空）
repo_from_url() {
  sed -nE 's#^(https://([^@/]+@)?github\.com/|git@github\.com:|ssh://git@github\.com/|github\.com/)([^/]+/[^/]+)$#\3#p' <<<"$1" \
    | sed -E 's#/$##; s#\.git$##'
}

has_remote() { git -C "$dir" remote 2>/dev/null | grep -qx -- "$1"; }

# ---- 確認する相手（owner/repo）を決める ----
repo=""
if [[ "$target" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] && ! has_remote "$target"; then
  repo="$target"
elif [[ "$target" == *github.com* ]]; then
  repo="$(repo_from_url "$target")"
  [ -n "$repo" ] || unknown "$target が GitHub のリポジトリとして読めない"
else
  remote="$target"
  if [ -z "$remote" ]; then
    git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || unknown "$dir は git リポジトリではない"
    if [ "$mode" = pr ]; then
      remote="$(git -C "$dir" config --get-regexp '^remote\..*\.gh-resolved$' 2>/dev/null | awk '$2 == "base" { sub(/^remote\./, "", $1); sub(/\.gh-resolved$/, "", $1); print $1; exit }')"
      [ -n "$remote" ] || { has_remote upstream && remote=upstream; }
    else
      branch="$(git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null || true)"
      [ -n "$branch" ] && remote="$(git -C "$dir" config --get "branch.$branch.remote" 2>/dev/null || true)"
    fi
    [ -n "$remote" ] || remote=origin
  fi
  url="$(git -C "$dir" remote get-url --push "$remote" 2>/dev/null)" || unknown "リモート「$remote」が見つからない"
  repo="$(repo_from_url "$url")"
  [ -n "$repo" ] || unknown "リモート「$remote」（$url）は GitHub ではない"
fi

api() { timeout "$TIMEOUT" gh api "$1" 2>/dev/null; }
API_FAIL="GitHub の API で $repo を読めない（オフライン、gh のログイン切れ、トークンの対象に入っていない、など）"

# ---- 公開範囲 ----
info="$(api "repos/$repo")" || unknown "$API_FAIL"
private="$(jq -r '.private' <<<"$info" 2>/dev/null)"   # true / false / null（// は false も空扱いするので使わない）
[ "$private" = false ] || {
  [ "$private" = true ] && weak "$repo は Private。無料プランの Private リポジトリでは GitHub のブランチ保護が効かない"
  unknown "$repo の公開範囲が分からない"
}

# ---- main / develop にかかっているルール ----
# このエンドポイントは「有効（active）」なルールだけを返す。試験モード（evaluate）のルールは含まれない。
missing=()
ids=()
for b in "${BRANCHES[@]}"; do
  rules="$(api "repos/$repo/rules/branches/$b")" || unknown "$API_FAIL"
  jq -e 'type == "array"' <<<"$rules" >/dev/null 2>&1 || unknown "$repo の $b のルールが読めない"
  for r in "${REQUIRED[@]}"; do
    jq -e --arg t "$r" 'any(.[]; .type == $t)' <<<"$rules" >/dev/null || missing+=("$b:$r")
  done
  while read -r id; do [ -n "$id" ] && ids+=("$id"); done < <(jq -r '.[].ruleset_id // empty' <<<"$rules")
done

if [ ${#missing[@]} -gt 0 ]; then
  weak "$repo に有効なルールが足りない（${missing[*]}）"
fi

# ---- 自分が例外（bypass）になっていないか ----
for id in $(printf '%s\n' "${ids[@]}" | sort -u); do
  rs="$(api "repos/$repo/rulesets/$id?includes_parents=true")" || unknown "$API_FAIL"
  bypass="$(jq -r '.current_user_can_bypass // empty' <<<"$rs" 2>/dev/null)"
  case "$bypass" in
    never) ;;
    "") unknown "$repo の ruleset（$id）で、自分が例外（bypass）かどうかが読めない" ;;
    *) weak "$repo の ruleset（$id）で、自分が例外（bypass: $bypass）になっている" ;;
  esac
done

exit 0
