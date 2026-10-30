#!/usr/bin/env bash
# Scan staged files for secrets and risky filenames. Prints file:line only, never the value.
# Exit: 0 clean, 1 hit, 2 not a git repo.
set -euo pipefail
git rev-parse --git-dir >/dev/null 2>&1 || { echo "usage: run inside a git repository" >&2; exit 2; }

pattern="AKIA[0-9A-Z]{16}|-----BEGIN ([A-Z]+ )*PRIVATE KEY|://[^/:@ ]+:[^/@ ]+@|(api[_-]?key|token|password|secret)[\"']?[[:space:]]*[:=]"
hits=$(git diff --cached --name-only --diff-filter=ACMR -z \
  | xargs -0 -r git grep --cached -nE "$pattern" -- 2>/dev/null | cut -d: -f1-2 || true)
files=$(git diff --cached --name-only --diff-filter=ACMR \
  | grep -E '(^|/)(\.env(\..*)?|[^/]*\.(key|pem|p12)|credentials\.json|secrets\.json)$' \
  | grep -vE '\.example$' || true)

[ -n "$hits" ] && printf 'secret: %s\n' $hits
[ -n "$files" ] && printf 'file: %s\n' $files
[ -z "$hits$files" ] && { echo "ok"; exit 0; }
exit 1
