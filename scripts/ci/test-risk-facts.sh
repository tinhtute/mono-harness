#!/usr/bin/env bash
# shellcheck disable=SC2016 # literal $ and backticks are fixture text and bash -c args
# Fixture tests for skills/stages/check/scripts/risk-facts.sh: each case builds
# a throwaway repository, commits a base and a change, and asserts on the JSON.
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/skills/stages/check/scripts/risk-facts.sh"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }

PASSED=0
FAILED=0
REPO=""

g() {
  git -C "$REPO" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false \
    -c core.hooksPath=/dev/null "$@"
}

# new_repo NAME [AGENTS_ALWAYS_REVIEW_LINE]: repo with one base commit on main.
new_repo() {
  REPO="$ROOT/$1"
  mkdir -p "$REPO"
  g init -q -b main
  printf '# Agents\n' >"$REPO/AGENTS.md"
  if [ -n "${2:-}" ]; then printf '\n## Unattended Shipping\n\n%s\n' "$2" >>"$REPO/AGENTS.md"; fi
  mkdir -p "$REPO/src"
  printf 'fn main() {}\n' >"$REPO/src/main.rs"
  g add -A
  g commit -q -m base
  g checkout -q -b change
}

commit() {
  g add -A
  g commit -q -m change
}

facts() { (cd "$REPO" && bash "$SCRIPT" main change); }

# check NAME JQ_FILTER: the filter must evaluate true on this repo's facts.
check() {
  local out
  if out=$(facts) && jq -e "$2" >/dev/null <<<"$out"; then
    echo "  ok   $1"
    PASSED=$((PASSED + 1))
  else
    echo "  FAIL $1"
    printf '%s\n' "$out" | sed 's/^/       /'
    FAILED=$((FAILED + 1))
  fi
}

# check_rc NAME WANT CMD...: CMD must exit with WANT.
check_rc() {
  local name=$1 want=$2 rc=0
  shift 2
  "$@" >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq "$want" ]; then
    echo "  ok   $name"
    PASSED=$((PASSED + 1))
  else
    echo "  FAIL $name (rc=$rc, want $want)"
    FAILED=$((FAILED + 1))
  fi
}

echo "risk-facts.sh"

new_repo big
seq 1 500 >"$REPO/src/big.rs"
commit
check "500-line code diff counts over 400" '.counted_lines > 400 and .excluded_lines == 0'

new_repo docs
mkdir -p "$REPO/docs/guide"
seq 1 300 >"$REPO/docs/guide/a.txt"
seq 1 200 >"$REPO/README.md"
commit
check "docs-only diff counts 0 and lists the paths" \
  '.counted_lines == 0 and .excluded_lines == 500 and (.excluded_paths | index("docs/guide/a.txt") and index("README.md"))'

new_repo excl
mkdir -p "$REPO/cli/tests"
seq 1 10 >"$REPO/cli/tests/a.rs"
seq 1 10 >"$REPO/src/foo_test.go"
seq 1 10 >"$REPO/src/test_foo.py"
seq 1 10 >"$REPO/Cargo.lock"
seq 1 10 >"$REPO/src/api.generated.ts"
printf 'src/gen.rs linguist-generated\n' >"$REPO/.gitattributes"
g checkout -q main
g add .gitattributes
g commit -q -m "base attributes"
g checkout -q -B change
seq 1 10 >"$REPO/src/gen.rs"
seq 1 7 >"$REPO/src/lib.rs"
commit
check "tests, lockfiles and generated files are excluded" \
  '.counted_lines == 7 and (.excluded_paths | length == 6) and .manifest_or_lockfile_touched == true'

new_repo selfgen
printf '*.rs linguist-generated\n' >"$REPO/.gitattributes"
seq 1 500 >"$REPO/src/big.rs"
commit
check "the PR's own .gitattributes cannot exempt its code" \
  '.counted_lines > 400 and (.excluded_paths | index("src/big.rs") | not)'

new_repo specs
mkdir -p "$REPO/web" "$REPO/test"
printf 'a\n' >"$REPO/web/foo.spec.ts"
printf 'b\n' >"$REPO/test/a_case.js"
g checkout -q main
g add -A
g commit -q -m "base specs"
g checkout -q -B change
g rm -q web/foo.spec.ts test/a_case.js
commit
check "*.spec.* and test/ files are tests" \
  '.test_changes.removed_files == ["test/a_case.js", "web/foo.spec.ts"]'

new_repo ci '- Always-review paths: scripts/ci/**, .github/**, cli/Cargo.toml'
mkdir -p "$REPO/.github/workflows"
printf 'on: push\n' >"$REPO/.github/x.yml"
commit
check ".github/x.yml is an always-review hit and CI config" \
  '.always_review_hits == [".github/x.yml"] and .ci_config_touched == true'

new_repo tworeview "$(printf -- '- Always-review paths: setup/**\n- Always-review paths: db/**')"
mkdir -p "$REPO/db"
printf 'x\n' >"$REPO/db/x.sql"
commit
check "every Always-review line counts" '.always_review_hits == ["db/x.sql"]'

new_repo noagents
printf 'x\n' >"$REPO/.gitlab-ci.yml"
printf '# changed\n' >>"$REPO/AGENTS.md"
commit
check "no Always-review line: only AGENTS.md itself hits" \
  '.always_review_hits == ["AGENTS.md"] and .ci_config_touched == true'

new_repo skip
printf '#[test]\n#[ignore]\nfn slow() {}\n' >>"$REPO/src/main.rs"
printf 'exit(1)\nxit("later", () => {})\n' >"$REPO/src/a.js"
printf 'Add `#[ignore]` to skip.\n' >"$REPO/NOTES.md"
commit
check "added #[ignore] and xit( are skip markers; exit( and docs are not" \
  '.test_changes.skip_markers_added == ["src/a.js:2: xit(\"later\", () => {})", "src/main.rs:3: #[ignore]"]'

export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=diff.noprefix GIT_CONFIG_VALUE_0=true
check "diff.noprefix=true still attributes skip markers" \
  '.test_changes.skip_markers_added | length == 2'
unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0

new_repo oddskip
printf 'xit(1)\n' >"$REPO/src/we\"ird.js"
printf 'xit(2)\n' >"$REPO/src/my spec.js"
commit
check "skip markers keep paths with a quote or a space" \
  '.test_changes.skip_markers_added == ["src/my spec.js:1: xit(2)", "src/we\"ird.js:1: xit(1)"]'

new_repo removed
mkdir -p "$REPO/tests"
printf 'a\n' >"$REPO/tests/a.rs"
printf 'b\n' >"$REPO/tests/b.rs"
g checkout -q main
g add -A
g commit -q -m "base tests"
g checkout -q -B change
g rm -q tests/a.rs
g mv tests/b.rs tests/c.rs
commit
check "deleted test file is removed; a renamed one is not" \
  '.test_changes.removed_files == ["tests/a.rs"]'

new_repo manifest
printf '{}\n' >"$REPO/package.json"
commit
check "manifest change is flagged" '.manifest_or_lockfile_touched == true and .ci_config_touched == false'

new_repo quote
mkdir -p "$REPO/docs"
printf 'x\n' >"$REPO/docs/we\"ird *name.md"
commit
check "path with a quote, space and * is escaped, not expanded" \
  '.excluded_paths == ["docs/we\"ird *name.md"]'

new_repo empty
check "no change: zero facts" \
  '.counted_lines == 0 and .excluded_paths == [] and .always_review_hits == [] and .test_changes.removed_files == [] and .ci_config_touched == false'

check_rc "--help exits 0" 0 bash "$SCRIPT" --help
check_rc "bad ref exits 2" 2 bash -c 'cd "$1" && bash "$2" main no-such-ref' _ "$REPO" "$SCRIPT"
check_rc "missing argument exits 2" 2 bash -c 'cd "$1" && bash "$2" main' _ "$REPO" "$SCRIPT"
check_rc "outside a repository exits 2" 2 bash -c 'cd "$1" && bash "$2" main change' _ "$ROOT" "$SCRIPT"

echo "passed: $PASSED  failed: $FAILED"
[ "$FAILED" -eq 0 ]
