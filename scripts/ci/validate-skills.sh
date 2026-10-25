#!/bin/bash
# validate-skills.sh - run validate-skill.sh over every tracked SKILL.md.
#
# CI entrypoint for .github/workflows/skills-ci.yml. With no arguments it checks
# every `git ls-files '*SKILL.md'` except the committed bad fixtures under
# scripts/ci/fixtures/; with arguments it checks exactly those files (the
# workflow uses that to prove a bad fixture fails). Exit 1 if any skill has an
# error; warnings print but never fail.

set -euo pipefail
cd "$(dirname "$0")/../.."

if [ "$#" -gt 0 ]; then
  files=("$@")
else
  files=()
  while IFS= read -r f; do files+=("$f"); done < <(git ls-files '*SKILL.md' | grep -v '^scripts/ci/fixtures/')
fi

if [ "${#files[@]}" -eq 0 ]; then
  echo "❌ no SKILL.md files to validate"
  exit 1
fi

failed=()
for f in "${files[@]}"; do
  bash scripts/ci/validate-skill.sh "$f" || failed+=("$f")
done

echo ""
if [ "${#failed[@]}" -gt 0 ]; then
  echo "❌ ${#failed[@]} of ${#files[@]} skill(s) failed:"
  printf '  %s\n' "${failed[@]}"
  exit 1
fi
echo "✅ ${#files[@]} skill(s) valid"
