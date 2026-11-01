#!/usr/bin/env bash
# 新しいプロジェクトを GitHub に上げ、ブランチ保護などの設定を 1 回で行う。
# ユーザーが自分のターミナルで、プロジェクトのフォルダで実行する（Claude には実行させない）。
#
# 使い方: bash ~/.claude/skills/new-project/scripts/github-setup.sh [--private] [リポジトリ名]
#   リポジトリ名を省くと、フォルダ名を使う。既定は Public。
#
# 管理用のログイン（リポジトリの作成・設定の変更ができる）は、このスクリプトの間だけ一時フォルダに作り、
# 終わったら（途中で止まっても）ログアウトして消す。
# 設計は claude-project-template の docs/design.md の 6.10。

set -uo pipefail

if [ -n "${CLAUDECODE:-}" ]; then
  echo "このスクリプトは Claude Code の中からは実行できません。自分のターミナルで実行してください。" >&2
  exit 1
fi

# ---- 表示 ----
step() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
ok() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
note() { printf '  \033[33m!\033[0m %s\n' "$*"; }
die() { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }
# 入力が閉じている（ターミナルからの実行でない）ときは、確認を飛ばさずに中止する
pause() { read -r -p "  $1 [Enter で続ける / Ctrl+C で中止] " _ || die "入力がないため中止しました"; }

usage() {
  sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

# ---- 引数 ----
visibility=public
name=""
for a in "$@"; do
  case "$a" in
    --private) visibility=private ;;
    --public) visibility=public ;;
    -h|--help) usage ;;
    -*) die "知らないオプションです: $a（--private / --public / --help）" ;;
    *) name="$a" ;;
  esac
done
[ -n "$name" ] || name="$(basename "$PWD")"

problems=()
TOKEN_URL="https://github.com/settings/personal-access-tokens"
ruleset_file=".github/rulesets/protect-main-develop.json"
[ -f "$ruleset_file" ] || ruleset_file="$HOME/.claude/skills/new-project/template/.github/rulesets/protect-main-develop.json"
checker="$HOME/.claude/hooks/check-remote-protection.sh"

# ---- 管理用ログイン（一時フォルダ）と後始末 ----
admin_dir=""
admin() { GH_CONFIG_DIR="$admin_dir" gh "$@"; }
cleanup() {
  if [ -n "$admin_dir" ] && [ -d "$admin_dir" ]; then
    GH_CONFIG_DIR="$admin_dir" gh auth logout --hostname github.com </dev/null >/dev/null 2>&1 || true
    rm -r -f -- "$admin_dir"
    echo
    echo "  （管理用のログインを消しました）"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# ============================================================
step "1. 前提の確認"
for c in git gh jq gitleaks; do
  command -v "$c" >/dev/null 2>&1 || die "$c が見つかりません（sudo pacman -S で入れてください）"
done
git rev-parse --git-dir >/dev/null 2>&1 || die "ここは git リポジトリではありません。プロジェクトのフォルダで実行してください"
for b in main develop; do
  git rev-parse --verify -q "refs/heads/$b" >/dev/null || die "$b ブランチがありません（/new-project の 3 章を先に済ませてください）"
done
git remote get-url origin >/dev/null 2>&1 && die "origin がすでにあります（GitHub に上げ済みかもしれません）: $(git remote get-url origin)"
[ -f "$ruleset_file" ] || die "ブランチ保護の設定（protect-main-develop.json）が見つかりません"
[ -f "$checker" ] || die "$checker がありません（claude-project-template の README のとおりに ~/.claude に入れてください）"
gh auth status >/dev/null 2>&1 || die "gh に Claude 用のトークンでログインしていません（claude-project-template の README の「Claude 用のトークン」）"
[ -z "$(git status --porcelain)" ] || note "コミットしていない変更があります。上がるのはコミット済みのものだけです"
ok "前提は満たしています"

# ============================================================
step "2. 秘密情報の検査（全履歴）"
# 最初の push は git のフックを飛ばす（--no-verify）ので、pre-push の検査の代わりにここで調べる
if ! gitleaks git --no-banner --redact . ; then
  die "秘密情報らしきものが見つかりました。コミットから取り除いてから、もう一度実行してください"
fi
ok "秘密情報は見つかりませんでした"

# ============================================================
step "3. 上げる内容の確認"
echo "  リポジトリ名: $name"
echo "  公開範囲    : $visibility"
if [ "$visibility" = private ]; then
  note "Private（無料プラン）では、GitHub 側のブランチ保護とシークレットスキャンの push 保護が使えません。"
  note "守りはローカル（安全フック・git のフック）だけになり、Claude の push と PR 作成は毎回確認が出ます。"
else
  note "Public なので、コード・ドキュメント・Q&A ログは誰でも見られます。"
fi
echo "  上げるファイル（develop ブランチ）:"
git ls-tree -r --name-only develop | sed 's/^/    /'
pause "この内容で GitHub に上げてよければ"

# ============================================================
step "4. 管理用ログイン（ブラウザで承認）"
admin_dir="$(mktemp -d)"
chmod 700 "$admin_dir"
echo "  リポジトリの作成と設定のために、一時的に管理用のログインをします。"
echo "  画面に出るコード（XXXX-XXXX）をブラウザに入れて、Authorize を押してください。"
echo "  「Authenticate Git with your GitHub credentials?」と聞かれたら n で構いません。"
# keyring に入れると、同じアカウントの Claude 用のトークンを上書きするため、一時フォルダのファイルに保存する
admin auth login --hostname github.com --git-protocol https --web --insecure-storage || die "管理用ログインに失敗しました"
owner="$(admin api user --jq .login)" || die "管理用ログインのアカウントが読めません"
repo="$owner/$name"
ok "$owner でログインしました"

# ============================================================
step "5. リポジトリの作成"
if out="$(admin repo create "$repo" "--$visibility" 2>&1)"; then
  ok "作成しました: https://github.com/$repo"
else
  die "作成できませんでした: $out"
fi
git remote add origin "https://github.com/$repo.git" || die "origin を足せませんでした"
ok "origin を足しました"

# ============================================================
step "6. Claude 用のトークンに追加して、最初の push"
cat <<EOF
  Claude 用のトークンの対象に、このリポジトリを足します（API ではできないため、ブラウザで行います）。

    1. 開いたページで、Claude 用のトークン（例: claude-code）の名前をクリック
    2. 右上の「Edit」を押す
    3. Repository access の「Only select repositories」の選択欄で、$repo を選ぶ
    4. 一番下の「Update」を押す

  ブラウザが開かなければ、次の URL を開いてください: $TOKEN_URL
EOF
xdg-open "$TOKEN_URL" >/dev/null 2>&1 || true
pause "追加できたら"

# 足したかどうかは、Claude 用のトークンで実際に push できるかで確かめる（読み取りは対象外でもできるため）
while :; do
  # main / develop の最初の push は git のフックが止めるので飛ばす（秘密情報は 2. で検査済み）
  if git push --no-verify -u origin main develop; then
    ok "main と develop を push しました"
    break
  fi
  note "push できませんでした。Claude 用のトークンの対象に $repo が入っていない可能性があります。"
  note "上の 1〜4 を確認してください（Update を押し忘れていないか）。"
  pause "確認できたら（もう一度 push します）"
done

# ============================================================
step "7. GitHub の設定"

# 試して、Private（無料プラン）で断られたら飛ばす
try_setting() { # try_setting <説明> <Private で断られうるか: yes|no> <gh の引数...>
  local label="$1" may_fail_private="$2" out
  shift 2
  if out="$(admin "$@" 2>&1)"; then
    ok "$label"
  elif [ "$visibility" = private ] && [ "$may_fail_private" = yes ]; then
    note "$label: Private（無料プラン）では使えないため飛ばしました"
  else
    note "$label: 失敗しました（$out）"
    problems+=("$label")
  fi
}

try_setting "ブランチ保護（ruleset）を登録" yes \
  api -X POST "repos/$repo/rulesets" --input "$ruleset_file"
try_setting "シークレットスキャンと push 保護を有効化" yes \
  api -X PATCH "repos/$repo" \
  -f 'security_and_analysis[secret_scanning][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'
try_setting "Actions の権限を読み取りのみにし、PR の作成・承認を不可に" no \
  api -X PUT "repos/$repo/actions/permissions/workflow" \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false
try_setting "既定のブランチを develop に" no \
  api -X PATCH "repos/$repo" -f default_branch=develop
try_setting "自動マージをオフに" no \
  api -X PATCH "repos/$repo" -F allow_auto_merge=false

# ============================================================
step "8. 確認（Claude の push 前の確認と同じもの。Claude 用のトークンで行う）"
rc=0
out="$(bash "$checker" . push)" || rc=$?
case $rc in
  0) ok "GitHub 側の保護: 有効（Claude の push は、このまま通ります）" ;;
  3) note "GitHub 側の保護: なし（$out）"
     note "Claude の push と PR 作成のたびに、確認が出ます" ;;
  *) note "GitHub 側の保護: 問題あり（$out）"
     problems+=("GitHub 側の保護の確認") ;;
esac

# ============================================================
step "結果"
echo "  リポジトリ: https://github.com/$repo（$visibility）"
if [ ${#problems[@]} -eq 0 ]; then
  ok "すべて完了しました。Claude Code に戻って「GitHub に上げた」と伝えてください。"
else
  note "うまくいかなかったもの:"
  for p in "${problems[@]}"; do echo "      - $p"; done
  note "Claude Code に戻って、この画面の内容を伝えてください。"
  exit 1
fi
