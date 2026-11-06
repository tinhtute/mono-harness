# pstack concepts audit

Read-only comparison of agent-engineering patterns. Sources at audit time:

- mono-harness `13a3570` (master).
- pstack-claude `903e738`, cloned to `/tmp/pstack-claude` (https://github.com/michael-denyer/pstack-claude).

Bar for a recommendation: it must fix a problem mono-harness has already recorded, in `docs/evals/failures.md`, `docs/evals/runs.md`, or Git history. Having the feature in pstack is not enough.

## 1. Executive summary

- **mono-harness is ahead on proof enforcement.** Its pre-commit and CI guard re-executes every cited proof (R2) and rejects `judge: same-session` on high-risk plans (R3). pstack's `check-plan.mjs` only checks plan structure (boxes and headings), and nothing in pstack re-runs a proof.
- **mono-harness is ahead on eval rigor.** It has a frozen routing case set with a holdout split (`docs/evals/routing.md`) and a failure ledger with a `coverage` field per incident (`docs/evals/failures.md`). pstack's `playbooks/eval.md` is a blinded-judge procedure with no stored cases and no run log.
- **Best fit #1: the hook wrapper should be a thin call into tracked code.** pstack's pre-commit only runs the tracked `bun tools/generate.mjs --check`, so nothing goes stale at install time. In mono-harness, ledger row "2026-09-16 — an installed pre-commit wrapper can go stale" is still `uncovered`.
- **Best fit #2: every checker needs a fixture that must trip it.** pstack's `tests/invariants.test.mjs` proves each layout check can fail. In mono-harness, `scripts/verify-doc-links.sh` and `scripts/validate-skill.sh` have no failing fixture. `cli/tests/projection_parity.rs` and `scripts/test-guards.sh` already do this.
- **pstack does not fix mono-harness's clearest routing failure.** That failure is H04, where an explicit `check review` was upgraded to a durable gate. pstack's only Claude Code hook is a SessionStart context injection, which is instruction text, not enforcement.
- **Routing differs in kind.** pstack injects a router mandate at every session start (`plugins/pstack/hooks/session-start-context.md`). mono-harness routes through skill metadata plus a 26-line `docs/WORKFLOW.md`. ADR 0003's argument against recurring per-session cost applies here, so this is not adopted.
- **"Encode lessons in structure" is a pstack principle that mono-harness already practices.** The ledger's `coverage` field, test-guards fixtures, and the hook guards all do this. Nothing to copy.
- **Multi-model adversarial review is a gap, but no recorded problem calls for it.** `interrogate` runs one reviewer per model and gives more weight to findings several models agree on. mono-harness's `check-review.md` has only the spec and standards axes, with one judge.
- **Not worth adopting for a lightweight harness:** TLA+/Lean models, five runtime ports, model-sheet stamping, the PreToolUse script-contract allowlist, and swarm verification lanes.

## 2. Comparison matrix

| Concept | mono-harness evidence | pstack evidence | Existing coverage | Actual gap | Trade-offs | Recommendation |
|---|---|---|---|---|---|---|
| Task routing | `docs/WORKFLOW.md` (Context table); `skills/stages/check/references/check.md` Preconditions step 1 (`auto` → bounded/gate) | `plugins/pstack/hooks/session-start-context.md`; `plugins/pstack/skills/poteto-mode/SKILL.md` Playbooks (24 playbooks) | Strong. Routing evals R01–R10 and H01–H04 | H04 and H01 failed in run 001 and have not been re-measured since (`docs/evals/lean-workflow.md` "Status and re-evaluation") | A per-session injection costs tokens in every session | No pstack adoption. Re-run H04 on C instead |
| Context management | `docs/WORKFLOW.md` Context: read only the primary reference; transfer brief carries the HEAD SHA | `principle-guard-the-context-window` (route bulk work to subagents); `playbooks/pause-safely.md` | Covered: transfer brief, `watzup`, `handoff` | None demonstrated | — | None |
| Workflow design | Six-skill spine with plan sections owned per skill (`skills/stages/README.md` mapping table) | Playbook todolist copied verbatim, `skip: <reason>` per step; project playbooks with anchor-checked `extends` (`check-playbooks.mjs`) | Covered | No consumer extension mechanism, but none was requested (ADR 0007 overwrites procedures in full) | Anchor check adds an upgrade contract | None |
| Multi-agent coordination | `check-review.md`: sub-agents only for `full` and only when asked; `design-it-twice.md` step 2 | `swarm/SKILL.md` Phase C: drop any result missing the SHAs or method its brief named; `poteto-mode` "Fresh subagents by default" | Partial. The transfer brief requires the SHA | No rule that rejects a worker report missing its SHA | More procedure text | None. No recorded incident |
| Architecture exploration | `skills/reason/think/references/design-it-twice.md` (3+ designs, compared on depth and seams) | `architect/SKILL.md` Phases A–D: sketch with `not implemented` bodies, arena synthesis, red-flag screen, contract deviations recorded | Covered for design. Implementing against the sketch is not covered | Phase D (sketch-as-contract) has no counterpart | Needs multi-model runners | None |
| Adversarial review | `check-review.md` (spec and standards axes); `check.md` step 7 judge declaration | `interrogate/SKILL.md` Steps 3–4 (one reviewer per model, merge cross-model agreement); `thermo-nuclear-review` (audit diff first, read bot comments after) | Partial | No model diversity, no "fresh eyes before bot comments" rule | Costs N× tokens per review | None now (HYPOTHESIS value only) |
| Verification | setup/install-git-hooks.sh (now `scripts/install-git-hooks.sh`) ZGUARD-CORE R2 (proof re-execution), R3, PHASE-DONE; CI `hook-guard` | `check-plan.mjs` (structure only); `principle-prove-it-works`; CI `generated` job | **mono-harness ahead** | — | — | Keep |
| Failure learning | `docs/evals/failures.md` (class, source SHA, `coverage`); ADR 0010; `skills/stages/retro/references/retro.md` + `session-digest.py` | `reflect/SKILL.md` (3 reviewer lenses + synthesizer, then a step that moves enforceable items to Backlog); `recall` | **mono-harness ahead** (ledger is durable, reflect output is not) | — | — | Keep |
| Enforcement | Hooks: pre-commit, pre-push; CI `cli-ci.yml` (build-test, size-gate, hook-guard), `docs-ci.yml`; `cli/tests/projection_parity.rs` (has drift tests) | `.pre-commit-config.yaml` → tracked `tools/generate.mjs --check`; `tests/invariants.test.mjs`; CI `skills-only` (install, then `diff -qr`) | Strong | (a) installed wrapper can go stale (ledger, `uncovered`); (b) two checkers have no failing fixture | Small | **Adopt (a) and (b)** |

## 3. Evidence-backed findings

**F1. The installed hook wrapper can go stale. VERIFIED.**
- mono-harness: `create_pre_commit_hook` in setup/install-git-hooks.sh (now `scripts/install-git-hooks.sh`) writes a heredoc wrapper that extracts ZGUARD-CORE at run time. The wrapper's own call sequence is baked in at install time.
- `install_hook_file` does replace a stale zharness hook, but only when someone re-runs the installer. `scripts/test-guards.sh` case R16 covers that replacement. Nothing runs the installer after the template changes.
- Ledger: `docs/evals/failures.md` "2026-09-16 — an installed pre-commit wrapper can go stale against its own template", `coverage: uncovered`.
- Mitigation: CI `hook-guard` re-runs the guard core on push, so a stale local wrapper delays rejection until CI. It does not bypass the guard.
- pstack: `.pre-commit-config.yaml` has a single entry, `bun tools/generate.mjs --check`, with no generated wrapper. Its comment notes a different weakness: the hook reads the working tree, not the index.
- Limitation: pstack's model needs `prek` or `pre-commit` installed. The pattern is "hook = exec of tracked script", not the tool itself.

**F2. Two checkers have no fixture that proves they can fail. VERIFIED absence, HYPOTHESIS value.**
- Searches: `git grep -nIE 'verify-doc-links|validate-skill'` across `scripts` and `cli/tests` finds only the scripts themselves. `grep -nE 'self-test|--test|fixture'` on both scripts finds nothing.
- pstack: `tests/invariants.test.mjs` header says *"A check that quietly matches nothing looks identical to a pass, and that already happened once."*
- Weak precedent in mono-harness: commit `f5af8e8` is titled "revive skill validation". Its body doesn't say how validation was dead, so a silent-pass incident is not proven.
- Counter-evidence: mono-harness already uses this pattern in `projection_parity_detects_drift` (`cli/tests/projection_parity.rs`) and throughout `scripts/test-guards.sh`.

**F3. pstack has no structural fix for H04. VERIFIED.**
- mono-harness: `docs/evals/runs.md` run 001, row `r001-H04` (fail): an explicit `check review` was turned into `mode: gate`, which wrote plan state.
- The current text has a defense: `check.md` Preconditions step 1 lists the aliases (`review` → `bounded`), and the "Zero-write rule" applies. This text has not been re-measured. `docs/evals/lean-workflow.md` "Status and re-evaluation" says C is unevaluated.
- pstack: `plugins/pstack/hooks/hooks.json` registers only `SessionStart`. `pre-tool-use.sh` is Copilot-only and decides allow or deny by model and path, never by workflow mode.

**F4. Routing by session injection. VERIFIED. Not adopted.**
- pstack: `session-start.sh` cats `session-start-context.md` on `startup|resume|clear|compact`, so the router text is paid every session.
- mono-harness: `git grep SessionStart` returns no matches. Its global `PreToolUse` hooks exist only in setup/settings.json (setup/ later moved to monoclaudian) (privacy guard, `rm` block).
- ADR 0003 Decision: *"every mandatory playbook step is paid on every invocation, forever, by every consumer repo."*

**F5. Multi-model review. VERIFIED absent, HYPOTHESIS value.**
- `git grep -nIE 'model divers|different model|another model'` finds only `docs/WORKFLOW.md` (model roles), with no diversity rule.
- pstack `interrogate` Step 4 merges findings and ranks findings from 2+ models highest.
- No ledger row or eval shows a defect that one judge missed and a second model would have caught.

**F6. Rule for "no independent reviewer available". VERIFIED absent, HYPOTHESIS value.**
- pstack's `poteto-mode` Subagents section says that when no reviewer can run, record `BLOCKED: independent review` and keep the gate closed.
- In mono-harness, `check.md` step 7 requires `judge: independent` for `full` and high-risk work, and R3 rejects `same-session`. Nothing stops an author from declaring `independent` for a reviewer that is really the same model and session.
- `git grep` for `no independent|independent reviewer|reviewer.*unavailable` finds nothing relevant.
- No incident has been recorded.

**F7. Worker-report hygiene. VERIFIED, partial coverage.**
- pstack `swarm` Phase C drops any result that doesn't record the SHAs and method its brief named, and respawns the worker once.
- mono-harness `docs/WORKFLOW.md` requires the HEAD SHA in the transfer brief but has no rejection rule for reports. No incident has been recorded.

**F8. mono-harness's lead on proof is real. VERIFIED.**
- ZGUARD-CORE R2 re-executes every proof with `sh -c`, and the CI `hook-guard` job repeats it.
- pstack's `check-plan.mjs` enforces `SUB_BLOCKS` and the `RULE` sentence: *"A PR is verified only when its unit, live, and perf boxes are all checked."* That is a self-attested checkbox, not re-execution.

## 4. Prioritized opportunities

| Rank | Opportunity | Ties to | Value | Confidence | Cost | Maintenance |
|---|---|---|---|---|---|---|
| 1 | Pre-commit wrapper checks itself against the template | Ledger row 2026-09-16 (`uncovered`) | Medium. Closes the last uncovered guard row | High | Low (~10 lines plus 1 fixture) | Low |
| 2 | Failing fixtures for `verify-doc-links.sh` and `validate-skill.sh` | `f5af8e8` (weak); pattern already used in `test-guards.sh` | Medium | Medium | Low | Low |
| 3 | Re-measure H04 and H01 on the current C instructions | `docs/evals/runs.md` run 001 | High (only known routing failures) | High | Medium (paid trials, owner approval) | None |
| — | Multi-model review, unavailable-reviewer rule, worker SHA rejection | No incident | Unknown | Low | Medium | Medium |
| — | Session-start router injection, PreToolUse allowlist, model sheet, TLA+/Lean, runtime ports, swarm lanes | No problem | — | — | High | High (against ADR 0003) |

## 5. Improvement roadmap

**1. Self-checking pre-commit wrapper.** Adapted from pstack's tracked-script hook.
- Integration point: the `create_pre_commit_hook` heredoc in setup/install-git-hooks.sh (now `scripts/install-git-hooks.sh`).
- Behavior change: on each run, the wrapper regenerates its own template from the tracked installer (staged blob if staged, else worktree) and compares it with its own bytes using `cmp`. If they differ, it prints `stale pre-commit wrapper: run bash setup/install-git-hooks.sh` (now `scripts/install-git-hooks.sh`) and exits non-zero. The alternative is to shrink the wrapper to one line that `exec`s a tracked entry script, which removes the class entirely.
- Validation:
  - A new `scripts/test-guards.sh` case: install, edit the template in a fixture repo, commit, and expect a rejection naming the reinstall command. A control commit without the edit passes.
  - Then append a ledger follow-up row marking the 2026-09-16 class covered.

**2. Every checker gets a failing fixture.** From pstack's `tests/invariants.test.mjs`.
- Integration point: a fixture block in `scripts/test-guards.sh`, or a sibling script wired into the CI `hook-guard` job.
- Behavior change: a checker edit that stops matching anything fails CI instead of passing silently.
- Validation:
  - A broken backtick path and a broken markdown link in a temp tracked doc must make `verify-doc-links.sh` exit 1.
  - A `.claimignore` line without `# reason` must exit 2.
  - A SKILL.md missing `name` must make `validate-skill.sh` fail.
  - Each case has a clean-tree control that passes.

**3. Re-measure H04 and H01 before any new routing mechanism.** Not a pstack import. It is the control the other two lack.
- Integration point: `scripts/run-lean-trial.sh` or the replay path in `docs/evals/lean-workflow.md`, on routing cases R09 and H04 (explicit `review`) and H01.
- Behavior change: none to the code. It decides whether `check.md`'s zero-write text is enough, or whether H04 needs a structural guard. One example of such a guard: R2 rejecting a Validation append whose entry declares `mode: bounded`.
- Validation: a pass rate on H04 and H01 recorded in `docs/evals/runs.md` against the run-001 baseline (0/1 each).

## 6. Coverage note

**Read in full or in the relevant sections, pstack:**
- `hooks/` (all `.sh`, `pre-tool-use.awk`, `script-contracts.awk`, `hooks.json`, `session-start-context.md`)
- `.pre-commit-config.yaml`, `.github/workflows/ci.yml` (first 200 lines), `CONTEXT.md`
- `poteto-mode/SKILL.md`, the head of `check-plan.mjs`, the head of `check-playbooks.mjs`
- Skills: `swarm`, `architect` (Phases A–D), `thermo-nuclear-review`, `interrogate` (Steps 1–4), `reflect`, `recall`
- Principles: `principle-encode-lessons-in-structure`, `principle-guard-the-context-window`
- `playbooks/eval.md`, the head of `tests/invariants.test.mjs`
- `git log --oneline -n 100` (first 40 read)

**Read, mono-harness:**
- `AGENTS.md`, README Goals, `docs/WORKFLOW.md`, `skills/stages/README.md`
- `check.md`, `check-review.md`, `retro.md` §1–3, `design-it-twice.md`
- ADR 0003 (Decision) and ADR 0010 (Context)
- `docs/evals/failures.md` (all incidents), `runs.md` run 001 table, `routing.md` head, `lean-workflow.md` status
- `install-git-hooks.sh` (ZGUARD-CORE header, `install_hook_file`), `test-guards.sh` case index, `cli-ci.yml` jobs, `projection_parity.rs` test names
- Commit `f5af8e8`

**Searches (bash, run from the repo root; an earlier zsh run failed on globbing and is not counted):**
- `git grep -nIE '<pattern>' -- ':!docs/plans/completed' ':!docs/research'`, with patterns `SessionStart`, `PreToolUse`, `no independent|independent reviewer|reviewer.*unavailable`, `reinstall|--force`
- `grep -rniE` over `skills scripts docs/WORKFLOW.md docs/decisions docs/patterns cli/src .github AGENTS.md`, with patterns `model divers|different model|another model`, `must trip|must fail|negative fixture|mutation`, `PASS.*ISSUES|BLOCKED_[A-Z]`, `HEAD SHA|exact SHA`, `prototype|instead of asking`, `session-digest|transcript`, `extends:|project playbook`
- `grep -nE 'self-test|--test|fixture'` on both checker scripts

**Skipped:**
- pstack Pi extension (`plugins/pstack/pi/`), Copilot/Codex/Muse ports, `tla/`, `lean/`, `tools/sync.mjs` fork machinery, `orch`/`watch-pr` scripts, and most principle and craft skills. They are runtime- or upstream-sync-specific and fail the lightweight bar.
- mono-harness `cli/src` internals, `skills/craft`, `skills/shipping`, and `site/`. They are not related to the nine concepts.
- `pause-safely.md` and `resume.mjs` were listed but not read. mono-harness's `handoff` and transfer brief cover that concept, and no incident has been recorded.
