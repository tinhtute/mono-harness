#!/usr/bin/env bash
# Run one RSI trial headless and score it. PAID: calls the model once.
# Usage: [RSI_CANDIDATE_ENV=<file>] bash evals/rsi/run.sh <out-root> <task> <candidate-sha> <trial-n>
# RSI_CANDIDATE_ENV: optional KEY=VALUE lines for the companion-config knobs under tuning (#194);
# only MAX_THINKING_TOKENS and MAX_MCP_OUTPUT_TOKENS are accepted.
# Model, effort, tools, and timeout come from tasks.json "frozen"; nothing overrides them.
# RSI_RUNTIME selects the runner: claude (default) or omp. The runtime's own model id is
# <runtime_model> in tasks.json "frozen"; model/effort/tools stay frozen either way.
# Writes <out-root>/<task>/<trial-n>/: fixture/, request.txt, trace.jsonl,
# predicates.tsv, metrics.json (incl. total_tokens, cost_usd), trial.env.
# trial.env pass=1 only when every predicate passes AND the runtime was not rate-limited.
# A rate-limited trial is scored pass=0 with `limited=1`, so report.py shows it as a failure
# rather than hiding it; re-run it before trusting the split.
set -euo pipefail
[ $# -eq 4 ] || { echo "usage: run.sh <out-root> <task> <candidate-sha> <trial-n>" >&2; exit 2; }
OUT="$1"; TASK="$2"; SHA="$(git rev-parse --verify "$3^{commit}")"; N="$4"
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
cfg() { python3 -I -c 'import json,sys; c=json.load(open(sys.argv[1])); print(eval(sys.argv[2], {}, {"c": c}))' "$HERE/tasks.json" "$1"; }
REQ="$(cfg "c['tasks']['$TASK']")"
MODEL="$(cfg "c['frozen']['model']")"; EFFORT="$(cfg "c['frozen']['effort']")"
TOOLS="$(cfg "c['frozen']['tools']")"; TIMEOUT="$(cfg "c['frozen']['timeout_s']")"
RUNTIME="${RSI_RUNTIME:-claude}"
case "$RUNTIME" in
  claude) RT_MODEL="$MODEL"; RT_VERSION="$(claude --version 2>/dev/null | cut -d' ' -f1)" ;;
  omp) RT_MODEL="$(cfg "c['frozen'].get('omp_model') or '$MODEL'")"
       RT_VERSION="$(omp --version 2>/dev/null | head -1)" ;;
  *) echo "RSI_RUNTIME must be claude or omp, got: $RUNTIME" >&2; exit 2 ;;
esac
T="$OUT/$TASK/$N"; FIX="$T/fixture"
[ ! -e "$T" ] || { echo "trial exists: $T" >&2; exit 1; }
# Claude Code loads CLAUDE.md, .claude/CLAUDE.md and .claude/rules/ from every ancestor of the cwd,
# so an out-root under $HOME pulls the caller's ~/.claude instructions into the trial.
d="$(cd "$OUT" 2>/dev/null && pwd || dirname "$(realpath -m "$OUT")")"
while [ "$d" != / ]; do
  for f in "$d/CLAUDE.md" "$d/CLAUDE.local.md" "$d/.claude/CLAUDE.md" "$d/.claude/rules"; do
    [ ! -e "$f" ] || { echo "out-root inherits $f; use an out-root outside it (e.g. under /var/tmp)" >&2; exit 2; }
  done
  d="$(dirname "$d")"
done
mkdir -p "$T"
python3 -I "$HERE/split.py" --check

# fixture, then the candidate overlay pinned to SHA (never a moving ref)
bash "$HERE/fixture.sh" "$TASK" "$FIX"
mkdir -p "$FIX/.claude/skills"
git -C "$ROOT" show "$SHA:.harness/WORKFLOW.md" > "$FIX/.harness/WORKFLOW.md"
# omp discovers project subagents under .omp/agents/; Claude Code under .claude/agents/.
# Same worker bytes either way, so the candidate surface stays the single source.
if [ "$RUNTIME" = omp ]; then
  mkdir -p "$FIX/.omp/agents"
  git -C "$ROOT" show "$SHA:setup/agents/worker.md" > "$FIX/.omp/agents/worker.md"
else
  mkdir -p "$FIX/.claude/agents"
  git -C "$ROOT" show "$SHA:setup/agents/worker.md" > "$FIX/.claude/agents/worker.md"
fi
git -C "$ROOT" archive "$SHA" skills/stages | tar -x -C "$FIX/.claude/skills" --strip-components=2
# check.md runs proofs through record-check.sh when it exists; ship the candidate's copy (#196).
mkdir -p "$FIX/scripts/workflow"
git -C "$ROOT" show "$SHA:scripts/workflow/record-check.sh" > "$FIX/scripts/workflow/record-check.sh"
printf 'Read `.harness/WORKFLOW.md` before working.\n' > "$FIX/CLAUDE.md"
git -C "$FIX" -c user.name=fixture -c user.email=fixture@example.invalid add -A
git -C "$FIX" -c user.name=fixture -c user.email=fixture@example.invalid commit -qm "overlay $SHA"
printf '%s\n' "$REQ" > "$T/request.txt"

# Drop only the caller's knobs that would change a frozen trial. Stripping every CLAUDE* var made the
# nested `claude -p` start as a top-level session and froze the desktop between trials (#192).
UNSET=(); for v in CLAUDE_CODE_PLUGIN_DIRS CLAUDE_EFFORT CLAUDE_CODE_DISABLE_1M_CONTEXT \
  MAX_THINKING_TOKENS MAX_MCP_OUTPUT_TOKENS ANTHROPIC_MODEL ANTHROPIC_SMALL_FAST_MODEL; do
  UNSET+=(-u "$v")
done
KNOBS=()
if [ -n "${RSI_CANDIDATE_ENV:-}" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    [[ "$line" =~ ^(MAX_THINKING_TOKENS|MAX_MCP_OUTPUT_TOKENS)=[0-9]+$ ]] || { echo "bad candidate knob: $line" >&2; exit 2; }
    KNOBS+=("$line")
  done < "$RSI_CANDIDATE_ENV"
fi
# Isolated config dir holding only the login: keeps the caller's ~/.claude CLAUDE.md, rules, skills and agents out.
CFG=$(mktemp -d); [ "$RUNTIME" = omp ] || cp "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json" "$CFG/"
# GNU timeout; macOS has none unless coreutils is installed.
if command -v timeout >/dev/null; then TO=(timeout); elif command -v gtimeout >/dev/null; then TO=(gtimeout)
else TO=(perl -e 'alarm shift; exec @ARGV or die "exec: $!"'); fi
START=$(date +%s)
if [ "$RUNTIME" = omp ]; then
  # The frozen tool list is Claude Code's vocabulary. omp names the same capabilities
  # differently (Skill -> manage_skill, Task -> task) and rejects unknown names outright,
  # so map them rather than passing the frozen string through.
  OMP_TOOLS="$(printf '%s' "$TOOLS" | tr ',' '\n' | tr '[:upper:]' '[:lower:]' | sed -e 's/^skill$/manage_skill/' -e 's/^task$/task/' | paste -sd, -)"
  (cd "$FIX" && env "${UNSET[@]}" ${KNOBS[@]+"${KNOBS[@]}"} "${TO[@]}" "$TIMEOUT" omp -p "$REQ" \
    --model "$RT_MODEL" --thinking "$EFFORT" --tools "$OMP_TOOLS" --mode=json \
    --no-context-files --no-extensions --no-rules) > "$T/trace.jsonl" 2> "$T/stderr.txt" || true
else
  (cd "$FIX" && env "${UNSET[@]}" CLAUDE_CONFIG_DIR="$CFG" ${KNOBS[@]+"${KNOBS[@]}"} "${TO[@]}" "$TIMEOUT" claude -p "$REQ" --setting-sources project,local --strict-mcp-config \
    --model "$RT_MODEL" --effort "$EFFORT" --allowedTools "$TOOLS" --permission-mode bypassPermissions \
    --output-format stream-json --verbose) > "$T/trace.jsonl" 2> "$T/stderr.txt" || true
fi
END=$(date +%s)
trash "$CFG"

# A rate-limited run still exits 0 and looks like a terse failed attempt: Claude Code reports
# `You've hit your 5-hour limit`, a provider 429 arrives as a quota message. Score it as a
# failure but tag it, so a poisoned grid is visible in trial.env instead of silent (#193 round 1).
LIMITED="$(bash "$HERE/limited.sh" "$T/trace.jsonl" "$T/stderr.txt")"

python3 -I "$HERE/oracle.py" "$TASK" "$FIX" > "$T/predicates.tsv" || printf 'oracle_ran\tfail\n' > "$T/predicates.tsv"
# session-digest reads Claude Code stream-json; an omp trace carries no such records, so its
# metrics come from the json trace directly. Same keys, so report.py needs no branch.
python3 -I "$HERE/oracle.py" "$TASK" "$FIX" >/dev/null 2>&1 || true
if [ "$RUNTIME" = omp ]; then
  python3 -I - "$T/trace.jsonl" "$T/metrics.json" <<'PY'
import json, sys
out = {"compactions": 0, "errors": 0, "output_tokens": 0, "peak_context": 0,
       "repeats": 0, "session": sys.argv[1], "tool_use": 0, "tool_use_by_name": {},
       "top_repeats": [], "user_prompts": 0}
seen = set()
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    try:
        rec = json.loads(line)
    except ValueError:
        continue
    if rec.get("type") != "turn_end":
        continue
    msg = rec.get("message") or {}
    usage = msg.get("usage") or {}
    out["output_tokens"] += int(usage.get("output") or 0)
    out["peak_context"] = max(out["peak_context"], int(usage.get("input") or 0) + int(usage.get("cacheRead") or 0))
    for block in msg.get("content") or []:
        if block.get("type") == "toolCall":
            name = block.get("name") or "?"
            key = block.get("id") or id(block)
            if key in seen:
                continue
            seen.add(key)
            out["tool_use"] += 1
            out["tool_use_by_name"][name] = out["tool_use_by_name"].get(name, 0) + 1
json.dump(out, open(sys.argv[2], "w"), sort_keys=True)
PY
else
  python3 -I "$ROOT/skills/stages/retro/scripts/session-digest.py" --json "$T/trace.jsonl" > "$T/metrics.json"
fi
# Finalization metrics (#196), scored with the evaluator's own guard core, never the candidate's.
FIN="$(bash "$HERE/finalization.sh" "$T/trace.jsonl" "$FIX" "$ROOT/setup/install-git-hooks.sh")"
# Complete-trial cost: every input/cache/output token, subagents included (cost.py).
COST="$(python3 -I "$HERE/cost.py" "$T/trace.jsonl")"
python3 -I -c 'import json,sys; m=json.load(open(sys.argv[1])); [m.update(json.loads(a)) for a in sys.argv[2:]]; json.dump(m, open(sys.argv[1], "w"), sort_keys=True)' "$T/metrics.json" "$FIN" "$COST"
{
  echo "task=$TASK"; echo "trial=$N"; echo "candidate_sha=$SHA"
  echo "model=$RT_MODEL"; echo "effort=$EFFORT"; echo "tools=$TOOLS"
  echo "knobs=${KNOBS[*]+${KNOBS[*]}}"
  echo "runtime=$RUNTIME $RT_VERSION"
  echo "limited=$LIMITED"
  echo "elapsed_s=$((END - START))"
  echo "pass=$([ "$LIMITED" = 0 ] && { grep -q $'\tfail$' "$T/predicates.tsv" && echo 0 || echo 1; } || echo 0)"
} > "$T/trial.env"
echo "trial $T: $(sed -n 's/^pass=//p' "$T/trial.env")"
