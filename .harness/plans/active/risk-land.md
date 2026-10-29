---
status: active
lane: high-risk
---
# Risk verdict, low-risk auto-merge, and exercise proof

## Goal
- outcome: A green PR gets an independent, commit-bound risk verdict; low-risk PRs merge themselves when the repo opts in, needs-review PRs get a short "where to look" list; changes that alter runtime behavior carry exercise evidence; a diff touching risky paths cannot ride a declared lane lower than `high-risk`.
- success_signal: `cd cli && cargo test` and `bash scripts/ci/test-guards.sh` pass with new fixtures for the lane-raise guard; `bash scripts/ci/verify-doc-links.sh` and `bash scripts/ci/validate-skills.sh` pass; one real PR in this repo shows a `## Risk` section and, when low risk, is merged by `ship` with the merged message.
- actors: the owner (reads verdicts, reviews needs-review PRs); the lead agent running `ship`/`babysit`; the independent judge sub-agent.
- authority: owner decision 2026-10-28 (auto-merge on immediately, all three parts in one plan); reference implementation mgratzer/forge (`skills/_shared/risk-rubric.md`, `skills/forge-land/SKILL.md`, `skills/_shared/exercise.md`); `skills/stages/check/references/check.md` § Lane Matrix.
- requirements:
  - R1: A risk rubric exists (size over 400 counted lines; always-review paths: CI workflows, git hooks/guards, dependency manifests or lockfiles, migrations, project security paths; deleted or weakened tests; exercise reported `wrong`; unstated plan deviation) plus a judgment test (low risk only if the judge names what the checks would miss). | acceptance: rubric file is linked from `ship.md` and `check.md`; `verify-doc-links.sh` passes | source: forge risk-rubric
  - R2: `ship.md` gains a land step: an independent fresh-context judge on the head SHA writes `## Risk` (verdict + full SHA) into the PR body; low risk with `Auto-merge: low-risk` in `AGENTS.md` → `gh pr merge --squash --auto --match-head-commit <sha>`; a moved head makes the verdict stale. | acceptance: `ship.md` steps name the command and stale-head rule; dry walk-through on a real PR | source: forge-land, owner decision
  - R3: After a merge, the reply shows the verdict block and a merged line (PR number, merged SHA, base, revert command); needs-review shows 2–5 `file:line` questions and does not merge. | acceptance: output format fixed in `ship.md` Reply; observed on a real PR | source: owner decision
  - R4: `babysit.md` never merges; it stops at review-ready and hands off to the land step. | acceptance: grep shows no merge command in `babysit.md` and a hand-off line | source: forge-guard
  - R5: `AGENTS.md` declares `## Unattended Shipping` with `Auto-merge: low-risk` and the security-sensitive paths; the "merge only on explicit request" wording in `ship.md`, `skills/stages/README.md` and `skills/mono/SKILL.md` carves out this opt-in. | acceptance: grep for the carve-out in each file | source: owner decision
  - R6: An exercise step (drive the changed path once plus one failure case; `## Exercised` section with `not exercised: <why>` fallback) is required by `feature.md` and recorded by `check`. | acceptance: `check.md` and `feature.md` reference it; `cargo test` passes (embedded contracts) | source: forge exercise
  - R7: The pre-commit guard rejects an approvable entry on a plan whose declared lane is below `high-risk` when the staged diff touches an always-review path; Lane Matrix, guard and `test-guards.sh` change together. | acceptance: new failing-then-passing fixtures in `scripts/ci/test-guards.sh` | source: check.md § Lane Matrix
  - R8: The merge memory is updated to allow low-risk auto-merge after green. | acceptance: memory file text | source: owner decision
- non-goals:
  - NG1: No change to the `zharness` CLI behavior beyond tests pinning reference text.
  - NG2: No auto-merge for needs-review PRs, no force-push, no tag or release automation.
  - NG3: No live UI/lens like forge's plugin.

## Phases and Verification
- approach: Port forge's land/rubric/exercise as procedure text in existing playbooks and check references, opt-in via an `AGENTS.md` section, and enforce only the lane raise mechanically in the existing pre-commit guard (new rule R5 beside R3/R4). Rejected: a `zharness land` CLI subcommand — violates "zharness only installs" and NG1.
- risks: auto-merge lands a bad PR → verdict bound to `--match-head-commit`, independent judge, always-review paths force needs-review, revert command printed; stop and turn `Auto-merge` off if any auto-merged PR is reverted. Guard R5 false-positives block normal commits → fixtures for both hit and miss paths; recovery: declare `lane: high-risk` or revert the rule commit.
- seams: `skills/mono/playbooks/{ship,babysit,feature}.md`; `skills/stages/check/references/check.md` § Lane Matrix and step 6; `setup/install-git-hooks.sh` ZGUARD-CORE block; `scripts/ci/test-guards.sh`; `cli/src/embedded.rs` + `cli/tests/skill_reference_resolution.rs` text contracts; `AGENTS.md`.
- phase_slug: `land`
  status: in-progress
  - goal: R1, R2, R3, R4, R5, R8 | depends_on: none
  - surfaces: `skills/stages/check/references/check-risk.md` (new), `check.md` link, `skills/mono/playbooks/ship.md`, `babysit.md`, `skills/mono/SKILL.md`, `skills/stages/README.md`, `AGENTS.md`, merge memory | avoided: `cli/src/**` logic, hooks
  - escalate_when: the repo has no CI checks that `gh pr checks` can see, or `--match-head-commit` with `--auto` is refused by GitHub settings
  - wave 1:
    - T1 write risk rubric + judgment test + `## Risk` and merged-message formats (owner: lead, writes `check-risk.md`, `check.md` link only) — output: rubric file — check: `bash scripts/ci/verify-doc-links.sh` — stop_if: link check fails
    - T2 add `## Unattended Shipping` (Auto-merge: low-risk, security paths) to `AGENTS.md` (owner: lead, writes `AGENTS.md` only) — output: section — check: `grep -A6 "^## Unattended Shipping" AGENTS.md`
  - wave 2:
    - T3 land step + Reply format in `ship.md`; merge carve-out in `skills/mono/SKILL.md` and `skills/stages/README.md`; `babysit.md` stops at review-ready and hands off (owner: lead, writes those 4 files only) — output: procedure text — check: `grep -n "match-head-commit" skills/mono/playbooks/ship.md && ! grep -nE "gh pr merge" skills/mono/playbooks/babysit.md && bash scripts/ci/validate-skills.sh` — stop_if: validate-skills fails
    - T4 update merge memory (owner: lead, writes memory file only) — output: memory text — check: `grep -i "low-risk" ~/.claude/projects/-Users-tinhtute-Lab-mono-harness/memory/merge-wait-for-green.md`
  - phase check: `bash scripts/ci/verify-doc-links.sh && bash scripts/ci/validate-skills.sh && (cd cli && cargo test)`
- phase_slug: `exercise`
  status: in-progress
  - goal: R6 | depends_on: land
  - surfaces: `skills/stages/check/references/check-exercise.md` (new), `check.md` step 6 link, `skills/mono/playbooks/feature.md` | avoided: Lane Matrix columns
  - escalate_when: a `cargo test` text contract pins wording that the exercise step must change
  - wave 1:
    - T5 write exercise procedure and `## Exercised` report format; link from `check.md` and a step in `feature.md` (owner: lead, writes those 3 files only) — output: procedure — check: `bash scripts/ci/verify-doc-links.sh && (cd cli && cargo test)` — stop_if: a contract test fails twice
  - phase check: `bash scripts/ci/verify-doc-links.sh && bash scripts/ci/validate-skills.sh && (cd cli && cargo test)`
- phase_slug: `lane-raise`
  status: in-progress
  - goal: R7 | depends_on: land
  - surfaces: `setup/install-git-hooks.sh` (new R5 in ZGUARD-CORE), `scripts/ci/test-guards.sh`, `check.md` § Lane Matrix note | avoided: R2/R3/R4 behavior
  - escalate_when: the always-review path list cannot be read identically by the guard and the rubric
  - wave 1:
    - T6 add failing fixtures: lane `normal` plan + staged `.github/workflows/x.yml` with approvable entry → reject; same with only docs → accept (owner: lead, writes `test-guards.sh` only) — output: red run — check: `bash scripts/ci/test-guards.sh` fails on the new cases
    - T7 implement R5 in the guard and the Lane Matrix note; reinstall hooks (owner: lead, writes `install-git-hooks.sh`, `check.md` only) — output: green run — check: `bash scripts/ci/test-guards.sh && bash setup/install-git-hooks.sh --force` — stop_if: any pre-existing guard case regresses
  - phase check: `bash scripts/ci/test-guards.sh && (cd cli && cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test)`
- validation: final `check full` with an independent judge; then dogfood on this plan's own PR — land must judge it needs-review (hooks and CI-adjacent paths), proving the no-merge path; a later docs-only PR proves the merged message.

## Log
- 2026-10-28 — phases land, exercise, lane-raise implemented; gates green: test-guards 99/0, cargo fmt/clippy/test, doc-links, validate-skills. Independent `check full` not run yet.
- 2026-10-29 — CI hook-guard red (89/8): fixtures ran the real R6 changed-path source from the repo root and read the branch's own diff. Fixed by stubbing it in test-guards.sh and testing the real one in a temp repo; 98/0. Phase statuses set to in-progress to match the Log.

## Validation

## Current State and Next Action
- active_phase: lane-raise
- lifecycle_status: in-progress
- blockers: none
- open_items: none
- exact_next_action: check full (independent judge) on all three phases, then dogfood land on this PR
