# RSI eval harness

Reproducible coding-task harness for the `rsi` issues (#192, blocking #193–#196).
Fixture and oracle are restored from `git show d8ed43e^:docs/evals/evidence/`.

| File | Role |
|---|---|
| `tasks.json` | task requests, split seed, and the **frozen** model/effort/tools/timeout |
| `split.json` | train/val/test derived from the seed; `split.py --check` fails on drift |
| `fixture.sh` | builds one task's `tally` repo (deterministic tree) |
| `oracle.py` | frozen scorer; evaluator-only, never copied into the fixture |
| `run.sh` | one headless trial against a candidate SHA; **paid** |
| `finalization.sh` | #196 metrics: `proof_calls`, `proof_turns` (model turns that ran a proof), and `approved_entries`/`approved_rejected` (new APPROVED entries the R2 guard would reject on the final tree), scored with the evaluator's guard core |
| `report.py` | per-split pass/fail plus median and IQR of the `session-digest.py --json` metrics |
| `test.sh` | free self-test of everything above |

## Loop

```bash
bash evals/rsi/test.sh                                    # free
for t in D01 D02 D03 D05; do for n in 1 2 3 4 5; do
  bash evals/rsi/run.sh "$OUT" "$t" "$CANDIDATE_SHA" "$n"
done; done
python3 evals/rsi/report.py "$OUT" train                  # the only report the proposer reads
python3 evals/rsi/report.py "$OUT" val                    # selector picks one candidate, then freezes it
python3 evals/rsi/report.py "$OUT" test                   # once, on the frozen candidate
```

A task passes when most of its trials pass every oracle predicate. The overlay
copied into each fixture from `CANDIDATE_SHA` is `.harness/WORKFLOW.md`,
`skills/stages/*` (as `.claude/skills/`), `setup/agents/worker.md`, and
`scripts/workflow/record-check.sh`. The pre-commit hook is not installed in the
fixture; `finalization.sh` re-executes proofs after the trial instead.
Trials run with `--permission-mode bypassPermissions` inside the throwaway
fixture, so run them in a sandbox you are willing to give that to.

## Running a grid cheaply

Waking the orchestrating agent costs a full context read per wake-up. A
2026-11-03 audit found about 28% of one session's quota spent on per-trial
Monitor wake-ups.

- Put `$OUT` under `/var/tmp`: `run.sh` refuses an out-root that inherits an
  ancestor `CLAUDE.md` or `.claude/rules`.
- Launch the whole grid as one `run_in_background` command, so it notifies once
  when it finishes. Do not use a Monitor that fires per trial.
- If you do need a Monitor, fire only on the final line or an error, and follow
  with `tail -n 0 -F`. `tail -n +1` replays old lines.
- Run the orchestrating session on Sonnet, since it only launches and waits.
  Stop background shells before ending the session.
