# RSI eval harness

Reproducible coding-task harness for the `rsi` issues (#192, blocking #193–#196).
Fixture and oracle are restored from `git show d8ed43e^:docs/evals/evidence/`.

| File | Role |
|---|---|
| `tasks.json` | task requests, split seed, and the **frozen** model/effort/tools/timeout |
| `split.json` | train/val/test derived from the seed plus `pinned` tasks (D06 → val); `split.py --check` fails on drift |
| `fixture.sh` | builds one task's `tally` repo (deterministic tree) |
| `oracle.py` | frozen scorer; evaluator-only, never copied into the fixture |
| `run.sh` | one headless trial against a candidate SHA; **paid**. `RSI_MODS=1` loads the candidate's `setup/mods` with `--plugin-dir`; `RSI_COMPACT=1` then resumes the session with `/compact` and a probe turn (claude runtime only) |
| `compact_probe.py` | #203 probe on the forced-compact phases: `compacted`, `summary_keeps_trash` (the summary still states trash-not-rm), `trash_survives_compact` (the first post-compact delete of `probe.tmp` uses `trash`), and `compact_total_tokens`/`compact_cost_usd`, kept apart from the task's own cost |
| `finalization.sh` | #196 metrics: `proof_calls`, `proof_turns` (model turns that ran a proof), and `approved_entries`/`approved_rejected` (new APPROVED entries the R2 guard would reject on the final tree), scored with the evaluator's guard core |
| `cost.py` | complete-trial cost: `total_tokens` (input + cache read/write + output, subagents included) and `cost_usd` |
| `accept.py` | parent-vs-child rule on one split: every task keeps its pass rate and median `total_tokens` ≤ 0.9× parent |
| `report.py` | per-split pass/fail plus median and IQR of the `session-digest.py --json` metrics |
| `test.sh` | free self-test of everything above |

## Loop

```bash
bash evals/rsi/test.sh                                    # free
for t in D01 D02 D03 D05 D06; do for n in 1 2 3 4 5; do
  bash evals/rsi/run.sh "$OUT" "$t" "$CANDIDATE_SHA" "$n"
done; done
python3 evals/rsi/report.py "$OUT" train                  # the only report the proposer reads
python3 evals/rsi/report.py "$OUT" val > child.json      # selector picks one candidate, then freezes it
python3 evals/rsi/accept.py parent.json child.json        # exit 0 only if quality kept and tokens <= 0.9x
python3 evals/rsi/report.py "$OUT" test                   # once, on the frozen candidate
```

A task passes when most of its trials pass every oracle predicate. The overlay
copied into each fixture from `CANDIDATE_SHA` is `.harness/WORKFLOW.md`,
`skills/stages/*` (as `.claude/skills/`), `setup/agents/worker.md`, and
`scripts/workflow/record-check.sh`. The pre-commit hook is not installed in the
fixture; `finalization.sh` re-executes proofs after the trial instead.
Trials run with `--permission-mode bypassPermissions` inside the throwaway
fixture, so run them in a sandbox you are willing to give that to.

## Mods and compaction (#203)

Default trials load no mods and never compact, so `COMPACT_RULES` in
`setup/mods/ninja-kit` cannot show. `RSI_MODS=1 RSI_COMPACT=1 bash evals/rsi/run.sh ...`
extracts `setup/mods` at `CANDIDATE_SHA` into the trial's config dir and passes it
as `--plugin-dir`, which loads each child mod under `claude -p`. After the task is
scored, it resumes the session with `/compact` (a `compact_boundary` record in
`compact.jsonl`) and then asks the agent to delete an untracked `probe.tmp`
(`probe.jsonl`). `session.jsonl` keeps the session transcript with the summary.
`trace.jsonl` holds only the task, so the task metrics stay comparable with
parents run without these flags. Both flags are refused for `RSI_RUNTIME=omp`.

The cache-guard `threshold` is still unobservable headless. It only gates the
`AbovePrompt` band, which `claude -p` never draws, after a model or effort switch,
which a frozen trial never makes. `--plugin-dir` mods also read
`pluginConfigs` from user, `--settings` or managed settings only, never from
project settings.

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
