#!/usr/bin/env bash
# Run one RSI trial headless and score it. PAID: calls the model once.
# Usage: bash evals/rsi/run.sh <out-root> <task> <candidate-sha> <trial-n>
# Model, effort, tools, and timeout come from tasks.json "frozen"; nothing overrides them.
# Writes <out-root>/<task>/<trial-n>/: fixture/, request.txt, trace.jsonl,
# predicates.tsv, metrics.json, trial.env (pass=1 only when every predicate passes).
set -euo pipefail
[ $# -eq 4 ] || { echo "usage: run.sh <out-root> <task> <candidate-sha> <trial-n>" >&2; exit 2; }
OUT="$1"; TASK="$2"; SHA="$(git rev-parse --verify "$3^{commit}")"; N="$4"
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
cfg() { python3 -I -c 'import json,sys; c=json.load(open(sys.argv[1])); print(eval(sys.argv[2], {}, {"c": c}))' "$HERE/tasks.json" "$1"; }
REQ="$(cfg "c['tasks']['$TASK']")"
MODEL="$(cfg "c['frozen']['model']")"; EFFORT="$(cfg "c['frozen']['effort']")"
TOOLS="$(cfg "c['frozen']['tools']")"; TIMEOUT="$(cfg "c['frozen']['timeout_s']")"
T="$OUT/$TASK/$N"; FIX="$T/fixture"
[ ! -e "$T" ] || { echo "trial exists: $T" >&2; exit 1; }
mkdir -p "$T"
python3 -I "$HERE/split.py" --check

# fixture, then the candidate overlay pinned to SHA (never a moving ref)
bash "$HERE/fixture.sh" "$TASK" "$FIX"
mkdir -p "$FIX/.claude/skills" "$FIX/.claude/agents"
git -C "$ROOT" show "$SHA:.harness/WORKFLOW.md" > "$FIX/.harness/WORKFLOW.md"
git -C "$ROOT" show "$SHA:setup/agents/worker.md" > "$FIX/.claude/agents/worker.md"
git -C "$ROOT" archive "$SHA" skills/stages | tar -x -C "$FIX/.claude/skills" --strip-components=2
printf 'Read `.harness/WORKFLOW.md` before working.\n' > "$FIX/CLAUDE.md"
git -C "$FIX" -c user.name=fixture -c user.email=fixture@example.invalid add -A
git -C "$FIX" -c user.name=fixture -c user.email=fixture@example.invalid commit -qm "overlay $SHA"
printf '%s\n' "$REQ" > "$T/request.txt"

START=$(date +%s)
(cd "$FIX" && timeout "$TIMEOUT" claude -p "$REQ" --setting-sources project,local --strict-mcp-config \
  --model "$MODEL" --effort "$EFFORT" --allowedTools "$TOOLS" --permission-mode bypassPermissions \
  --output-format stream-json --verbose) > "$T/trace.jsonl" 2> "$T/stderr.txt" || true
END=$(date +%s)

python3 -I "$HERE/oracle.py" "$TASK" "$FIX" > "$T/predicates.tsv" || printf 'oracle_ran\tfail\n' > "$T/predicates.tsv"
python3 -I "$ROOT/skills/stages/retro/scripts/session-digest.py" --json "$T/trace.jsonl" > "$T/metrics.json"
{
  echo "task=$TASK"; echo "trial=$N"; echo "candidate_sha=$SHA"
  echo "model=$MODEL"; echo "effort=$EFFORT"; echo "tools=$TOOLS"
  echo "runtime=claude-code $(claude --version | cut -d' ' -f1)"
  echo "elapsed_s=$((END - START))"
  echo "pass=$(grep -q $'\tfail$' "$T/predicates.tsv" && echo 0 || echo 1)"
} > "$T/trial.env"
echo "trial $T: $(sed -n 's/^pass=//p' "$T/trial.env")"
