#!/usr/bin/env bash
# Finalization metrics for #196, scored after a trial. Frozen, evaluator-side.
# Usage: finalization.sh <trace.jsonl> <fixture> <guard-src>
# Prints one JSON object:
#   proof_calls       Bash calls that run a proof (record-check.sh, unittest, pytest)
#   proof_turns       distinct main-chain model turns that issued at least one proof call;
#                     batching proofs into one record-check.sh call lowers it
#   approved_entries  APPROVED/APPROVE_WITH_REQUESTS Validation entries added during the trial
#   approved_rejected those of them the pre-commit R2 guard would reject: a proof exits
#                     non-zero on the final tree, or the entry cites no proof
# <guard-src> is the installer whose ZGUARD-CORE block the evaluator trusts (the
# evaluator's own checkout, never the candidate), so the scorer stays frozen.
set -euo pipefail
[ $# -eq 3 ] || { echo "usage: finalization.sh <trace.jsonl> <fixture> <guard-src>" >&2; exit 2; }
TRACE="$1"; FIX="$(cd "$2" && pwd)"; GSRC="$3"

read -r CALLS TURNS < <(python3 -I - "$TRACE" <<'PY'
import json, re, sys
PROOF = re.compile(r"record-check\.sh|\bunittest\b|\bpytest\b")
calls, turns, seen = 0, set(), set()
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    try:
        rec = json.loads(line)
    except ValueError:
        continue
    if rec.get("isSidechain") or rec.get("parent_tool_use_id"):
        continue
    if rec.get("type") == "assistant":        # Claude Code stream-json
        msg = rec.get("message") or {}
        blocks = [(b.get("id"), b.get("name"), (b.get("input") or {}).get("command", ""))
                  for b in msg.get("content") or [] if b.get("type") == "tool_use"]
        turn = msg.get("id")
    elif rec.get("type") == "turn_end":       # omp json
        msg = rec.get("message") or {}
        blocks = [(b.get("id"), b.get("name"), (b.get("arguments") or {}).get("command", ""))
                  for b in msg.get("content") or [] if b.get("type") == "toolCall"]
        turn = id(rec)
    else:
        continue
    for bid, name, cmd in blocks:
        if bid in seen or (name or "").lower() != "bash" or not PROOF.search(str(cmd)):
            continue
        seen.add(bid)
        calls += 1
        turns.add(turn)
print(calls, len(turns))
PY
)

W="$(mktemp -d)"; trap 'trash "$W" >/dev/null 2>&1 || true' EXIT
awk '$0=="# ZGUARD-CORE-BEGIN"{on=1;next} $0=="# ZGUARD-CORE-END"{on=0} on' "$GSRC" > "$W/guard.sh"
# shellcheck disable=SC1091
source "$W/guard.sh"
BASE="$(git -C "$FIX" log --format=%H -1 --grep='^overlay ')"
approved=0; rejected=0
for plan in "$FIX"/.harness/plans/active/*.md "$FIX"/.harness/plans/completed/*.md; do
  [ -f "$plan" ] || continue
  rel="${plan#"$FIX"/}"; name="$(basename "$plan")"
  mkdir -p "$W/old" "$W/new/$name"
  # The plan may have moved active/ -> completed/; the baseline is either path at the overlay commit.
  { git -C "$FIX" show "$BASE:$rel" 2>/dev/null || git -C "$FIX" show "$BASE:.harness/plans/active/$name" 2>/dev/null || true; } > "$W/old/$name"
  mkdir -p "$W/old/$name.d"; zharness_dump_entries "$W/old/$name" "$W/old/$name.d"
  zharness_dump_entries "$plan" "$W/new/$name"
  for e in "$W/new/$name"/e*.txt; do
    [ -f "$e" ] || continue
    body="$(cat "$e")"
    case "$(zharness_anchored_verdict "$body")" in APPROVED|APPROVE_WITH_REQUESTS) ;; *) continue ;; esac
    if cat "$W/old/$name.d"/e*.txt 2>/dev/null | grep -qxF -- "$(head -1 "$e")"; then continue; fi
    approved=$((approved + 1))
    proofs="$(zharness_entry_proofs "$body")"
    if [ -z "$proofs" ]; then rejected=$((rejected + 1)); continue; fi
    while IFS= read -r p; do
      (cd "$FIX" && zharness_run_proof "$p" >/dev/null 2>&1) || { rejected=$((rejected + 1)); break; }
    done <<< "$proofs"
  done
done
printf '{"approved_entries": %s, "approved_rejected": %s, "proof_calls": %s, "proof_turns": %s}\n' \
  "$approved" "$rejected" "$CALLS" "$TURNS"
