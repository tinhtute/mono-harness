#!/usr/bin/env bash
# Free self-test for the RSI harness: split, fixtures, oracle (red/green),
# session-digest --json, report, and run.sh against a stub claude. Calls no model.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
W="$(mktemp -d)"; fails=0
ok() { echo "ok - $1"; }; bad() { echo "FAIL - $1"; fails=$((fails + 1)); }
pred() { python3 -I "$HERE/oracle.py" "$1" "$2" || true; }

python3 -I "$HERE/split.py" --check && ok "split.json matches seed" || bad "split.json drifted"

for t in D01 D02 D03 D05 D06; do
  bash "$HERE/fixture.sh" "$t" "$W/$t" >/dev/null
  if pred "$t" "$W/$t" | grep -q $'\tfail$'; then ok "$t: fresh fixture fails oracle"; else bad "$t: fresh fixture passes oracle"; fi
done
[ "$(git -C "$W/D01" rev-parse 'HEAD^{tree}')" = "$(bash "$HERE/fixture.sh" D01 "$W/D01b" >/dev/null; git -C "$W/D01b" rev-parse 'HEAD^{tree}')" ] \
  && ok "fixture tree is reproducible" || bad "fixture tree differs between builds"

# reference solutions must pass every predicate
(cd "$W/D01" && grep -rl count_words tally tests | xargs perl -pi -e 's/count_words/word_count/g')
cat >> "$W/D05/tally/core.py" <<'PY'


def longest(text):
    words = text.split()
    return max(words, key=len) if words else None
PY
printf 'import unittest\nfrom tally.core import longest\n\n\nclass T(unittest.TestCase):\n    def test_longest(self):\n        self.assertEqual(longest("a bb"), "bb")\n' > "$W/D05/tests/test_longest.py"
git -C "$W/D05" add -A
cat > "$W/D06/tally/fmt.py" <<'PY'
def render(freqs):
    return "\n".join(f"{w} {n}" for w, n in sorted(freqs.items(), key=lambda kv: (-kv[1], kv[0])))
PY
printf 'import unittest\nfrom tally.fmt import render\n\n\nclass T(unittest.TestCase):\n    def test_render(self):\n        self.assertEqual(render({"a": 1, "b": 2}), "b 2\\na 1")\n' > "$W/D06/tests/test_fmt.py"
git -C "$W/D06" add -A
for t in D01 D05 D06; do
  out="$(pred "$t" "$W/$t")"
  if grep -q $'\tfail$' <<<"$out"; then bad "$t: reference fails: $out"; else ok "$t: reference passes oracle"; fi
done

# session-digest --json on a stream-json trace; one message id split over two records
cat > "$W/trace.jsonl" <<'J'
{"type":"system","subtype":"init"}
{"type":"assistant","message":{"id":"m1","usage":{"input_tokens":10,"cache_read_input_tokens":90,"output_tokens":7},"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"ls"}}]}}
{"type":"assistant","message":{"id":"m1","usage":{"input_tokens":10,"cache_read_input_tokens":90,"output_tokens":7},"content":[{"type":"tool_use","id":"t2","name":"Bash","input":{"command":"ls"}}]}}
{"type":"assistant","parent_tool_use_id":"x","message":{"id":"s1","usage":{"output_tokens":999},"content":[]}}
{"type":"system","subtype":"compact_boundary"}
{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1","content":"a"}]}}
{"type":"result","usage":{"output_tokens":42}}
J
m="$(python3 -I "$ROOT/skills/stages/retro/scripts/session-digest.py" --json "$W/trace.jsonl")"
python3 -I -c 'import json,sys; m=json.loads(sys.argv[1]); exp={"output_tokens":42,"peak_context":100,"compactions":1,"tool_use":2,"repeats":1}; bad={k:(m[k],v) for k,v in exp.items() if m[k]!=v}; sys.exit(str(bad) if bad else 0)' "$m" \
  && ok "session-digest --json metrics" || bad "session-digest --json: $m"

# report: synthetic train trials
for t in $(python3 -I -c 'import json,sys; print(" ".join(json.load(open(sys.argv[1]))["train"]))' "$HERE/split.json"); do
  for n in 1 2 3; do
    mkdir -p "$W/out/$t/$n"; printf 'pass=%s\n' "$([ $n = 3 ] && echo 0 || echo 1)" > "$W/out/$t/$n/trial.env"; printf '%s\n' "$m" > "$W/out/$t/$n/metrics.json"
  done
done
r="$(python3 -I "$HERE/report.py" "$W/out" train)"
python3 -I -c 'import json,sys; r=json.loads(sys.argv[1]); t=r["tasks"]; sys.exit(0 if r["split"]=="train" and all(v["pass"] and v["passes"]==2 and v["output_tokens"]=={"median":42,"iqr":0} for v in t.values()) and t else r)' "$r" \
  && ok "report aggregates train trials" || bad "report: $r"

# rate-limit guard: only a terminal limit counts; numbers containing 429 and a retried 429 do not
printf '{"usage":{"totalTokens":20429},"cost":0.01429725,"id":"call_279429"}\n' > "$W/t_num.jsonl"
printf '{"error":{"code": 429,"status":"RESOURCE_EXHAUSTED"}}\n{"stopReason":"stop","isTerminal":true}\n' > "$W/t_retry.jsonl"
printf '{"type":"result","result":"You have hit your 5-hour limit"}\n' | sed 's/You have/You'"'"'ve/' > "$W/t_claude.jsonl"
printf '{"error":{"code": 429,"status":"RESOURCE_EXHAUSTED"}}\n' > "$W/t_omp.jsonl"
: > "$W/t_err.txt"
g="$(for f in num retry claude omp; do bash "$HERE/limited.sh" "$W/t_$f.jsonl" "$W/t_err.txt"; done | tr -d '\n')"
[ "$g" = 0011 ] && ok "rate-limit guard: terminal only, no bare 429" || bad "rate-limit guard: got $g, want 0011"

# finalization (#196): proof turns from the trace, R2 re-exec of entries added after the overlay
F="$W/fin"; bash "$HERE/fixture.sh" D02 "$F" >/dev/null
git -C "$F" -c user.name=t -c user.email=t@t commit -q --allow-empty -m "overlay test"
P="$F/.harness/plans/active/tally-filters.md"
python3 -I - "$P" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
add = ("- 2026-01-01 `main` verdict: APPROVED\n  - `python3 -m unittest -q`\n"
       "- 2026-01-02 `main` verdict: APPROVED\n  - `false`\n"
       "- 2026-01-03 `main` verdict: REQUEST_CHANGES\n  - `false`\n\n")
open(p, "w").write(s.replace("## Validation\n\n", "## Validation\n\n" + add, 1))
PY
cat > "$W/fin.jsonl" <<'J'
{"type":"assistant","message":{"id":"a1","content":[{"type":"tool_use","id":"u1","name":"Bash","input":{"command":"bash scripts/workflow/record-check.sh -- 'python3 -m unittest -q'"}},{"type":"tool_use","id":"u2","name":"Bash","input":{"command":"python3 -m unittest -q"}}]}}
{"type":"assistant","message":{"id":"a1","content":[{"type":"tool_use","id":"u2","name":"Bash","input":{"command":"python3 -m unittest -q"}}]}}
{"type":"assistant","message":{"id":"a2","content":[{"type":"tool_use","id":"u3","name":"Bash","input":{"command":"pytest -q"}},{"type":"tool_use","id":"u4","name":"Bash","input":{"command":"ls"}}]}}
{"type":"assistant","parent_tool_use_id":"x","message":{"id":"s1","content":[{"type":"tool_use","id":"u5","name":"Bash","input":{"command":"pytest"}}]}}
J
f="$(bash "$HERE/finalization.sh" "$W/fin.jsonl" "$F" "$ROOT/setup/install-git-hooks.sh")"
python3 -I -c 'import json,sys; m=json.loads(sys.argv[1]); exp={"proof_calls":3,"proof_turns":2,"approved_entries":2,"approved_rejected":1}; sys.exit(0 if m==exp else f"{m} != {exp}")' "$f" \
  && ok "finalization metrics" || bad "finalization: $f"

# cost (HarnessMM): all tokens, subagents included; result modelUsage wins, else per-message; omp turn_end
c1="$(python3 -I "$HERE/cost.py" "$W/trace.jsonl")"
printf '{"type":"result","total_cost_usd":0.5,"modelUsage":{"a":{"inputTokens":1,"outputTokens":2,"cacheReadInputTokens":3,"cacheCreationInputTokens":4},"b":{"inputTokens":10}}}\n' > "$W/c_res.jsonl"
c2="$(python3 -I "$HERE/cost.py" "$W/c_res.jsonl")"
printf '{"type":"turn_end","message":{"usage":{"totalTokens":100,"cost":{"total":0.25}}}}\n%.0s' 1 2 > "$W/c_omp.jsonl"
c3="$(python3 -I "$HERE/cost.py" "$W/c_omp.jsonl")"
[ "$c1|$c2|$c3" = '{"cost_usd": 0.0, "total_tokens": 1106}|{"cost_usd": 0.5, "total_tokens": 20}|{"cost_usd": 0.5, "total_tokens": 200}' ] \
  && ok "cost: complete-trial tokens" || bad "cost: $c1|$c2|$c3"

# accept: keep pass rate AND tokens <= 0.9 x parent
rep() { printf '{"tasks":{"D05":{"trials":5,"passes":%s,"total_tokens":{"median":%s,"iqr":0}}}}' "$1" "$2" > "$W/$3.json"; }
rep 4 1000 par; rep 4 900 ok1; rep 4 901 hi; rep 3 500 drop
v=""; for c in ok1 hi drop; do python3 -I "$HERE/accept.py" "$W/par.json" "$W/$c.json" >/dev/null && v="${v}1" || v="${v}0"; done
[ "$v" = 100 ] && ok "accept: quality kept and <=0.9x tokens" || bad "accept: got $v, want 100"

# mod overlay + forced-compact probe (#203): run.sh end to end against a stub claude, no model call
SB="$W/stubbin"; SC="$W/stubcfg"; mkdir -p "$SB" "$SC"; echo '{}' > "$SC/.credentials.json"
printf '#!/bin/sh\necho "omp stub"\n' > "$SB/omp"
cat > "$SB/claude" <<'SH'
#!/usr/bin/env bash
# Stub: logs each phase and the plugin dir it was handed, answers with canned stream-json.
[ "${1:-}" = --version ] && { echo "0.0.0 (stub)"; exit 0; }
prompt="$2"; pd=""; sid=""; res=""
while [ $# -gt 0 ]; do case "$1" in --plugin-dir) pd="$2" ;; --session-id) sid="$2" ;; --resume) res="$2" ;; esac; shift; done
printf 'phase sid=%s resume=%s prompt=%s\n' "$sid" "$res" "${prompt%% *}" >> "$STUB_LOG"
if [ -n "$pd" ]; then (cd "$pd" && find . -type f | sort | sed 's/^/mod /') >> "$STUB_LOG"; cp "$pd/ninja-kit/hooks/register.ts" "$STUB_LOG.ts"; fi
case "$prompt" in
  /compact)
    printf '{"type":"system","subtype":"compact_boundary","compact_metadata":{"trigger":"manual","pre_tokens":9}}\n'
    mkdir -p "$CLAUDE_CONFIG_DIR/projects/stub"
    printf '{"type":"user","isCompactSummary":true,"message":{"role":"user","content":"Summary. %s"}}\n' "$STUB_SUMMARY" \
      >> "$CLAUDE_CONFIG_DIR/projects/stub/$res.jsonl" ;;
  Delete*)
    printf '{"type":"assistant","message":{"id":"p1","content":[{"type":"tool_use","id":"b1","name":"Bash","input":{"command":"%s probe.tmp"}}]}}\n' "$STUB_DEL" ;;
esac
printf '{"type":"result","subtype":"success","modelUsage":{"m":{"inputTokens":1}}}\n'
SH
chmod +x "$SB/claude" "$SB/omp"
SHA="$(git -C "$ROOT" rev-parse HEAD)"
stub() { # stub <trial> <summary> <delete-cmd> [VAR=value ...]
  local n="$1" sum="$2" del="$3"; shift 3
  env PATH="$SB:$PATH" CLAUDE_CONFIG_DIR="$SC" STUB_LOG="$W/stub$n.log" STUB_SUMMARY="$sum" STUB_DEL="$del" "$@" \
    bash "$HERE/run.sh" "$W/stubout" D05 "$SHA" "$n" >/dev/null 2>"$W/stub$n.err"
}
mk() { python3 -I -c 'import json,sys; m=json.load(open(sys.argv[1])); print(" ".join(str(m.get(k)) for k in sys.argv[2:]))' "$W/stubout/D05/$1/metrics.json" "${@:2}"; }
PK="compacted summary_keeps_trash trash_survives_compact compact_total_tokens"
stub 1 "Keep verbatim: trash not rm." trash RSI_MODS=1 RSI_COMPACT=1 || true
stub 2 "Nothing kept." rm RSI_MODS=1 RSI_COMPACT=1 || true
stub 3 "" "" || true
L1="$W/stub1.log"; sid="$(sed -n '1s/^phase sid=\([^ ]*\) .*/\1/p' "$L1" 2>/dev/null)"
[ -n "$sid" ] && [ "$(grep -c "^phase sid= resume=$sid " "$L1")" = 2 ] && grep -q "resume=$sid prompt=/compact" "$L1" \
  && ok "compact: task phase sets the session id, /compact and probe resume it" || bad "compact phases: $(cat "$L1" "$W/stub1.err" 2>&1 | head -5)"
grep -q '^mod ./ninja-kit/hooks/register.ts$' "$L1" && grep -q '^mod ./cache-guard/hooks/register.tsx$' "$L1" \
  && cmp -s "$L1.ts" <(git -C "$ROOT" show "$SHA:setup/mods/ninja-kit/hooks/register.ts") \
  && ok "mods: candidate setup/mods handed to --plugin-dir, bytes pinned to SHA" || bad "mods overlay: $(grep '^mod' "$L1" | head -3)"
[ "$(mk 1 $PK)|$(mk 2 $PK)" = "1 1 1 2|1 0 0 2" ] && grep -q '^mods=1$' "$W/stubout/D05/1/trial.env" \
  && ok "compact probe: trash after compact scores 1, rm and a lost rule score 0" || bad "compact probe: $(mk 1 $PK)|$(mk 2 $PK)"
[ "$(grep -c '^phase' "$W/stub3.log")" = 1 ] && grep -q '^phase sid= resume= ' "$W/stub3.log" && ! grep -q '^mod ' "$W/stub3.log" \
  && [ "$(mk 3 compacted)" = None ] && grep -q '^compact=0$' "$W/stubout/D05/3/trial.env" \
  && ok "default trial: one phase, no mods, no probe keys" || bad "default trial: $(cat "$W/stub3.log" "$W/stub3.err" 2>&1 | head -5)"
rc=0; env PATH="$SB:$PATH" RSI_RUNTIME=omp RSI_MODS=1 bash "$HERE/run.sh" "$W/stubout" D05 "$SHA" 9 >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] && [ ! -e "$W/stubout/D05/9" ] && ok "omp: RSI_MODS refused before any trial dir" || bad "omp guard: rc=$rc"

echo "fails=$fails  (scratch: $W)"
[ "$fails" -eq 0 ]
