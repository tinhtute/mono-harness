---
status: active
lane: high-risk
---
# Split Claude Code setup into monoclaudian

## Goal
- outcome: this repository (monoharness) holds only the portable harness — skills, `zharness` CLI, `.harness/` protocol, docs, non-RSI evals, site, harness CI and harness agents. Claude Code–specific setup (CLAUDE.md, rules, settings, models policy for its agents, mods, statusline, installer, `test-runner` agent) lives in a new repository `monoclaudian` with its `setup/` history preserved and its own CI. The RSI eval suite is removed. Breaking change: no compatibility shims.
- success_signal: on monoharness master, `git ls-files setup evals/rsi` is empty, `grep -rniE "setup/|evals/rsi|\bRSI\b" --exclude-dir={target,.git,.claude} .` returns no hit outside CHANGELOG history entries, and all five AGENTS.md gate commands pass; in `../monoclaudian`, `git log --oneline -- mods | wc -l` > 0 and its CI-equivalent commands (mod tests, agent-model check) pass locally.
- actors: owner (sole maintainer and installer on own machines); coding agents reading AGENTS.md; `npx skills add` consumers of monoharness.
- authority: owner decisions 2026-11-06 in session: repo A named `monoclaudian`; drop RSI entirely, redo later from harness; CI moves with its owner repo, removing CI in both accepted; breaking change; harness agents renamed `mono-lead`/`mono-worker`/`mono-verifier` and installed by a monoharness script; `test-runner` stays Claude Code side; each repo keeps its own models.json + agent-model test; `install-git-hooks.sh` moves to `scripts/`; old ADRs/completed plans/research are rewritten to new paths, not left as history; ninja-kit keeps hardcoded `.harness/plans/active`, documented in monoclaudian README; GitHub repo creation is a separate approval.
- requirements:
  - R1: tag `baseline/pre-split` on current master before any history rewrite. | acceptance: `git rev-parse baseline/pre-split` equals pre-split master SHA and the tag is pushed | source: memory cited-shas-need-merge-commit-or-tag
  - R2: create local `../monoclaudian` from `setup/` via `git filter-repo --subdirectory-filter setup` on a fresh clone, minus `install-git-hooks.sh` and the three harness agents. | acceptance: `cd ../monoclaudian && git log --oneline | wc -l` > 1; `ls` shows CLAUDE.md, rules, settings.json, models.json, mods, statusline, install.sh, agents/test-runner.md and no install-git-hooks.sh, lead/worker/verifier | source: owner
  - R3: monoclaudian has its own CI: mod tests (ninja-kit, cache-guard under bun) and an agent-model check covering only `test-runner`. | acceptance: monoclaudian `.github/workflows/ci.yml` exists and its commands pass locally | source: owner "CI follows owning repo"
  - R4: monoclaudian README documents that ninja-kit's footer reads `.harness/plans/active` (zharness layout) and that harness skills/agents come from monoharness. | acceptance: `grep -n ".harness/plans/active" ../monoclaudian/README.md` hits | source: owner
  - R5: remove `evals/rsi/` and every live RSI reference in monoharness. | acceptance: success_signal grep for `evals/rsi|\bRSI\b` | source: owner
  - R6: harness agents live at `agents/mono-lead.md`, `agents/mono-worker.md`, `agents/mono-verifier.md` with renamed `name:`, a monoharness `models.json` + `scripts/ci/test-agent-models.sh` for them, and `scripts/install-agents.sh` that copies them to `~/.claude/agents/`. | acceptance: `bash scripts/ci/test-agent-models.sh` prints `agent models OK (3 agents)`; install script into a temp `CLAUDE_DIR` yields 3 files | source: owner
  - R7: fanout playbook and every live reference use the `mono-*` agent names. | acceptance: `grep -rnwE "lead|worker|verifier" skills/mono/playbooks/fanout.md` reviewed; `grep -rn "subagent_type.*\b(lead|worker|verifier)\b"` empty | source: owner
  - R8: `setup/install-git-hooks.sh` moves to `scripts/install-git-hooks.sh`; AGENTS.md, CI (`hook-guard`), `scripts/ci/test-guards.sh` and memory note updated. | acceptance: `bash scripts/ci/test-guards.sh` passes; `bash scripts/install-git-hooks.sh --force` succeeds | source: owner
  - R9: monoharness `setup/` and all setup-owned CI triggers/jobs (mods, agent-models on setup paths) removed. | acceptance: `git ls-files setup` empty; `grep -n "setup/" .github/workflows/*.yml` empty | source: owner
  - R10: all docs — live and historical (ADRs, completed plans, research, site, CHANGELOG upcoming entry) — rewritten to new paths or to `monoclaudian`. | acceptance: `bash scripts/ci/verify-doc-links.sh` passes with no new `.claimignore` entries; success_signal grep | source: owner "Sửa hết"
  - R11: all AGENTS.md gate commands pass on monoharness. | acceptance: the five Gate Commands exit 0 | source: AGENTS.md
- non-goals:
  - NG1: no GitHub repo creation, push of monoclaudian, or rewrite of monoharness history without separate owner approval.
  - NG2: no new RSI or replacement eval suite.
  - NG3: no change to `zharness` CLI behavior or scope (agents are not installed by the CLI).
  - NG4: no ninja-kit path configurability.
  - NG5: no edits to reference repos (onedrive-cloud, harness-experimental, codesight).

## Phases and Verification
- approach: extract first, then shrink. Tag master and build `../monoclaudian` from a fresh clone at the tag (history intact, independent of later edits), then remove RSI, then rehome harness-owned pieces out of `setup/` and delete it, then rewrite docs and run every gate. One branch `split/monoclaudian`, one PR, one commit per phase. Rejected: monorepo with two packages (keeps cross-CI coupling the owner wants gone); filter-repo on this working clone (destroys local history).
- risks: filter-repo on the wrong clone rewrites monoharness → run only inside a fresh `git clone --no-local` under `../monoclaudian`, check `pwd` first; stop if the path is this repo. Renaming agent words in prose breaks pinned text in `cli/src/embedded.rs` (e.g. line 368 "worker" is generic prose) → rename only agent identifiers (spawn names, `subagent_type`, file names); run `cargo test` after each skill reference edit. Doc rewrite breaks link gate → `verify-doc-links.sh` per phase. Recovery: `git reset --hard baseline/pre-split` on the branch; `trash ../monoclaudian` and re-extract.
- seams: `scripts/ci/test-agent-models.sh`, `scripts/ci/test-guards.sh`, `scripts/ci/verify-doc-links.sh`, `scripts/ci/validate-skills.sh`, `cd cli && cargo test` (embedded contracts, projection parity), bun mod tests in `mods/*`, new `scripts/install-agents.sh` (`CLAUDE_DIR` override).
- constraints: no push, no GitHub repo creation, no `gh` writes without owner approval (NG1); deletes via `trash`; `scripts/ci/**`, `.github/**`, `setup/install-git-hooks.sh` are always-review paths → PR is never auto-merged; reinstall hooks with `bash scripts/install-git-hooks.sh --force` after the move.
- recovery: tag `baseline/pre-split` is the restore point for both repos; plan Log records each phase commit SHA.
- phase_slug: `extract`
  status: checked
  - goal: R1, R2, R3, R4 | depends_on: none
  - surfaces: git tag `baseline/pre-split`; new `../monoclaudian/**` | avoided: every file in this repo
  - escalate_when: `../monoclaudian` already exists; filter-repo leaves no history for `mods`; mod tests fail at baseline.
  - wave 1:
    - T1 tag `baseline/pre-split` at master HEAD (owner: lead, writes tag only) — output: local tag; push deferred to owner approval — check: `git rev-parse baseline/pre-split` == `git rev-parse master` — stop_if: working tree dirty
  - wave 2:
    - T2 `git clone --no-local . ../monoclaudian && cd ../monoclaudian && git checkout -B master baseline/pre-split && git filter-repo --subdirectory-filter setup --force`, then `trash install-git-hooks.sh agents/lead.md agents/worker.md agents/verifier.md`, drop their rows from `models.json`, remove the `origin` remote (owner: lead, writes ../monoclaudian only) — output: repo rooted at former setup/ — check: `git -C ../monoclaudian log --oneline -- mods | wc -l` > 0 and `ls ../monoclaudian/agents` == `test-runner.md` — stop_if: `pwd` resolves to this repo during filter-repo
  - wave 3:
    - T3 add `scripts/test-agent-models.sh` (copied, paths re-rooted) and `.github/workflows/ci.yml` with jobs `mods` (bun test in mods/ninja-kit, mods/cache-guard as in cli-ci.yml) and `agent-models` (owner: worker, writes ../monoclaudian/{scripts,.github}) — output: self-contained CI — check: `cd ../monoclaudian && bash scripts/test-agent-models.sh && (cd mods/ninja-kit && bun test) && (cd mods/cache-guard && bun test)` — stop_if: a test needs a path outside the repo
    - T4 rewrite `../monoclaudian/README.md`: what it is, install, ninja-kit reads `.harness/plans/active` (zharness layout), harness skills/agents come from monoharness (`npx skills add`, `scripts/install-agents.sh`); fix `install.sh` paths (no `setup/` prefix, no agents it no longer has) (owner: worker, writes README.md, install.sh) — output: accurate docs — check: `grep -n ".harness/plans/active" ../monoclaudian/README.md && ! grep -rn "setup/\|install-git-hooks\|\bRSI\b" ../monoclaudian --exclude-dir=.git` — stop_if: none
  - phase check: `cd ../monoclaudian && bash scripts/test-agent-models.sh && (cd mods/ninja-kit && bun test) && (cd mods/cache-guard && bun test) && git log --oneline | wc -l` (> 1), then commit in monoclaudian
- phase_slug: `drop-rsi`
  status: checked
  - goal: R5 | depends_on: extract
  - surfaces: `evals/rsi/`, `.github/workflows/*` RSI jobs, RSI mentions in setup/mods plugin.json and live docs | avoided: evals/01–08, historical docs (phase docs)
  - escalate_when: a non-RSI eval or CI job imports from `evals/rsi`.
  - wave 1:
    - T5 `trash evals/rsi` on branch `split/monoclaudian`; remove RSI jobs/paths in workflows and RSI lines in README.md, AGENTS.md, evals/*/graders (owner: worker, writes those files only) — output: no RSI code — check: `git ls-files evals/rsi | wc -l` == 0 and `grep -rnE "evals/rsi|\bRSI\b" .github README.md AGENTS.md evals` empty — stop_if: escalate condition
  - phase check: `bash scripts/ci/verify-doc-links.sh && bash scripts/ci/test-guards.sh`
- phase_slug: `rehome`
  status: checked
  - goal: R6, R7, R8, R9 | depends_on: drop-rsi
  - surfaces: `agents/`, `models.json`, `scripts/install-agents.sh`, `scripts/install-git-hooks.sh`, `scripts/ci/test-agent-models.sh`, `scripts/ci/test-guards.sh`, `.github/workflows/cli-ci.yml`, skills naming agents (fanout.md, work-fanout.md, work-full.md, check-durable.md), AGENTS.md, `.harness/PROJECT.md`, `cli/docs/CONTRACT.md` | avoided: `cli/src/**` behavior, generic "worker/lead" prose
  - escalate_when: `cargo test` pins an agent name that must change in `cli/src/embedded.rs` (always-review path); a skill reference needs a new companion file.
  - wave 1:
    - T6 `git mv setup/install-git-hooks.sh scripts/install-git-hooks.sh`; update `test-guards.sh`, cli-ci `hook-guard` job and its paths, AGENTS.md, CONTRACT.md, PROJECT.md, CONTRIBUTING.md (owner: lead, writes those files) — output: guards installed from scripts/ — check: `bash scripts/ci/test-guards.sh && bash scripts/install-git-hooks.sh --force` — stop_if: guard fixtures fail
    - T7 `git mv setup/agents/{lead,worker,verifier}.md agents/mono-{lead,worker,verifier}.md` with `name:` renamed; root `models.json` with only those 3 rows (`readOnly: ["mono-verifier"]`); repoint `scripts/ci/test-agent-models.sh` to root paths; add `scripts/install-agents.sh` (copies `agents/*.md` to `${CLAUDE_DIR:-$HOME/.claude}/agents/`, backs up existing) (owner: lead, writes those files) — output: harness agents owned here — check: `bash scripts/ci/test-agent-models.sh | grep "OK (3 agents)" && D=$(mktemp -d) && CLAUDE_DIR=$D bash scripts/install-agents.sh && ls $D/agents | wc -l` == 3 — stop_if: none
  - wave 2:
    - T8 rename agent identifiers in skills (fanout.md, work-fanout.md, work-full.md, check-durable.md and any `subagent_type`) to `mono-*` (owner: lead, writes skills/** only) — output: spawn names match files — check: `cd cli && cargo test && cd .. && bash scripts/ci/validate-skills.sh` — stop_if: escalate condition
    - T9 `trash setup` (remaining: CLAUDE.md, rules, settings, models.json, mods, statusline, install.sh, README, test-runner) after confirming each exists in ../monoclaudian; drop `setup/**` triggers and the `mods`/old `agent-models` setup paths from cli-ci.yml, keep agent-models job on new paths (owner: lead, writes setup/, .github/workflows/cli-ci.yml) — output: no setup/ — check: `git ls-files setup | wc -l` == 0 and `! grep -n "setup/" .github/workflows/*.yml` — stop_if: a setup file is missing from ../monoclaudian
  - phase check: `bash scripts/ci/test-guards.sh && bash scripts/ci/test-agent-models.sh && cd cli && cargo test`
- phase_slug: `docs`
  status: checked
  - goal: R10, R11 | depends_on: rehome
  - surfaces: README.md, CHANGELOG.md (Unreleased breaking entry), docs/** (ADRs, guides, research), `.harness/plans/completed/**`, site/**, memory note `install-git-hooks-needs-force` | avoided: code
  - escalate_when: a historical doc's claim becomes false (not just a path) after rewrite.
  - wave 1:
    - T10 rewrite every `setup/...` reference to `scripts/...`, `agents/mono-*`, or `monoclaudian` (+ path), and remove/reword RSI mentions, across docs, completed plans, site; add CHANGELOG breaking entry (owner: worker, writes docs/**, .harness/plans/completed/**, site/**, README.md, CHANGELOG.md) — output: no stale refs — check: `grep -rniE "setup/|evals/rsi|\bRSI\b" --exclude-dir={target,.git,.claude} . | grep -v "^./CHANGELOG.md"` empty (CHANGELOG past releases only) and `git diff --stat .claimignore` empty — stop_if: escalate condition
  - phase check: all five AGENTS.md Gate Commands (fmt/clippy/test, musl size, test-guards, verify-doc-links, validate-skills) exit 0; independent `check full` judge on a different model family.

## Log
- 2026-11-06 decision (owner): lift NG1 — create public github.com/tinhtute/monoclaudian, commit, push, open PR; fan out agents.
- 2026-11-06 T1 (lead): tag `baseline/pre-split` = 75d591c, pushed.
- 2026-11-06 wave 1 spawned: extract T2–T4 lead (opus) in ../monoclaudian; drop-rsi + rehome T5–T8 lead (opus) in worktree `split/rehome`.
- 2026-11-06 extract done: monoclaudian master 8f605a8 (ef5c728, 6ad82e8, 8f605a8); deviation accepted: mod CI runs `bun test hooks/rules.spec.ts` (other tests need the private claude-code/testing kit, as in old cli-ci). Pushed; monoclaudian CI run 42223068309 green.
- 2026-11-06 drop-rsi/rehome done on `split/rehome` (aa7100d, ca63bf2, 4fde7cb, 0b18161), fast-forwarded into split/monoclaudian; hooks reinstalled with `--force`.
- 2026-11-06 T9 (lead): a0a7706 setup/ removed after every file confirmed in monoclaudian; mod-tests job and setup triggers dropped.
- 2026-11-06 T10 worker (sonnet): c73c1c9; deviations accepted: embedded.rs legacy-path test, verify-doc-links roots, AGENTS.md always-review list; rsi-prompt-surface completed plan trashed per owner "drop RSI" (recover: `git show baseline/pre-split:.harness/plans/completed/rsi-prompt-surface.md`).
- 2026-11-06 check full (verifier, claude-fable-5-1, independent): REQUEST_CHANGES — site install command broken, history rewrites falsified claims, CHANGELOG contradiction, legacy agents not retired, wording, doc-link prefix, test scope.
- 2026-11-06 fixes (lead, opus): b624eba; history restored from baseline with "(now …)/(later moved…)" notes; install-agents retires legacy agents, CI-tested.
- 2026-11-06 re-check (verifier, claude-fable-5-1, independent): APPROVE_WITH_REQUESTS — AGENTS.md monoclaudian wording, CHANGELOG unreleased-rsi line, README "private", site SSH URL: fixed by lead in final commit.
- 2026-11-06 decision (lead): success_signal and T10 grep amended — truthful historical mentions in `.harness/plans/completed`, `docs/decisions`, `docs/research` and CHANGELOG are allowed; live files must be clean.

## Validation
- 2026-11-06 independent judge claude-fable-5-1 — APPROVE_WITH_REQUESTS; requests applied. Gates on split/monoclaudian: `bash scripts/ci/verify-doc-links.sh` 0 findings; `bash scripts/ci/test-guards.sh` 106/0; `bash scripts/ci/test-agent-models.sh` OK (3 agents); `bash scripts/ci/validate-skills.sh` 22 valid; `cd cli && cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test` pass; musl size gate not runnable on macOS (linker; fails identically on baseline) → CI `size-gate`. monoclaudian: test-agent-models OK (1), bun rules.spec 9/0 + 5/0, GitHub CI green.

## Current State and Next Action
- active_phase: docs
- lifecycle_status: checked
- blockers: none
- open_items: none
- exact_next_action: merge PR after green CI, then handoff and move plan to completed
