#!/usr/bin/env bash
# lint-prompt.sh - check a rewritten prompt carries every ambition slot.
#
# Usage: lint-prompt.sh [--lens depth|altitude|range] [FILE]   (stdin if no FILE)
#
# A slot is a line starting with its label, e.g. "Judge: cargo test --test x".
# Exit 0 when every slot for the lens is present and concrete; exit 1 and list
# each missing or vague slot otherwise; exit 2 on bad usage.

set -euo pipefail

lens=depth
if [ "${1:-}" = "--lens" ]; then lens="${2:-}"; shift 2; fi
case "$lens" in depth|altitude|range) ;; *) echo "usage: lint-prompt.sh [--lens depth|altitude|range] [FILE]" >&2; exit 2 ;; esac

text=$(cat "${1:-/dev/stdin}")
fails=()

slot() {                                    # <label> -> slot text, empty if absent
	printf '%s\n' "$text" | sed -n "s/^[[:space:]]*[-*]*[[:space:]]*\*\{0,2\}$1\*\{0,2\}:[[:space:]]*//Ip" | head -1
}
need() {                                    # <label> <why>
	[ -n "$(slot "$1")" ] || fails+=("$1: missing ($2)")
}

need Field "name the discipline, e.g. SRE incident response"
need Raw "the primary material: a path, URL, table or command"
need Instruments "named tools or methods, not 'best practices'"
need Assumption "the belief the raw material could refute"
need Judge "what outside the user and the model shows it is right"
need Pass "the judge result that counts as success"
need Fail "the judge result that counts as failure"

raw=$(slot Raw)
[ -z "$raw" ] || printf '%s' "$raw" | grep -Eq '[/.`]|https?:|SELECT|select ' ||
	fails+=("Raw: vague (name a path, URL, table or command)")
pass=$(slot Pass)
[ -z "$pass" ] || printf '%s' "$pass" | grep -Eq '[0-9]|exit|green|reproduc|match' ||
	fails+=("Pass: vague (state a number, exit code or reproduction)")

case "$lens" in
altitude) need Outcome "the goal beyond the goal, stated as a lasting state" ;;
range)
	need Verbs "the task as verbs, not a noun"
	crew=$(slot Crew)
	if [ -z "$crew" ]; then fails+=("Crew: missing (two or more fields and what each does)")
	elif [ "$(printf '%s' "$crew" | tr ';,' '\n\n' | grep -c .)" -lt 2 ]; then fails+=("Crew: needs two or more fields"); fi
	;;
esac

if printf '%s' "$text" | grep -Eiq '\b(act|write|pretend) (like|as) (a|an)\b'; then
	fails+=("Role-play: ask what the field does, not to write like it")
fi

if [ "${#fails[@]}" -eq 0 ]; then echo "ok: $lens slots complete"; exit 0; fi
printf 'fail: %s\n' "${fails[@]}"
exit 1
