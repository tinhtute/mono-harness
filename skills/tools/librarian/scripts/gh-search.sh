#!/usr/bin/env bash
# Known-good gh calls for GitHub code research. Run from the consumer repo root.
# Exit: 0 ok, 1 gh call failed (missing, unauthenticated, 404/403, rate limit), 2 usage error.
set -euo pipefail
CACHE=.zharness/cache/github

usage() {
  cat >&2 <<'U'
usage: gh-search.sh <command> [args]
  preflight                      gh installed + authenticated, remaining rate limit
  branch <repo>                  default branch name
  search <terms> [gh flags...]   code search (--repo, --owner, --match, --limit; default --limit 30)
  tree   <repo> [ref] [prefix]   blob paths, optionally under prefix
  ls     <repo> [dir] [ref]      directory entries: type<TAB>path
  fetch  <repo> <file> [ref]     cache file; prints the cached path
  lines  <repo> <file> <a> <b>   numbered lines a..b of a cached file
U
  exit 2
}
need() { [ "$1" -ge "$2" ] || usage; }
ref_of() { [ -n "${2:-}" ] && echo "$2" || gh repo view "$1" --json defaultBranchRef --jq '.defaultBranchRef.name'; }

cmd=${1:-}; [ -n "$cmd" ] || usage; shift
case "$cmd" in
  preflight)
    command -v gh >/dev/null || { echo "gh CLI not installed. Install: https://cli.github.com"; exit 1; }
    gh auth status >/dev/null 2>&1 || { echo "gh not authenticated. Run: gh auth login"; exit 1; }
    gh api rate_limit --jq '"ok remaining=\(.rate.remaining)/\(.rate.limit)"' ;;
  branch) need $# 1; ref_of "$1" ;;
  search)
    need $# 1; terms=$1; shift
    case " $* " in *" --limit "*) ;; *) set -- "$@" --limit 30 ;; esac
    gh search code "$terms" --json path,repository,sha,url "$@" \
      --jq '.[] | "\(.repository.nameWithOwner):\(.path)\t\(.url)"' ;;
  tree)
    need $# 1; ref=$(ref_of "$1" "${2:-}")
    gh api "repos/$1/git/trees/$ref?recursive=1" \
      --jq ".tree[] | select(.type==\"blob\" and (.path | startswith(\"${3:-}\"))) | .path" ;;
  ls)
    need $# 1; ref=$(ref_of "$1" "${3:-}"); dir=${2:+/$2}
    gh api "repos/$1/contents$dir?ref=$ref" --jq '.[] | [.type, .path] | @tsv' ;;
  fetch)
    need $# 2; ref=$(ref_of "$1" "${3:-}"); out="$CACHE/$1/$2"
    mkdir -p "$(dirname "$out")"
    gh api "repos/$1/contents/$2?ref=$ref" --jq .content | tr -d '\n' | base64 --decode > "$out"
    echo "$out" ;;
  lines)
    need $# 4; f="$CACHE/$1/$2"
    [ -f "$f" ] || { echo "not cached: $f (run fetch first)" >&2; exit 1; }
    nl -ba "$f" | sed -n "$3,$4p" ;;
  *) usage ;;
esac
