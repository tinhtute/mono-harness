---
status: completed
lane: high-risk
---
# Repo restructure: purpose roots and `.harness/` managed paths

## Goal
- outcome: The repository is organized by purpose — `cli/`, `skills/`, `evals/`, `setup/` (setup/ later moved to monoclaudian), `scripts/` (install + `ci/` only), `docs/` (few folders), `site/` — and zharness manages its files under `.harness/` in every consumer repo, migrating the old `docs/` layout on `zharness update`.
- success_signal: every gate in AGENTS.md is green on the final commit; `git ls-files` matches the target tree in R2–R6; a fixture repo with the old layout reaches the new layout through `zharness update` with plan bytes unchanged; `zharness update --check --all` reports `current` for mono-harness, TTDVKH and Mono after migration.
- actors: the owner (ní) and coding agents working in this repo; consumer repos managed by zharness (TTDVKH, Mono); hosts that install skills via `npx skills add`.
- authority: owner decisions in brainstorm on 2026-10-23 — scope "Full restructure"; lean-eval "Tag, then remove"; fixed paths `scripts/install-zharness.sh` and `skills/<group>/<name>`; layout "Purpose roots"; managed paths move to `.harness/`; `zharness update` migrates.
- requirements:
  - R1: The lean-eval experiment is archived and removed: tag `archive/lean-eval-v1` points at the last commit containing it; `docs/evals/` and the lean scripts (`run-lean-trial.sh`, `lean-replay-score.sh`, `verify-lean-eval.sh`, `test-lean-eval.sh`, `record-check.sh`, `generate-dashboard.sh`, `probes/`) are gone from master. | acceptance: `git rev-parse archive/lean-eval-v1` succeeds and `git ls-tree` of that tag contains `docs/evals/evidence`; `test ! -e docs/evals`; `git grep -l lean-eval -- ':!CHANGELOG.md' ':!docs/research' ':!docs/decisions' ':!docs/plans/completed'` is empty | source: owner decision
  - R2: `scripts/` holds only `install-zharness.sh`, `ci/` (doc-link check, guard tests, skill validation, installer test, fixtures) and `workflow/` (`plan-slice.sh`, `record-check.sh`, which stage skills call); CI workflows and skills call the new paths. | acceptance: `git ls-files scripts` lists only `scripts/install-zharness.sh`, `scripts/ci/**` and `scripts/workflow/**`; CI jobs `build-test`, `size-gate`, `hook-guard`, `doc-links` pass on the PR | source: owner decision (layout)
  - R3: `setup/` (setup/ later moved to monoclaudian) holds everything installed on the machine: `CLAUDE.md`, `rules/`, `hooks/`, `settings.json`, `install.sh`, `install-git-hooks.sh`, `statusline/`; the root `rules/` folder is gone. | acceptance: `test ! -e rules`; `bash setup/install.sh` into a temp `HOME` installs `~/.claude/rules/english.md` and the statusline; `bash setup/install-git-hooks.sh --force` (now `scripts/install-git-hooks.sh`) installs a pre-commit hook whose guard tests pass (`bash scripts/ci/test-guards.sh`) | source: owner decision (layout)
  - R4: `docs/` top level holds only `ARCHITECTURE.md`, `README.md` and the folders `decisions/`, `research/`, `memory/`, `guides/`; `guides/` absorbs `prompt-engineering-principles.md`, `patterns/`, `templates/` and `workflow-harness/`, which are gone from the top level. | acceptance: `ls docs` matches that list; `bash scripts/ci/verify-doc-links.sh` passes | source: owner decision (layout)
  - R5: Diagrams live only under `site/assets/` (PNG + `.tldraw` sources); root `assets/` is gone and README images resolve. | acceptance: `test ! -e assets`; `bash scripts/ci/verify-doc-links.sh` passes; README image paths exist in the tree | source: owner decision (layout)
  - R6: zharness writes and checks `.harness/WORKFLOW.md`, `.harness/PROJECT.md` and `.harness/plans/{active,completed}/` instead of `docs/WORKFLOW.md`, `docs/PROJECT.md`, `docs/plans/`; `cli/docs/CONTRACT.md`, the embedded router, the stage skills, AGENTS.md, README and the pre-commit plan guards use the new paths. | acceptance: `cd cli && cargo test` (including `projection_parity` and `skill_reference_resolution`) passes; `git grep -nE 'docs/(WORKFLOW|PROJECT)\.md|docs/plans/' -- ':!CHANGELOG.md' ':!docs/decisions' ':!docs/research' ':!.harness/plans/completed'` returns only migration code and its tests | source: owner decision (managed paths)
  - R7: `zharness update` on a repo with the old layout moves `docs/WORKFLOW.md`, `docs/PROJECT.md` and `docs/plans/**` to `.harness/`, keeps every plan's bytes, refreshes the AGENTS.md block, and is idempotent; the change ships as a release whose CHANGELOG entry is marked BREAKING. | acceptance: a cargo integration test with an old-layout fixture asserts moved paths, byte-identical plans, and a no-op second run; CHANGELOG has a BREAKING entry for the release | source: owner decision (migration)
  - R8: This repo, TTDVKH and Mono run on the new layout. | acceptance: after installing the release and running `zharness update` in each, `zharness update --check --all` prints `current` for all three | source: owner decision (migration)
- non-goals:
  - NG1: Moving or renaming `scripts/install-zharness.sh` or any `skills/<group>/<name>` path.
  - NG2: Changing skill content beyond path references.
  - NG3: Restructuring `cli/src` internals or `evals/` contents.
  - NG4: Redesigning `site/` beyond moving diagram assets into it.
  - NG5: Deleting the lean-eval history (it stays reachable through the tag).

## Phases and Verification
- approach: Three phases in dependency order — tidy the repo with `git mv` while every path the CLI owns stays put (p1), then move the managed paths inside the CLI with a red-first migration test and ship a BREAKING release (p2), then roll the release out to the three repos (p3). Rejected: one big-bang commit that moves files and CLI paths together, because a broken gate could not be traced to either half.
- constraints: `scripts/install-zharness.sh` and `skills/<group>/<name>` never move (NG1); every move is `git mv` so history follows; pushing tags and publishing releases is an owner action.
- risks: (1) a missed path reference breaks CI or a skill → `verify-doc-links.sh`, `cargo test` and a `git grep` of each old path after every task; (2) the installed pre-commit hook in `.git/hooks` points at old script paths → reinstall it in the same task that moves them; (3) migration loses or corrupts a plan → byte-equality fixture test before any consumer runs it; (4) consumers on an old binary meet the new layout → `zharness update` from the new binary is the only path, release notes say so.
- recovery: each task is its own commit; revert that commit. p3 recovery: TTDVKH and Mono are git repos — `git checkout -- .` and `git clean` the `.harness/` folder restores them before commit; the lean-eval tag keeps the removed history.
- seams: AGENTS.md gate commands; `cli/tests/projection_parity.rs`, `cli/tests/skill_reference_resolution.rs`; `cli/src/installer` update path (`zharness update`); `scripts/test-install-zharness.sh`; `setup/install.sh` (setup/ later moved to monoclaudian).
- phase_slug: `p1-tidy`
  status: done
  - goal: R1, R2, R3, R4, R5 | depends_on: none
  - surfaces: `docs/evals`, `scripts/`, `rules/`, `setup/` (setup/ later moved to monoclaudian), `docs/{templates,patterns,workflow-harness}`, `docs/prompt-engineering-principles.md`, `assets/`, `site/assets`, `.github/workflows`, `.claimignore`, AGENTS.md, README.md, CONTRIBUTING.md, `site/docs/*.html`, skill references naming moved paths | avoided: `docs/WORKFLOW.md`, `docs/PROJECT.md`, `docs/plans/`, `cli/src`, `skills/` paths, `scripts/install-zharness.sh`
  - escalate_when: a moved file is referenced by something outside this repo besides the installed git hook; or a gate fails for a reason not caused by a path change.
  - wave 1:
    - T1 Tag `archive/lean-eval-v1` at HEAD, then remove `docs/evals/` and the lean scripts named in R1, and fix references (owner: main agent, writes the removed paths, `.claimignore`, docs that link them only) — output: lean-eval gone, tag local — check: `git rev-parse archive/lean-eval-v1 && git ls-tree -r --name-only archive/lean-eval-v1 | grep -q docs/evals/evidence && test ! -e docs/evals && bash scripts/verify-doc-links.sh` — stop_if: a non-lean script or skill still needs a removed file
  - wave 2:
    - T2 Move gate scripts to `scripts/ci/`, `plan-slice.sh` and `record-check.sh` to `scripts/workflow/`; update CI, AGENTS.md, skills, CONTRACT.md and other references (owner: main agent, writes `scripts/**` except `install-zharness.sh`, `.github/workflows`, referencing docs/skills only) — output: R2 tree — check: `bash scripts/ci/test-guards.sh && bash scripts/ci/test-install-zharness.sh && bash scripts/ci/verify-doc-links.sh && (cd cli && cargo test)` — stop_if: a skill reference test pins the old path in a way that needs a CLI change
  - wave 3:
    - T3 Move `rules/`, `install-git-hooks.sh`, `statusline.py`, `setup-*.sh` into `setup/` (setup/ later moved to monoclaudian) (`statusline/` subfolder for the statusline files); fix `setup/install.sh`, AGENTS.md, README; reinstall the git hook (owner: main agent, writes `setup/**`, `rules/`, those scripts, referencing docs only) — output: R3 tree — check: `HOME=$(mktemp -d) bash setup/install.sh` (setup/ later moved to monoclaudian) installs `.claude/rules/english.md`; `bash setup/install-git-hooks.sh --force && bash scripts/ci/test-guards.sh` (now `scripts/install-git-hooks.sh`) — stop_if: `setup/install.sh` writes outside the temp HOME
  - wave 4:
    - T4 Create `docs/guides/` from `prompt-engineering-principles.md`, `patterns/`, `templates/`, `workflow-harness/`; fix links (owner: main agent, writes `docs/**` except WORKFLOW/PROJECT/plans, referencing files) — output: R4 tree — check: `ls docs` matches R4 and `bash scripts/ci/verify-doc-links.sh`
    - T5 Move `assets/diagrams/*` (PNG + `.tldraw`) and `assets/*` into `site/assets/`, drop duplicate PNGs, fix README and site image paths (owner: main agent, writes `assets/`, `site/assets/`, README, `site/**/*.html` image refs only) — output: R5 tree — check: `test ! -e assets && bash scripts/ci/verify-doc-links.sh`
  - phase check: `cd cli && cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test && cd .. && bash scripts/ci/test-guards.sh && bash scripts/ci/test-install-zharness.sh && bash scripts/ci/verify-doc-links.sh && test ! -e rules && test ! -e assets && test ! -e docs/evals`
- phase_slug: `p2-harness-paths`
  status: done
  - goal: R6, R7 | depends_on: p1-tidy
  - surfaces: `cli/src/installer/**`, `cli/src/embedded.rs`, `cli/docs/**` (CONTRACT, embedded WORKFLOW and templates), `cli/tests/**`, `cli/Cargo.toml`, stage skill references, plan guards in the pre-commit hook and `scripts/ci/test-guards.sh`, AGENTS.md, README, CHANGELOG, this repo's own `docs/WORKFLOW.md`, `docs/PROJECT.md`, `docs/plans/` | avoided: skill directory paths, `scripts/install-zharness.sh`
  - escalate_when: the migration cannot keep plan bytes identical; or the CLI size gate (1,850,000 bytes) fails.
  - scope (owner, 2026-10-23): hard switch — skills, guards and docs name only `.harness/`, with no fallback wording; release notes order the steps as install the binary → `zharness update` → reinstall hook → refresh skills. Plan guards check the new path only. Version 0.31.0 marked BREAKING. Fix `docs/**` references (incl. `docs/memory`); leave `site/**` (NG4).
  - spec:
    - S1 Path constants: `WORKFLOW_TARGET`, `PROJECT_TARGET` (`cli/src/installer/mod.rs`), `ACTIVE_PLANS_DIR` (`migrate.rs`) and the active-plan scan in `mod.rs` read `.harness/…`; embedded contracts in `cli/src/embedded.rs` pin `.harness/plans/{active,completed}/{slug}.md`.
    - S2 Layout migration runs inside `zharness update` before the existing 9→5 plan migration: for each of `docs/WORKFLOW.md`, `docs/PROJECT.md`, `docs/plans/**` that exists and whose `.harness/` target does not, rename it; then remove `docs/plans` if empty. If source and target both exist → stop with an error naming both (never overwrite). `update --check` reports an old-layout repo as stale, not current.
    - S3 Idempotent: a second `update` performs zero writes; plan bytes are identical before and after the move (`fs::rename`, no rewrite).
    - S4 The AGENTS.md managed block and the embedded router (`cli/docs/embedded/WORKFLOW.md` ↔ `docs/WORKFLOW.md` mirror) name `.harness/`.
    - S5 Gates follow the move: `cli-ci.yml` path filters and the completed-plan job (line 157), `verify-doc-links.sh`'s plan-folder exclusion, the pre-commit plan guards in `setup/install-git-hooks.sh` (now `scripts/install-git-hooks.sh`) and their fixtures in `scripts/ci/test-guards.sh` use `.harness/plans`; `.claimignore` entries citing pruned completed plans keep their `git show` paths (they name history).
  - wave 1:
    - T1 Red first: add an integration test with an old-layout fixture (WORKFLOW, PROJECT, active + completed plans, AGENTS.md block) asserting `zharness update` yields `.harness/` paths, byte-identical plans, refreshed block, and a no-op second run; then implement the migration and switch the CLI constants to `.harness/` (owner: main agent, writes `cli/src/installer/**`, `cli/tests/**`) — output: R7 test green — check: `cd cli && cargo test` — stop_if: the test passes before the implementation exists
  - wave 2:
    - T2 Point the embedded router, CONTRACT.md, templates, stage skills, plan guards, AGENTS.md and README at `.harness/` (owner: main agent, writes those files only) — output: no stale managed-path references — check: `cd cli && cargo test --test projection_parity --test skill_reference_resolution && cd .. && bash scripts/ci/test-guards.sh && git grep -nE 'docs/(WORKFLOW|PROJECT)\.md|docs/plans/' -- ':!CHANGELOG.md' ':!docs/decisions' ':!docs/research' ':!.harness/plans/completed'` returns only migration code and its tests
  - wave 3:
    - T3 Run the new binary's `update` on this repo (moves its own plan files), bump the CLI version, add a BREAKING CHANGELOG entry (owner: main agent, writes `.harness/**`, `docs/` removals, `cli/Cargo.toml`, `cli/Cargo.lock`, CHANGELOG) — output: this repo on the new layout — check: `cargo run --manifest-path cli/Cargo.toml -- update --check` prints current; CHANGELOG has `BREAKING`
  - phase check: `cd cli && cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test && cargo build --release --target x86_64-unknown-linux-musl && test "$(wc -c < target/x86_64-unknown-linux-musl/release/zharness)" -le 1850000 && cd .. && bash scripts/ci/test-guards.sh && bash scripts/ci/verify-doc-links.sh`
- phase_slug: `p3-rollout`
  status: done
  - goal: R8 | depends_on: p2-harness-paths
  - surfaces: the published release, `~/.local/bin/zharness`, TTDVKH and Mono working trees | avoided: those repos' product code
  - escalate_when: always before pushing the release tag, and before committing in TTDVKH or Mono (owner repos).
  - wave 1:
    - T1 Owner merges the PR and pushes the `cli/vX.Y.Z` tag; install it with `bash scripts/install-zharness.sh`; run `zharness update` in TTDVKH and Mono (owner: owner for tag/merge, main agent for install/update) — output: three repos on `.harness/` — check: `zharness update --check --all` prints `current` for all three
  - phase check: `zharness --version` shows the new release and `zharness update --check --all` prints `current` three times

## Log
- 2026-10-23T03:36:17Z — p1-tidy — decision — Log reconciled after the fact: T1–T5 landed as 55dc61e, 0ecb241, 5d738ed, 7340230, e069038 (rebased onto master 3ed429f); the plan file was untracked, so no entries were written then.
- 2026-10-23T03:39:21Z — p2-harness-paths/T1 — decision — The migration test is a lib test (`src/installer/layout_tests.rs`), not `cli/tests/`: the fixture helpers (`test_support`) are crate-private. Uninstall leaving `.zharness/base/{original,ownership.tsv}` is pre-existing (same on released 0.29.0), not in scope.
- 2026-10-23T03:40:42Z — p2-harness-paths/T2 — decision — `verify-doc-links.sh` reports 8 broken links, all in this repo's `docs/plans/completed/` (no longer skipped now that the exclusion is `.harness/plans/*`). T3 moves them, so the doc-link check runs at the T3 / phase check. `projection_parity` still reads `../docs/WORKFLOW.md`; it changes in T3 along with this repo's own move. Kept intentionally: the historical `migration.md` (0.14 harness) and `.claimignore` entries pointing at `git show` history.
- 2026-10-23T03:42:17Z — p2-harness-paths/T3 — decision — Doc links: `.harness` added to the scan roots (the live router and PROJECT were otherwise unchecked; `.harness/plans/*` stays excluded). Frozen ADRs/research cite `docs/WORKFLOW.md`, `docs/PROJECT.md`, `docs/plans/completed/` → three `.claimignore` entries with reasons, matching how prior moves were handled. `update` output lines now read `moved  docs/X -> .harness/X`. The `KEPT docs/playbooks/*` notices during this repo's update are pre-existing retirement records in its own `.zharness` (retirement code untouched).
- 2026-10-23T03:44:44Z — p2-harness-paths — blocked — independent gate CHANGES_REQUESTED: `test-guards.sh` 71/3. `verify-doc-links.sh` added `.harness` to the `find` roots, so `find` exits 1 in any tree without `.harness` (TRIP fixture, consumers). failure_class: BAD_OUTPUT. Correction: the T3 `done` entry's "guards 74/0" was measured before that script edit, so it did not cover the edited script.
- 2026-10-23T03:44:44Z — p2-harness-paths — decision — Fix: scan `.harness` only when it exists. After the fix, `test-guards.sh` → 74/0 and `verify-doc-links.sh` → 0 findings. Gate finding 2 (untracked `.harness/`) is a commit-time action: the phase commit stages `.harness/` together with the `docs/` deletions. Tested source: HEAD e069038 + diff sha256 e20d57e709ad.
- 2026-10-23T03:58:00Z — p2-harness-paths — blocked — first commit attempt rejected by the reinstalled pre-commit hook: (1) the Validation entry cited no backticked proof commands; (2) `zharness_guard_old_blob` found no predecessor for plans renamed `docs/plans/` → `.harness/plans/`, so every historical entry in `completed/` re-ran against pre-restructure script paths. failure_class: BAD_OUTPUT. (2) hits every consumer committing the move.
- 2026-10-23T03:58:00Z — p2-harness-paths — decision — Fix: Validation entry lists its proof commands; `old_blob` also tries `docs/plans/<same subpath>` (and `docs/plans/active/<name>` for completed). New guard case S6b; `bash scripts/ci/test-guards.sh` → 76/0; mutation (drop the `docs/plans` fallback) → S6b fails. Post-gate change limited to the hook fallback and its test.
- 2026-10-23T05:00:00Z — p3-rollout — decision — absorb: guard scripts/ci/test-guards.sh (S6b pins the `docs/plans` → `.harness/plans` old-blob fallback; R6/R7 migration is pinned by `cli/src/installer/layout_tests.rs`).

## Validation
- 2026-10-23T03:45:14Z — phase `p2-harness-paths` — verdict: APPROVED — mode: gate
  - `cd cli && cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test` — exit 0; 88 pass, 0 fail
  - `cd cli && cargo build --release --target x86_64-unknown-linux-musl && test "$(wc -c < target/x86_64-unknown-linux-musl/release/zharness)" -le 1850000` — exit 0; 819920 bytes
  - `bash scripts/ci/test-guards.sh` — exit 0; 74/0 at the gate, 76/0 after the commit-time guard fix (Log)
  - `bash scripts/ci/verify-doc-links.sh` — exit 0; 0 findings
  - R6 residual grep, R7 temp-repo probes (old layout, dual copy, partial, unrelated docs/ files kept) — ok
  - judge: independent (first pass CHANGES_REQUESTED, a doc-link `find` on a missing `.harness`; fixed and re-run)
  - tested source: HEAD e069038 + tracked diff sha256 e20d57e709ad; `.harness/` untracked, must be staged with the `docs/` deletions
- 2026-10-23T05:00:00Z — phase `p3-rollout` — verdict: APPROVED — mode: full
  - `grep -q '^version = "0.31.0"' cli/Cargo.toml` — exit 0
  - `test -f .harness/WORKFLOW.md && test ! -e docs/WORKFLOW.md` — exit 0
  - machine-local, observed by the judge, not re-executable in CI: zharness --version → 0.31.0; zharness update --check --all → current for mono-harness, TTDVKH, Mono; gh release view cli/v0.31.0 → published; TTDVKH and Mono have .harness/WORKFLOW.md and no docs/WORKFLOW.md
  - judge: independent
  - tested source: master d146824


## Current State and Next Action
- active_phase: none
- lifecycle_status: completed
- blockers: none
- open_items: none
- exact_next_action: none — initiative complete; owner commits the `.harness/` move in TTDVKH and Mono
