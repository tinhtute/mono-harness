---
status: completed
lane: normal
---
# Verification wins: close the audit's quick gaps

## Goal
- outcome: The quick wins and small scripts from the 2026-10-30 verification audit land: no stale hook references, mechanical risk facts and benchmark stats come from scripts, and skill scripts have fixture tests in CI.
- success_signal: each requirement's acceptance command passes; `bash scripts/ci/validate-skills.sh`, `bash scripts/ci/verify-doc-links.sh`, `bash scripts/ci/test-guards.sh` and `cd cli && cargo test` pass on the combined tree.
- actors: the owner (ní); the lead agent; fanout workers.
- authority: audit `docs/research/2026-10-30-verification-audit.md` (PR #186) § B gaps 3–5 and § D quick wins; owner decisions 2026-11-02: git attribution defers to host, remove stale `setup/hooks` refs and the `$CLAUDE_LAST_MESSAGE` Stop hook, work on a new branch off `master`.
- requirements:
  - R1: dropped — premise wrong. `scripts/ci/validate-skill.sh:13` sets `pipefail`, so the `pytest | grep -q passed` pipeline at :247 already fails when pytest exits non-zero (repro 2026-11-02: a skill with "1 failed, 1 passed" → `❌ Tests failed`). No change. | acceptance: none | source: audit B5
  - R2: `skills/tools/git/SKILL.md` no longer forbids attribution; it adds none of its own and uses the host's or the user's attribution lines when given. | acceptance: `grep -c "Never include AI attribution" skills/tools/git/SKILL.md` = 0; `bash scripts/ci/validate-skill.sh skills/tools/git/SKILL.md` passes | source: owner decision, `skills/tools/git/SKILL.md:64`
  - R3: the plan file `create-cli` writes uses the lock skeleton frontmatter (`status: active`, a `lane:`). | acceptance: `grep -A3 '^---' skills/extras/create-cli/SKILL.md` around :120-127 shows `status: active` and `lane:`; no `status: draft` left | source: audit A, `skills/extras/create-cli/SKILL.md:124`
  - R4: `skills/mono/playbooks/babysit.md` step 5 names `gh run view <run-id> --log-failed` for reading CI logs. | acceptance: `grep -c "log-failed" skills/mono/playbooks/babysit.md` ≥ 1 | source: audit D
  - R5: `AGENTS.md` has an `## Exercise` section with a runnable recipe for `zharness`. | acceptance: the recipe's commands run green in a temp git repo (install then uninstall leaves no managed files) | source: audit B2, `skills/stages/check/references/check-exercise.md:9`
  - R6: no repo file points at the missing `setup/hooks/`; the `$CLAUDE_LAST_MESSAGE` Stop hook is gone from `setup/settings.json`. | acceptance: `git grep -n "setup/hooks" -- ':!docs/research' ':!.harness/plans' ':!scripts/ci/test-guards.sh'` empty (the guard test's synthetic AGENTS.md fixture is not a reference); `grep -c CLAUDE_LAST_MESSAGE setup/settings.json` = 0; `jq . setup/settings.json` valid | source: owner decision, audit E
  - R7: `scripts/ci/test-skill-scripts.sh` runs one hit and one miss fixture per skill script, starting with `scan-staged.sh`, and `skills-ci.yml` runs it. | acceptance: `bash scripts/ci/test-skill-scripts.sh` exits 0; breaking `scan-staged.sh`'s regex makes it exit non-zero | source: audit B5
  - R8: `skills/stages/check/scripts/risk-facts.sh <base> <sha>` prints JSON `{counted_lines, excluded_lines, excluded_paths[], always_review_hits[], test_changes:{removed_files[], skip_markers_added[]}, ci_config_touched}`, reading always-review paths from `git show <base>:AGENTS.md`; `check-risk.md` § Checks tells the judge to run it. | acceptance: fixture repo: a 500-line code diff → `counted_lines` > 400; a docs-only diff → `counted_lines` 0; touching `.github/x.yml` → listed in `always_review_hits` and `ci_config_touched: true`; `cd cli && cargo test` passes | source: audit B3
  - R9: `skills/mono/scripts/bench.sh -n N [--warmup W] -- CMD` prints JSON `{n, median_ms, p90_ms, stdev_ms, min_ms}` and exits non-zero if any run fails; `perf.md` step 1 points at it. | acceptance: `bench.sh -n 5 -- sleep 0.05` → `median_ms` between 40 and 200; `bench.sh -n 3 -- false` → rc≠0 | source: audit B4
- non-goals:
  - NG1: No `zharness` subcommand or `zverify` (AGENTS.md § Harness keeps zharness install-only; needs an ADR first).
  - NG2: No exercise driver, eval runner, or stop-gate check (audit wave 3).
  - NG3: No change to the pre-commit hook body.

## Phases and Verification
- approach: One phase, partitioned by write set for a fanout; shared files (`AGENTS.md`, `setup/settings.json`, `validate-skill.sh`) stay with the lead. Rejected: one sequential pass — four disjoint slices run faster in parallel.
- phase_slug: `main`
  status: done
  - goal: R2, R3, R4, R5, R6, R7, R8, R9 | depends_on: none
  - surfaces: `scripts/ci/`, `.github/workflows/skills-ci.yml`, `skills/tools/git/SKILL.md`, `skills/extras/create-cli/SKILL.md`, `skills/mono/{playbooks,scripts}/`, `skills/stages/check/{scripts,references/check-risk.md}`, `AGENTS.md`, `setup/settings.json` | avoided: `cli/src/`, `setup/install-git-hooks.sh`
  - T0 lead: R5, R6 (writes `AGENTS.md`, `setup/settings.json`, `setup/install.sh`, `setup/README.md` only); lands before the wave
  - T1 worker A: R7 (writes `scripts/ci/test-skill-scripts.sh`, `scripts/ci/fixtures/skill-scripts/**`, `.github/workflows/skills-ci.yml` only)
  - T2 worker B: R2, R3, R4 (writes `skills/tools/git/SKILL.md`, `skills/extras/create-cli/SKILL.md`, `skills/mono/playbooks/babysit.md` only)
  - T3 lead C: R8 (writes `skills/stages/check/scripts/risk-facts.sh`, `skills/stages/check/references/check-risk.md`, its fixtures, and any `cli/tests` pin it needs only)
  - T4 worker D: R9 (writes `skills/mono/scripts/bench.sh`, `skills/mono/playbooks/perf.md` only)
  - phase check: `bash scripts/ci/validate-skills.sh && bash scripts/ci/verify-doc-links.sh && bash scripts/ci/test-guards.sh && bash scripts/ci/test-skill-scripts.sh && (cd cli && cargo test)`

## Log
- 2026-11-02 T0 done (lead, claude-opus-5-5, branch quaqua/verification-wins, uncommitted): R6 removed `setup/hooks` refs from `setup/settings.json:2`, `AGENTS.md` always-review list, `setup/install.sh` Step 4, and the `$CLAUDE_LAST_MESSAGE` Stop hook; R5 added `AGENTS.md` § Exercise, run green in a temp repo (install rc=0, uninstall rc=0, porcelain empty).
- 2026-11-02 wave spawned: T1 worker A (sonnet), T2 worker B (sonnet), T3 lead C (opus), T4 worker D (sonnet), each in its own worktree (base turned out to be `origin/master` `98ba582`, which contains `a3e1ff1`).
- 2026-11-02 T2 done (worker B, sonnet, branch worktree-agent-a9ddf72b215e92f4b, 3e8a53e): R2 git SKILL.md:64 defers to host attribution, v1.5.0; R3 create-cli frontmatter `status: active`/`lane: normal`, v1.1.0; R4 babysit step 5 names `gh run view <run-id> --log-failed`. Verified by lead: commit touches only the 3 scoped files; acceptance greps reported 0/none/1.
- 2026-11-02 T4 done (worker D, sonnet, branch worktree-agent-ae8de15d3c5a2d6a2, f37a8ad): R9 `skills/mono/scripts/bench.sh` + perf.md step 1 link. Re-run by lead: `-n 5 -- sleep 0.05` → median_ms 55.48 rc=0; `-n 3 -- false` → rc=1; no args → rc=2; commit touches only the 2 scoped files.
- 2026-11-02 T1 done (worker A, sonnet, branch worktree-agent-a32e9345041ebc88b, e8dcbfa): R7 `scripts/ci/test-skill-scripts.sh` (23 cases over scan-staged, group-staged, lint-prompt, gh-search, fetch, session-digest) + new `skill-scripts` job in skills-ci.yml. Re-run by lead: `23 passed, 0 failed`; worker's mutation run (AKIA alternative removed) → `21 passed, 2 failed`; commit touches only the 5 scoped files.
- 2026-11-02 T3 done (lead C, opus, branch worktree-agent-ab1ab50031ff9b36b, 2931c51): R8 `skills/stages/check/scripts/risk-facts.sh` + `scripts/ci/test-risk-facts.sh` + check-risk.md § Checks rewired. Re-run by lead: `passed: 15  failed: 0`; diff touches only the 3 scoped files.
- 2026-11-02 integrated (lead): applied 3e8a53e, f37a8ad, e8dcbfa, 2931c51 to the working tree of quaqua/verification-wins (uncommitted; owner has not asked for a commit); held file edit: `risk-facts` job + path filter in skills-ci.yml. Phase check green on the combined tree.
- 2026-11-02 check full (verifier-wins, claude-fable-5-1, independent): REQUEST_CHANGES — 3 blocking (R6 grep hit in a risk-facts fixture; stale hook docs in setup/README.md and install.sh; PR's own .gitattributes could exempt code from Size), 3 should-fix (only first Always-review line read; skip markers lost for quoted/space paths; *.spec.*, test/, spec/, __tests__/, *Test.java missed), lows.
- 2026-11-02 fixes (lead): risk-facts.sh reads linguist-generated from `<base>`, reads every Always-review line, diffs skip markers per path from `--numstat -z`, widens test patterns; 4 new fixtures fail on the pre-fix script (15 passed, 4 failed) and pass now; fixture glob `setup/hooks/**` → `scripts/ci/**`; setup/README.md hooks row, Stop-hook table and "required by hooks" removed; install.sh header, `~/.claude/hooks` mkdir and hook count removed; AGENTS.md § Exercise isolates `XDG_CONFIG_HOME`; T0 write set widened to setup/README.md; R2 acceptance path fixed.
- 2026-11-02 re-check (verifier-wins, claude-fable-5-1): APPROVE_WITH_REQUESTS — fixes #2 #3 #6 #7 #8 #9 #13 verified by its own repros; condition: stage the working copy (done, `git diff --quiet` rc=0, staged risk-facts.sh has `--source="$base"`).
- 2026-11-02 shipped: PR #187 merged to master at 50f8731 after all 9 CI checks passed; 4 worker worktrees and `worktree-agent-*` branches removed.
- 2026-11-02 handoff — decision — absorb: none (risk-facts.sh, bench.sh and the CI fixture jobs carry the lessons; open items stay listed below).

## Validation
- 2026-11-02 phase main, combined working tree: `bash scripts/ci/validate-skills.sh` → 22 skill(s) valid rc=0; `bash scripts/ci/verify-doc-links.sh` → 0 findings rc=0; `bash scripts/ci/test-guards.sh` → 104 passed, 0 failed rc=0; `bash scripts/ci/test-skill-scripts.sh` → 23 passed, 0 failed rc=0; `bash scripts/ci/test-risk-facts.sh` → 15 passed rc=0; `cd cli && cargo test` → 89 passed, 0 failed rc=0; `jq -e . setup/settings.json && bash -n setup/install.sh` rc=0.
- 2026-11-02 after verifier fixes: validate-skills 22 valid rc=0; verify-doc-links 0 findings rc=0; test-guards 104/0 rc=0; test-skill-scripts 23/0 rc=0; test-risk-facts 19/0 rc=0; `cd cli && cargo test` 84+3+2 passed, 0 failed; shellcheck risk-facts.sh + test-risk-facts.sh rc=0; R6 grep empty (rc=1); § Exercise recipe: install 0, uninstall 0, porcelain empty, real registry unchanged.

## Current State and Next Action
- active_phase: main
- lifecycle_status: completed
- blockers: none
- open_items: owner policy call — `*.md` always counts as docs for Size, so SKILL.md and cli/docs/embedded/*.md (shipped in the binary) count 0; bench.sh has no CI fixture and uses GNU `date +%s%N`; gh-search.sh/fetch.sh fixtures cover usage only; Always-review globs use bash `[[ == ]]` (`**/x/**` does not match a root `x/`), same as the hook; a PR-added `*.generated.*` file still exempts itself from Size (listed in excluded_paths; verifier non-blocking).
- exact_next_action: none; the open items above are follow-ups for a new plan if the owner wants them
