#!/usr/bin/env bash
# Group staged files into commit kinds: deps, config, test, docs, code.
# A manifest stays with its lockfile (deps); a co-located test stays with its source (code).
# Prints "<kind>: <file>" lines sorted by kind. Exit: 0 ok, 2 not a git repo.
set -euo pipefail
git rev-parse --git-dir >/dev/null 2>&1 || { echo "usage: run inside a git repository" >&2; exit 2; }

mapfile -t staged < <(git diff --cached --name-only)
declare -A present=()
for f in "${staged[@]}"; do present[$f]=1; done

# Source file a co-located test covers: foo_test.go, foo.spec.ts, foo.test.ts, foo_test.py, test_foo.py.
source_of() {
  local d b; d=$(dirname "$1"); b=$(basename "$1")
  for c in "${b/_test./.}" "${b/.spec./.}" "${b/.test./.}" "${b#test_}"; do
    [ "$c" != "$b" ] && [ -n "${present[$d/$c]:-}${present[$c]:-}" ] && { echo yes; return; }
  done
}

for f in "${staged[@]}"; do
  b=$(basename "$f")
  case "$b" in
    package.json|package-lock.json|yarn.lock|pnpm-lock.yaml|go.mod|go.sum|Cargo.toml|Cargo.lock|pyproject.toml|requirements*.txt|poetry.lock|uv.lock) k=deps ;;
    *) case "$f" in
         .claude/*|*/.claude/*) k=config ;;
         tests/*|*/tests/*|__tests__/*|*/__tests__/*) k=test ;;
         *_test.*|*.spec.*|*.test.*|test_*.py) [ -n "$(source_of "$f")" ] && k=code || k=test ;;
         *.md|*.txt) k=docs ;;
         *) k=code ;;
       esac ;;
  esac
  echo "$k: $f"
done | sort
