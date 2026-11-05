---
status: active
lane: high-risk
---
# rsi prompt surface (#193)

## Goal
- outcome: a frozen candidate edit to the prompt surface (`skills/stages/*/references/*.md`, `setup/agents/worker.md` body) makes the orchestrator integrate verified worker output into the main tree after a wave, without lowering pass rate elsewhere.
- success_signal: `python3 evals/rsi/report.py <out> train` shows D03 passing ≥4/5 trials on the candidate and more passes than the 5-trial baseline at 00bd527; val (D05) does not regress; test (D01) runs exactly once on the frozen candidate and passes.
- actors: the orchestrating agent running `work full` with a fanout wave; workers in `setup/agents/worker.md`; the owner who approves the frozen candidate.
- authority: issue #193 (RSI constraints, HarnessMM App. B.2); `evals/rsi/README.md`; `evals/rsi/split.json` (train D02/D03, val D05, test D01); D03 finding on #193 (trials 2–3 verify workers then stop before integrating).
- requirements:
  - R1: baseline recorded — train and val at the current master SHA, 3 trials per task, report output kept in `## Validation`. | acceptance: `python3 evals/rsi/report.py <baseline-out> train` and `... val` outputs logged | source: #193 How step 1
  - R2: each candidate changes only the allowed surface. | acceptance: `git diff --name-only master..<candidate>` lists only `skills/stages/*/references/*.md` and `setup/agents/worker.md` | source: #193 What
  - R3: the proposer reads only train reports; selection uses val; at most 5 rounds. | acceptance: `## Log` names each round's candidate SHA and the report it read | source: #193 RSI constraints
  - R4: the frozen candidate passes D03 ≥4/5 (5 trials), beating the 5-trial baseline count, and D02 not worse than baseline on train. | acceptance: `python3 evals/rsi/report.py <out> train` | source: owner (D03 first target)
  - R5: test runs once on the frozen candidate and its result never feeds a proposer. | acceptance: one test run in `## Log` after the freeze entry; `report.py <out> test` passes | source: #193 RSI constraints
  - R6: no guard loosened; the skill contract tests still pass. | acceptance: `cd cli && cargo test` and `bash scripts/ci/test-guards.sh` exit 0; no diff under `setup/install-git-hooks.sh`, `evals/rsi/oracle.py` or `setup/settings*.json` | source: #193 What
- non-goals:
  - NG1: no change to model, effort, tools or timeout in `evals/rsi/tasks.json`, nor to the oracle.
  - NG2: the `output_tokens` −15% target from #193 is reported, not gated, in this plan.
  - NG3: #194–#196 surfaces (hooks, mods, compaction) are out of scope.

## Phases and Verification
- approach: baseline at master, then up to 5 proposer rounds on train only, select one candidate by val, freeze, run test once. Each candidate is a branch commit whose SHA `evals/rsi/run.sh` overlays. Rejected: writing the integration fix by hand without baseline/val, which breaks the frozen-split rule in #193.
- constraints: frozen model/effort/tools/timeout in `evals/rsi/tasks.json`; out-root under `/var/tmp/rsi-runs/`; 3 trials per task per candidate; every trial is a paid `claude -p` run.
- recovery: candidates live on branches `quaqua/rsi-c<round>-<n>`; master is untouched until the frozen candidate's PR; a bad round is dropped by abandoning its branch.
- risks: overfit to a 2-task train set → val D05 must hold; spend → stop after 5 rounds or 2 rounds with no train gain; test leakage → test runs only after the freeze entry in `## Log`.
- seams: `evals/rsi/run.sh <out> <task> <sha> <n>` and `evals/rsi/report.py <out> <split>`; contract tests `cd cli && cargo test`.
- phase_slug: `baseline`
  status: done
  - goal: R1 | depends_on: none
  - surfaces: `/var/tmp/rsi-runs/baseline/`, this plan's `## Validation` | avoided: all tracked source
  - escalate_when: `bash evals/rsi/test.sh` fails, or a trial errors on infrastructure
  - wave 1:
    - T1 run D02, D03, D05 × 3 at master SHA (owner: main agent, writes `/var/tmp/rsi-runs/baseline/` only) — output: 9 trial dirs — check: `python3 evals/rsi/report.py /var/tmp/rsi-runs/baseline train && python3 evals/rsi/report.py /var/tmp/rsi-runs/baseline val` — stop_if: any trial times out twice
  - phase check: both report outputs recorded in `## Validation`
- phase_slug: `rounds`
  status: planned
  - goal: R2, R3, R4, R6 | depends_on: baseline
  - surfaces: `skills/stages/*/references/*.md`, `setup/agents/worker.md` body | avoided: `evals/rsi/**`, `setup/install-git-hooks.sh`, `setup/settings*.json`, `cli/**`
  - escalate_when: a candidate needs a file outside the allowed surface, or an acceptance check must change
  - wave 1 (repeat per round, ≤5):
    - T1 propose 1–3 diffs from the latest train report only (owner: proposer sub-agent, writes allowed surface on its branch only) — output: candidate SHAs + hypothesis + risk — check: `git diff --name-only master..<sha>` within allowed surface and `cd cli && cargo test` — stop_if: proposer cites val or test data
    - T2 run D02, D03 × 3 per candidate (owner: main agent, writes `/var/tmp/rsi-runs/r<round>-<n>/` only) — output: train report per candidate — check: `python3 evals/rsi/report.py /var/tmp/rsi-runs/r<round>-<n> train`
  - wave 2:
    - T3 run D05 × 3 on the best train candidates; pick one; log `decision: freeze <sha>` (owner: main agent) — check: `python3 evals/rsi/report.py <out> val` not worse than baseline
  - phase check: frozen candidate D03 ≥2/3, D02 ≥ baseline; `cd cli && cargo test && bash scripts/ci/test-guards.sh`; independent verifier reviews the frozen diff
- phase_slug: `test`
  status: planned
  - goal: R5 | depends_on: rounds
  - surfaces: `/var/tmp/rsi-runs/test/`, PR for the frozen candidate | avoided: any further edit to the candidate
  - escalate_when: test fails (no retry; report to owner)
  - wave 1:
    - T1 run D01 × 3 once on the frozen SHA (owner: main agent) — output: test report — check: `python3 evals/rsi/report.py /var/tmp/rsi-runs/test test`
  - phase check: test report in `## Validation`; PR opened with the frozen diff, baseline/train/val/test tables, and token metrics

## Log

- 2026-11-04 — baseline — start — fanout: 3 workers (sonnet), one per task D02/D03/D05, 3 trials each at 00bd527, out-root /var/tmp/rsi-runs/baseline.
- 2026-11-04 — baseline/T1 — done — 9/9 trials ran; train D02 3/3, D03 2/3; val D05 3/3; pass flags checked in each trial.env.
- 2026-11-04 — baseline — decision — D03 already meets R4's ≥2/3 at baseline (was 1/3 at 9335066), so R4 cannot discriminate with 3 trials; owner to decide before rounds.
- 2026-11-04 — baseline — decision — owner: D03 runs 5 trials per candidate (overrides the 3-trial constraint for D03 only); baseline adds D03 trials 4–5.
- 2026-11-04 — baseline — done — D03 5-trial baseline 3/5 (trials 2 and 5 fail r1_punct, r2_nfc_sort, r3_cli_combined: wave output not integrated); phase baseline complete.
- 2026-11-04 — rounds — start — round 1: proposer sub-agent (worktree) reads `report.py /var/tmp/rsi-runs/baseline train` and D02/D03 trial dirs only; writes branches `quaqua/rsi-c1-<n>` off 00bd527.
- 2026-11-04 — rounds/T1 — done — round 1 candidates (read baseline train report + D02/D03 trials only; no D05/D01): c1-1 6ca4617 (integration target stays the main checkout despite cwd-moved notice), c1-2 2a52504 (wave integration needs no owner merge approval), c1-3 e1c42cc (worker `done` only after output is in main tree); all within allowed surface, `cargo test` pass.
- 2026-11-04 — rounds/T2 — start — train D02×3, D03×5 per candidate into /var/tmp/rsi-runs/r1-{1,2,3}.
- 2026-11-05 — rounds/T2 — invalid — round 1 produced no usable train data: 15/15 trials across r1-{1,2,3} carry `You've hit your 5-hour limit · resets 9pm` in `trace.jsonl`. Trials D0*/2–4 ran 2–3 s with `output_tokens: 0` and `tool_use: 0`; each D03/1 trial integrated both branches and was cut before T3, which is why `r3_cli_combined` fails. `run.sh` scores a limited trial as `pass=0`, so `report.py train` (D03 1/5 per candidate) is a harness artifact, not a candidate result. Baseline is unaffected: 12/12 baseline trials ran 16–162 s with no limit message.
- 2026-11-05 — rounds/T2 — decision — discard r1-{1,2,3}; round 1 is unspent, not lost. No candidate may be selected from it, and no round-2 proposal cites it.
- 2026-11-05 — owner — decision — run the grid on `omp` + `google-antigravity/gemini-3.8-flash` instead of the rate-limited Claude subscription, and fix the harness in this PR rather than carrying the defect. This supersedes NG1 for the model/effort pair: `evals/rsi/tasks.json` keeps `frozen.model` (Claude Code) and gains `frozen.omp_model`, and `RSI_RUNTIME` selects the pair. The baseline must be re-measured on the new runtime; the 00bd527 Claude baseline is no longer comparable and is kept only as a historical record.
- 2026-11-05 — harness — done — `evals/rsi/run.sh` gains: an `RSI_RUNTIME` switch (`claude` default, `omp` opt-in), an `omp_model` lookup, the Claude-tool-name to omp-tool-name map (`Skill` → `manage_skill`), project subagents under `.omp/agents/` (omp does not read `.claude/agents/`), an omp metrics reader for `--mode=json` traces, and a rate-limit guard that tags `limited=1` and forces `pass=0`. Free `evals/rsi/test.sh` 10/10. One paid smoke trial `RSI_RUNTIME=omp … D05 00bd527 1`: 5/5 predicates, `elapsed_s=97`, `output_tokens=4461`, `tool_use=22`, `limited=0`.

- 2026-11-05 — harness — done — rate-limit guard false-positived on omp traces (bare `429` matched token counts, costs, call ids; a mid-run 429 that omp retried on another credential also matched). Moved to `evals/rsi/limited.sh`: final trace record + stderr only, no bare `429`. `evals/rsi/test.sh` 11/11 (new case: number, retried 429, Claude 5-hour limit, terminal omp 429 → 0011). Re-scored baseline-omp D02/3, D03/5, D05/3 to `limited=0 pass=1` (all predicates pass); r1-1 Claude trials still tag limited.
- 2026-11-05 — baseline — done — omp + gemini-3.8-flash @00bd527 into /var/tmp/rsi-runs/baseline-omp: D02 3/3, D03 5/5, D05 3/3; 0 limited.
- 2026-11-05 — rounds/T2 — done — r1b on omp, 0 limited: r1b-1 (6ca4617) D02 3/3, D03 5/5; r1b-2 (2a52504) D02 3/3, D03 3/5 (trials 1, 3 fail r1_punct, r2_nfc_sort, r3_cli_combined); r1b-3 (e1c42cc) D02 3/3, D03 4/5 (trial 3, same predicates).
- 2026-11-05 — rounds — blocked — gate: escalate_when "an acceptance check must change". Evidence: omp baseline D03 is 5/5, so R4 ("≥4/5, beating the 5-trial baseline count") cannot be met by any candidate on this runtime; the D03 integration gap does not reproduce on gemini-3.8-flash (failure_class: MISSING_CONTEXT). Next action: owner picks runtime/target for R4.
- 2026-11-05 — owner — decision — close the D03 target: the integration gap does not reproduce on omp + gemini-3.8-flash (baseline 5/5), so no candidate is selected or frozen; commit only the harness fix. Test (D01) is not run.

## Validation

- baseline @00bd527 (`report.py /var/tmp/rsi-runs/baseline train|val`): D02 3/3 (output_tokens median 6383, IQR 988), D03 2/3 (median 5196, IQR 1538; trial 2 fails r1_punct, r2_nfc_sort, r3_cli_combined), D05 3/3 (median 1294, IQR 509).
- D03 5-trial baseline @00bd527: 3/5, output_tokens median 5196, IQR 2650. Bar for R4: candidate ≥4/5.
- baseline-omp @00bd527 (omp + gemini-3.8-flash): D02 3/3 (output_tokens median 26702), D03 5/5 (median 40278), D05 3/3 (median 5030).
- r1b train (omp): c1-1 D02 3/3, D03 5/5 (median 41764); c1-2 D02 3/3, D03 3/5; c1-3 D02 3/3, D03 4/5.

## Current State and Next Action
- active_phase: rounds
- lifecycle_status: in-progress
- blockers: none; D03 target closed by owner.
- open_items: whether the merged candidate still shows the D03 integration gap on the new runtime at all — a different model may not reproduce the failure, which would make the candidate untestable rather than proven.
- exact_next_action: record the D03 conclusion on #193 and close or archive this plan.
