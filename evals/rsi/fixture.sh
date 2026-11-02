#!/usr/bin/env bash
# RSI fixture generator — builds the task-code snapshot for one task of
# evals/rsi/tasks.json. Restored from lean-fixture-generator-v1
# (git show d8ed43e^:docs/evals/evidence/lean-fixture-generator-v1.txt);
# plans moved to .harness/plans/, D04 dropped (no oracle), D05 added.
# Usage: bash fixture.sh <D01|D02|D03|D05> <out-dir>
# The candidate overlay is applied afterwards by run.sh; this writes task code only.
set -euo pipefail
CASE="$1"; OUT="$2"
[ ! -e "$OUT" ] || { echo "out-dir exists: $OUT" >&2; exit 1; }
mkdir -p "$OUT/tally" "$OUT/tests" "$OUT/.harness/plans/active" "$OUT/.harness/plans/completed"
cd "$OUT"

cat > tally/__init__.py <<'EOF'
EOF
cat > tally/core.py <<'EOF'
def count_words(text):
    return len(text.split())


def frequencies(text):
    out = {}
    for word in text.split():
        out[word] = out.get(word, 0) + 1
    return out
EOF
for m in report summary stats export cli_text cli_json; do
  cat > "tally/$m.py" <<EOF
from tally.core import count_words


def $m(text):
    return {"name": "$m", "words": count_words(text)}
EOF
done
cat > tally/parse.py <<'EOF'
def tokens(text):
    return text.split()
EOF
cat > tally/fmt.py <<'EOF'
def render(freqs):
    return "\n".join(f"{w} {n}" for w, n in sorted(freqs.items()))
EOF
cat > tally/cli.py <<'EOF'
import sys

from tally.core import frequencies
from tally.fmt import render


def main(argv=None):
    text = sys.stdin.read()
    print(render(frequencies(text)))
    return 0
EOF
: > tests/__init__.py
cat > tests/test_core.py <<'EOF'
import unittest

from tally.core import count_words, frequencies
from tally.report import report


class CoreTest(unittest.TestCase):
    def test_count(self):
        self.assertEqual(count_words("a b a"), 3)

    def test_frequencies(self):
        self.assertEqual(frequencies("a b a"), {"a": 2, "b": 1})

    def test_report(self):
        self.assertEqual(report("a b")["words"], 2)


if __name__ == "__main__":
    unittest.main()
EOF
cat > README.md <<'EOF'
# tally

Word statistics. Test: `python3 -m unittest -q`.
EOF

case "$CASE" in
D01) : ;;
D02)
  cat > .harness/plans/active/tally-filters.md <<'EOF'
---
status: active
lane: normal
---
# tally filters

## Goal

- outcome: `tally.cli` can fold case and drop rare words.
- requirements:
  - R1: `--ignore-case` counts words case-insensitively. | acceptance: `python3 -m unittest -q tests.test_filters.IgnoreCaseTest` | source: owner
  - R2: `--min N` omits words seen fewer than N times. | acceptance: `python3 -m unittest -q tests.test_filters.MinCountTest` | source: owner
- non-goals: no other flags.

## Phases and Verification

- phase_slug: `main`
  status: planned
  - goal: R1, R2 | depends_on: none
  - phase check: `python3 -m unittest -q`

## Log

## Validation

## Current State and Next Action

- active_phase: none
- lifecycle_status: planned
- blockers: none
- exact_next_action: work full
EOF
  ;;
D03)
  cat > .harness/plans/active/tally-unicode.md <<'EOF'
---
status: active
lane: high-risk
---
# tally unicode

## Goal

- outcome: tokenization and rendering are Unicode-correct; CLI output stays stable for ASCII input.
- requirements:
  - R1: `tally.parse.tokens` splits on Unicode whitespace and strips Unicode punctuation. | acceptance: `python3 -m unittest -q tests.test_parse` | source: owner
  - R2: `tally.fmt.render` sorts by NFC-normalized word. | acceptance: `python3 -m unittest -q tests.test_fmt` | source: owner
  - R3: `tally.cli` uses `tokens` and `render` together. | acceptance: `python3 -m unittest -q tests.test_cli` | source: owner
- non-goals: no locale-specific collation.

## Phases and Verification

- phase_slug: `p1`
  status: planned
  - goal: R1, R2, R3 | depends_on: none
  - surfaces: tally/parse.py, tally/fmt.py, tally/cli.py, tests/
  - escalate_when: an acceptance check must change
  - wave 1:
    - T1 parse slice (owner: worker-a, writes tally/parse.py and tests/test_parse.py only) — output: Unicode tokens — check: `python3 -m unittest -q tests.test_parse`
    - T2 fmt slice (owner: worker-b, writes tally/fmt.py and tests/test_fmt.py only) — output: NFC sort — check: `python3 -m unittest -q tests.test_fmt`
  - wave 2:
    - T3 integrate cli on the combined tree — output: cli uses both — check: `python3 -m unittest -q`
  - phase check: `python3 -m unittest -q` and independent review

## Log

- 2026-10-01T00:00:00Z — p1/T1 — done — `python3 -m unittest -q tests.test_parse` exit 0 at commit 0000000 (pre-fixture tree; this tree has no tests/test_parse.py).

## Validation

## Current State and Next Action

- active_phase: p1
- lifecycle_status: in-progress
- blockers: none
- exact_next_action: work full phase p1
EOF
  ;;
D05) : ;;
*) echo "unknown case $CASE" >&2; exit 1 ;;
esac

git init -q
git -c user.name=fixture -c user.email=fixture@example.invalid add -A
git -c user.name=fixture -c user.email=fixture@example.invalid commit -qm "fixture $CASE v1"
