#!/bin/bash
# record-check.sh — convenience proof runner for ## Validation entries (R2 companion)
#
# NOT the guarantee. The pre-commit hook re-executes every proof command of a
# newly added APPROVED/APPROVE_WITH_REQUESTS entry from staged bytes itself and
# reads no marker. This script only lets an agent sanity-run the exact commands
# it is about to cite, under identical semantics: `sh -c`, 5-minute timeout per
# command (timeout → gtimeout → unbounded, same resolver as the pre-commit hook),
# exit 0 required.
#
# Usage:
#   scripts/workflow/record-check.sh [-t SECONDS] -- "cmd1" "cmd2" ...
#   echo '"cmd1\ncmd2"' | jq -r .[] | ...   # not supported; pass commands as args
#
# Exit codes: 0 all proofs pass; 1 at least one failed; 2 usage error.

set -u

TIMEOUT=300
while getopts ":t:h" opt; do
  case "$opt" in
    t) TIMEOUT="$OPTARG" ;;
    h) grep '^#' "$0" | sed 's/^# \{1,\}\?//'; exit 0 ;;
    *) echo "usage: $0 [-t seconds] -- cmd..." >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))
[ $# -gt 0 ] || { echo "usage: $0 [-t seconds] -- cmd..." >&2; exit 2; }

failed=0
rc=0
out=""
# Same resolver as zharness_run_proof in scripts/install-git-hooks.sh
# (ZGUARD-CORE): GNU timeout, else coreutils gtimeout, else unbounded.
zharness_run_proof() {
	if command -v timeout >/dev/null 2>&1; then
		timeout "$TIMEOUT" sh -c "$1" 2>&1
	elif command -v gtimeout >/dev/null 2>&1; then
		gtimeout "$TIMEOUT" sh -c "$1" 2>&1
	else
		echo "⚠️  no timeout/gtimeout on PATH — running proof unbounded (interrupt with Ctrl+C if it hangs)" >&2
		sh -c "$1" 2>&1
	fi
}
for cmd in "$@"; do
	printf '🧪 proof: %s\n' "$cmd"
	out=$(zharness_run_proof "$cmd") && rc=0 || rc=$?
	if [ "${rc:-0}" -ne 0 ]; then
		failed=$((failed + 1))
		printf '❌ FAIL (exit %s)\n' "$rc"
		printf '%s\n' "$out" | tail -10 | sed 's/^/    /'
	else
		printf '✅ PASS\n'
		[ -n "$out" ] && printf '%s\n' "$out" | tail -3 | sed 's/^/    /'
	fi
done

if [ "$failed" -ne 0 ]; then
  printf '\n❌ %s of %s proof command(s) failed — do not write an APPROVED entry citing these.\n' "$failed" "$#"
  exit 1
fi
printf '\n✅ %s proof command(s) passed — safe to cite in a Validation entry.\n' "$#"
