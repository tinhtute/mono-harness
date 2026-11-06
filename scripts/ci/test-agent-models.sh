#!/usr/bin/env bash
# models.json is the role -> model policy for the harness agents; each agents/*.md
# must carry the model its tier names, and every agent file must have a policy row.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
policy="$root/models.json"
fail=0
listed=$(jq -r '.agents[].agent' "$policy" | sort)
present=$(cd "$root/agents" && ls *.md | sed 's/\.md$//' | sort)
if [ "$listed" != "$present" ]; then
  echo "agent files and models.json rows differ:"; diff <(echo "$listed") <(echo "$present") || true; fail=1
fi
for a in $listed; do
  want=$(jq -r --arg a "$a" '.tiers[(.agents[]|select(.agent==$a).tier)]' "$policy")
  jq -e --arg m "$want" '.available|index($m)' "$policy" >/dev/null || { echo "$a: tier model '$want' not in available"; fail=1; }
  f="$root/agents/$a.md"
  [ -f "$f" ] || continue
  got=$(awk '/^---$/{n++;next} n==1 && /^model:/{print $2}' "$f")
  name=$(awk '/^---$/{n++;next} n==1 && /^name:/{print $2}' "$f")
  [ "$got" = "$want" ] || { echo "$a: model '$got', policy wants '$want'"; fail=1; }
  [ "$name" = "$a" ] || { echo "$a: frontmatter name '$name'"; fail=1; }
  if jq -e --arg a "$a" '.readOnly|index($a)' "$policy" >/dev/null; then
    tools=$(awk '/^---$/{n++;next} n==1 && /^tools:/{sub(/^tools:[[:space:]]*/,"");print}' "$f")
    [ -n "$tools" ] || { echo "$a: read-only agent has no tools allowlist"; fail=1; }
    case ", $tools," in *", Edit,"*|*", Write,"*|*", NotebookEdit,"*) echo "$a: read-only agent allows an edit tool: $tools"; fail=1 ;; esac
  fi
done
[ "$fail" -eq 0 ] && echo "agent models OK ($(echo "$listed" | wc -l | tr -d ' ') agents)"
exit "$fail"
