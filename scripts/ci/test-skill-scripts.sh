#!/usr/bin/env bash
# Fixture tests for skill scripts: one hit and one miss case per script.
# Run: bash scripts/ci/test-skill-scripts.sh
# SKILL_SCRIPTS_ROOT points at an alternate tree holding skills/ (mutation checks).
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
root=${SKILL_SCRIPTS_ROOT:-$here}
fx="$here/scripts/ci/fixtures/skill-scripts"
# Run from inside a Git hook, the caller's GIT_* would steer fixture repos.
# shellcheck disable=SC2046
unset $(git rev-parse --local-env-vars)

tmp=$(mktemp -d)
cleanup() { if command -v trash >/dev/null 2>&1; then trash "$tmp" 2>/dev/null || true; else rm -rf "${tmp:?}"; fi; }
trap cleanup EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  ok  - $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL - $1"; }

out=""
rc=0
run() { rc=0; out=$("$@" 2>&1) || rc=$?; }
expect() { # <name> <want-rc>
	if [ "$rc" -eq "$2" ]; then ok "$1 (rc=$rc)"; else bad "$1: want rc=$2, got rc=$rc: $out"; fi
}

newrepo() { rm -rf "${tmp:?}/r"; mkdir "$tmp/r"; git -C "$tmp/r" init -q; }

scan="$root/skills/tools/git/scripts/scan-staged.sh"
group="$root/skills/tools/git/scripts/group-staged.sh"
lint="$root/skills/reason/ambition/scripts/lint-prompt.sh"
ghs="$root/skills/tools/librarian/scripts/gh-search.sh"
fetch="$root/skills/tools/read/scripts/fetch.sh"
digest="$root/skills/stages/retro/scripts/session-digest.py"

# scan-staged.sh
secret="AKIA$(printf 'A%.0s' $(seq 16))"
newrepo
printf 'key = %s\n' "$secret" > "$tmp/r/cfg.txt"
git -C "$tmp/r" add cfg.txt
run bash -c "cd '$tmp/r' && bash '$scan'"
expect "scan-staged hit: staged AKIA key" 1
case "$out" in *cfg.txt:1*) ok "scan-staged hit prints file:line" ;; *) bad "scan-staged hit missing file:line: $out" ;; esac
case "$out" in *"$secret"*) bad "scan-staged leaked the key value" ;; *) ok "scan-staged hides the key value" ;; esac
newrepo
echo "hello world" > "$tmp/r/a.txt"
git -C "$tmp/r" add a.txt
run bash -c "cd '$tmp/r' && bash '$scan'"
expect "scan-staged miss: clean stage" 0
run bash -c "cd '$tmp' && GIT_CEILING_DIRECTORIES='$tmp' bash '$scan'"
expect "scan-staged usage: outside a repo" 2

# group-staged.sh
newrepo
mkdir "$tmp/r/src"
echo '{}' > "$tmp/r/package.json"
echo '# d' > "$tmp/r/README.md"
echo 'x' > "$tmp/r/src/app.js"
git -C "$tmp/r" add -A
run bash -c "cd '$tmp/r' && bash '$group'"
expect "group-staged hit: mixed stage" 0
want=$'code: src/app.js\ndeps: package.json\ndocs: README.md'
if [ "$(printf '%s\n' "$out" | sort)" = "$(printf '%s\n' "$want" | sort)" ]; then
	ok "group-staged classifies deps/docs/code"
else
	bad "group-staged output: $out"
fi
newrepo
run bash -c "cd '$tmp/r' && bash '$group'"
expect "group-staged miss: empty stage" 0
if [ -z "$out" ]; then ok "group-staged empty stage prints nothing"; else bad "group-staged empty output: $out"; fi
run bash -c "cd '$tmp' && GIT_CEILING_DIRECTORIES='$tmp' bash '$group'"
expect "group-staged usage: outside a repo" 2

# lint-prompt.sh
run bash "$lint" "$fx/bad-prompt.txt"
expect "lint-prompt hit: missing slots" 1
case "$out" in *"Instruments: missing"*) ok "lint-prompt names the missing slot" ;; *) bad "lint-prompt output: $out" ;; esac
run bash "$lint" "$fx/good-prompt.txt"
expect "lint-prompt miss: complete prompt" 0
run bash "$lint" --lens bogus "$fx/good-prompt.txt"
expect "lint-prompt usage: bad lens" 2

# gh-search.sh, offline usage only
run bash "$ghs"
expect "gh-search usage: no command" 2
run bash "$ghs" bogus
expect "gh-search usage: unknown command" 2

# fetch.sh, offline usage only
run bash "$fetch"
if [ "$rc" -ne 0 ]; then ok "fetch usage: no URL (rc=$rc)"; else bad "fetch accepted no URL"; fi
case "$out" in *Usage*) ok "fetch usage message printed" ;; *) bad "fetch usage message missing: $out" ;; esac

# session-digest.py
run python3 -I "$digest" "$fx/session.jsonl"
expect "session-digest hit: fixture log" 0
case "$out" in *"Bash: boom"*) ok "session-digest reports the errored result" ;; *) bad "session-digest output: $out" ;; esac
: > "$tmp/empty.jsonl"
run python3 -I "$digest" "$tmp/empty.jsonl"
expect "session-digest miss: empty log" 0
case "$out" in *"tool calls: 0"*) ok "session-digest empty log counts zero" ;; *) bad "session-digest empty output: $out" ;; esac
run python3 -I "$digest" no-such-session-id
expect "session-digest usage: unknown session" 1

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
