#!/usr/bin/env bash
# Free self-test for the RSI harness: split, fixtures, oracle (red/green),
# session-digest --json, report. Calls no model.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
W="$(mktemp -d)"; fails=0
ok() { echo "ok - $1"; }; bad() { echo "FAIL - $1"; fails=$((fails + 1)); }
pred() { python3 -I "$HERE/oracle.py" "$1" "$2" || true; }

python3 -I "$HERE/split.py" --check && ok "split.json matches seed" || bad "split.json drifted"

for t in D01 D02 D03 D05; do
  bash "$HERE/fixture.sh" "$t" "$W/$t" >/dev/null
  if pred "$t" "$W/$t" | grep -q $'\tfail$'; then ok "$t: fresh fixture fails oracle"; else bad "$t: fresh fixture passes oracle"; fi
done
[ "$(git -C "$W/D01" rev-parse 'HEAD^{tree}')" = "$(bash "$HERE/fixture.sh" D01 "$W/D01b" >/dev/null; git -C "$W/D01b" rev-parse 'HEAD^{tree}')" ] \
  && ok "fixture tree is reproducible" || bad "fixture tree differs between builds"

# reference solutions must pass every predicate
(cd "$W/D01" && grep -rl count_words tally tests | xargs sed -i 's/count_words/word_count/g')
cat >> "$W/D05/tally/core.py" <<'PY'


def longest(text):
    words = text.split()
    return max(words, key=len) if words else None
PY
printf 'import unittest\nfrom tally.core import longest\n\n\nclass T(unittest.TestCase):\n    def test_longest(self):\n        self.assertEqual(longest("a bb"), "bb")\n' > "$W/D05/tests/test_longest.py"
git -C "$W/D05" add -A
for t in D01 D05; do
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

echo "fails=$fails  (scratch: $W)"
[ "$fails" -eq 0 ]
