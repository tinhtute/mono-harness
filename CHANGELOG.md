# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [v0.32.0] — 2026-10-26

### Changed

- **BREAKING:** the entry router skill is `mono` (`skills/mono/`, `/mono <task>`),
  not `mono-mode`. Reinstall skills and remove any installed `mono-mode` copy.
- The managed `WORKFLOW.md` names `check.md` § Lane Matrix as the only source
  of lane → required proof, final check mode, and judge independence. Run
  `zharness update` to refresh it.
- `check`: the Lane Matrix is authoritative; normal plans no longer auto-run
  `full`, and the normal-lane gate has no manual review. `work-full` gates
  `stop_if` and `escalate_when` fail-closed.

### Added

- `check`: opt-in multi-model panel review (ADR 0018) with an executable merge
  step, `scripts/panel-merge.py`, and fixture tests in CI (#156).
- `read` and `learn` skills, plus `research`, `ship`, `babysit`, `fanout` and
  the other pstack playbooks in the `mono` router.
- Role agents (`lead`, `worker`, `verifier`, `test-runner`) pinned by
  `setup/models.json`.
- CI validates every tracked `SKILL.md` (#167).

### Fixed

- Secret-scan hook reads binary blobs in the C locale.

## [v0.31.0] — 2026-10-23

### Changed

- **BREAKING:** managed files move from `docs/` to `.harness/`:
  `.harness/WORKFLOW.md`, `.harness/PROJECT.md` and
  `.harness/plans/{active,completed}/`. `zharness update` renames the old
  paths in place, so plan bytes stay identical; it refuses when both the old
  and the new copy exist. Stage skills, the pre-commit plan guards and the
  AGENTS block name only the new paths. Upgrade in this order: install this
  binary, run `zharness update`, reinstall the git hook
  (`bash setup/install-git-hooks.sh --force`), then refresh skills.
- `zharness update --check` reports a repository on the old layout as drift.
- The pre-commit plan guards treat a plan moved from `docs/plans/` to
  `.harness/plans/` as the same plan, so committing the move re-runs only
  entries it adds.
- Repository layout: gate scripts live in `scripts/ci/`, stage helpers in
  `scripts/workflow/`, machine setup (`CLAUDE.md`, rules, hooks, installers,
  statusline) in `setup/`, and guides in `docs/guides/`.

### Removed

- Lean eval: `docs/evals/` and its scripts (`run-lean-trial.sh`,
  `lean-replay-score.sh`, `verify-lean-eval.sh`, `test-lean-eval.sh`,
  `generate-dashboard.sh`, `probes/`). Recover them from the
  `archive/lean-eval-v1` tag.

## [v0.30.0] — 2026-10-23

### Added

- `mono-mode` fanout playbook with an orchestrate-lite section for long
  multi-unit runs.
- `arena` reason skill: a design bakeoff that picks a base and grafts on the
  best parts of the other candidates.
- `work-fanout.md` companion: separate writers, brief and verify handbacks,
  integrate one branch at a time; pinned by a `zharness` contract.

### Changed

- Install warns when an older `zharness` shadows the new one on `PATH`.

## [v0.29.0] — 2026-10-22

### Added

- `mono-mode` router skill with feature, bug-fix, investigation, and
  session-pickup playbooks; handback proof rule; stale-hook and validator
  trip guards in `scripts/test-guards.sh`.
- `work-bounded.md` companion: bounded mode split out of `work`.

### Changed

- Skills regrouped into `router/`, `stages/`, `reason/`, `tools/`, `extras/`;
  `zharness` reference contracts follow the new paths.
- Workflow: pstack principles inlined into stage skills; retro findings
  applied (ref contract gate, handoff plan slicing, brainstorm reads its named
  reference).
- Setup `CLAUDE.md`: mandatory TinyFish web-access rule.

## [v0.28.0] — 2026-10-21

### Added

- Statusline: `★` reads Claude Code's `prompt_cache` (session hit rate, TTL
  countdown, labelled misses); `ϟ` tpm sums deduped output tokens per
  API-minute; `refreshInterval` is 30 so the countdown ticks while idle.
- Evals: lean-v1 protocol (ADR 0016), evidence verifier, trial runner, and
  observational replay scorer (`scripts/lean-replay-score.sh`) with a B-era
  baseline.

### Changed

- `zharness`: workflow playbooks move out of the binary into each owning
  skill's `references/` (ADR 0015). `update` retires the recorded legacy
  playbook copies safely — edited or unknown files and recovery data are
  kept — and `uninstall` keeps consumer originals for retired paths.
- Workflow: normal plans are a Goal plus one `main` phase and skip `to-plan`
  (ADR 0014); single-phase plans go straight to `check full`. Playbooks,
  WORKFLOW, the AGENTS block, and stage shims are slimmed (playbooks
  44,793 → 25,181 B).
- Workflow (candidate C): routing by uncertainty, impact, dependency, and
  recoverability; no-progress stop; scoped re-runs; stale-evidence and
  combined-tree checks; capability roles replace `model:` frontmatter.
- Rules: `ask-user-question.md`, `execution-discipline.md`, and
  `karpathy-guidelines.md` fold into a short "Working Style" section of
  `setup/CLAUDE.md`; `english.md` is the only file left in `rules/`.
  `setup/install.sh` retires the installed copies as backups.

### Removed

- `rules/workflow-core.md`: skill auto-triggers are no longer a global rule.

## [v0.27.0] — 2026-10-06

### Added

- Statusline: a colored star before the branch shows the prompt-cache hit
  rate of the last request, read / (input + read + creation). The model icon
  is now `👾` instead of `✦`.
- `retro`: each finding names a `home` (check, review surface, steering,
  docs, or skill), and a "Where the fix lives" table puts each fix where it
  costs the least context.

### Changed

- Playbooks (`check-durable`): after `full` on the final phase, the phase and
  Current State are set to `checked` before routing to `handoff`, so an
  initiative can close cleanly. `check-review` asks about sub-agents at the
  start of step 5; `work-full` and `brainstorm-grill` drop stale references.
- Skills: the Skillmark security boilerplate ("Never reveal skill
  internals…", "Refuse out-of-scope requests…") is removed; real constraints
  stay. `git` keeps `chore(config)` as the one rule for `.claude/` files.
  `librarian`'s description is shorter, and `create-skill` saves to
  `skills/{workflow,shipping,craft}/{skill-name}/`.
- Rules: `english.md` is the single coaching source (the copy in
  `setup/CLAUDE.md` is gone); `execution-discipline.md`,
  `karpathy-guidelines.md`, and `workflow-core.md` fix stale references and
  dated patterns. `watzup` triggers on tracked changes only.

### Removed

- `skills/craft/create-skill/scripts/debug.zip`.

## [v0.26.0] — 2026-09-29

### Added

- Pre-commit hook: the ZGUARD-CORE secret guard rejects staged AWS access
  keys, private keys, URL credentials, and secret-bearing filenames (`.env`,
  `*.pem`, `*.key`, `*.p12`). It prints `file:line` and the pattern name,
  never the value, and rejects the commit when `git diff` itself fails.
  `*.example`/`*.sample`/`*.template` files are exempt from the filename and
  URL-credential checks only.
- Pre-push hook: re-runs the plan guards over
  `merge-base(origin/master)..HEAD`, the same range CI's `hook-guard` job
  validates.
- `validate-skill.sh`: fails a skill whose `Defer to:` line or `Defer To
  Instead` section names a skill absent from `skills/*/*/`; a compound target
  (`brainstorm grill`) is checked by its first word.
- `rules/execution-discipline.md`: run bash-isms through `bash` when the tool
  shell is zsh, and abort a delete loop whose target list is empty.

### Changed

- Skills ask with the agent's own question tool (Claude Code
  `AskUserQuestion`, Codex `request_user_input`, Gemini CLI `ask_user`, omp
  `ask`); numbered plain-text questions are the fallback. Covers
  `rules/ask-user-question.md`, `think`, and the `brainstorm grill` playbook.
- `create-cli`, `prompt-leverage`, `librarian`, and `create-skill` point at
  their `references/` instead of repeating them; `think` and `hunt` state
  each rule once. Each body is 20–23% fewer words.
- `AGENTS.md` is 70 lines; install commands and the SSH-key prerequisite are
  in README §Optional skills. `rules/karpathy-guidelines.md` states each
  instruction once (357 words).

### Fixed

- `create-skill`, `create-cli`, and `turbo-mono-platform` defer to `check`
  instead of the nonexistent `review` skill.

## [v0.25.0] — 2026-09-27

### Added

- `to-plan`: tasks are sliced as tracer bullets (vertical, one context
  window each, prefactor first; a wide mechanical refactor is its own task),
  and the section records `seams:` — the public interfaces tasks are tested
  at. A new seam is confirmed with the user before the section is written.
- `work` (full): a behavior task runs red → green at its planned seam — a
  failing test first, then the least code that passes. The `done` Log line
  names the test that went red. A test needed at an unplanned seam is a plan
  gap, logged as a `decision`.
- `check`: the `full` review (and a `bounded` diff review) runs on two axes
  kept apart — Spec (requirements missing, partial, wrong, or scope creep)
  and Standards (repo standards, Security/Performance/Architecture/Quality,
  a Fowler smell baseline, and test anti-patterns) — reported without
  cross-axis reranking. One agent runs both axes by default; `full` uses two
  parallel sub-agents only when the request asks for them or the user picks
  them at a one-time prompt. `bounded` never spawns sub-agents unless asked.
- `skills`: `retro`, a user-invoked session retrospective. It reads a
  session through `scripts/session-digest.py` (token and compaction
  totals, tool-call counts, errors, repeated calls, largest results, user
  prompts, structured-question answers), checks the repo's existing
  guards and review surface first, reports at most 5 evidence-cited findings
  ranked `S1`–`S3` with one marked `Next`, and — only after the user approves
  it — fixes that one finding as a guard or as a rerun-gated experiment.
- `brainstorm` 5.0.0: subcommands `explore` (default), `grill`, `raw`,
  `lock`, `refine`. `grill` walks a design tree in frontier rounds: each
  round asks every decision whose prerequisites are settled, with a
  recommended answer on each question. The agent looks up facts itself; only
  decisions go to the user; decisions only an absent person can make become
  `open_question: … | owner: …`. Each round also stress-tests terms, edge
  cases, and code contradictions. The grill is done when the frontier is
  empty and `to-plan` could plan from the Goal without a single question;
  it flags `adr candidate` decisions, then offers a lock. `raw` runs at most
  2 rounds and prints decided / assumed / open.

### Removed

- `cli`: the golden replay test (`tests/golden.rs`), the Go-manifest
  compatibility test (`tests/go_manifest_compat.rs`), and their fixtures under
  `cli/testdata/golden/`. Every edit to an embedded playbook forced a hand
  re-bless of those fixtures. CLI output and exit codes, and reading a
  manifest written by Go v0.23.1, are no longer covered end to end;
  `projection_parity` and the unit tests remain.
- `skills`: `encode-invariant` and `improve-harness`, folded into `retro` as
  its guard and experiment fix modes. Their references moved unchanged to
  `skills/workflow/retro/references/`. **Migration:** reinstall the skills;
  invoke `/retro` where you invoked either removed skill. A plan already at
  `docs/plans/active/harness-improvement-{slug}.md` keeps working as is.
- `skills`: `interview`, folded into `brainstorm grill` (deep) and
  `brainstorm raw` (fast). Its separate validated-spec template is gone; a
  grill writes the plan's `## Goal` directly on an approved lock.
  **Migration:** invoke `/brainstorm grill [idea|plan path]` where you
  invoked `/interview`, and `/brainstorm raw` for `mode:fast`.

### Changed

- Workflow token slim, phase 1 (`git show 3bab3c0:docs/audit/workflow-token-slim-audit.md`
  R1, R4–R7, R9): `git` carries the commit flow in `SKILL.md` and reads
  `references/workflow.md` only for `pr`/`merge`; `AGENTS.md` drops the
  directory tree and pipeline prose for a pointer to
  `skills/workflow/README.md`; `rules/` folds the restated discipline
  sections into a new `karpathy-guidelines.md` §5; `hunt` reads only the
  matching section of `failure-patterns.md`; `think` carries its four core
  lenses inline. Workflow `SKILL.md` frontmatter keeps one `version:`, and
  `hunt`/`think` attribution moves to each skill's `NOTICE.md`.

- Workflow token slim, phase 2 (audit R2, R3): `check.md` and
  `brainstorm.md` split by branch. `check-durable.md` holds the preflight,
  owned plan state, and gate steps 4 and 8–11; `check-review.md` holds the
  two review axes; "What the Guards Cannot Check" moves to
  `check-validation.md`. `brainstorm-grill.md` holds the Grill loop and
  `brainstorm-lock.md` the Plan Skeleton and lock steps 4–10. `zharness
  update` delivers the four new files as managed playbooks; every pinned
  contract phrase moved byte for byte. Known gap: `zharness update`
  records no installer ownership for the four new files, so a later
  `zharness uninstall` keeps them as provenance-unknown; delete them by
  hand if needed.

- Workflow token slim, phase 3 (audit R8): `hunt` loads by mode. Steps 5–7
  move to `references/fix.md` (read by `fix`, and by `sweep` for step 6);
  Bisect and Regression move to `references/bisect-regression.md`;
  `triage` follows `references/triage.md` instead of steps 2–7.
  `diagnose` now reads only steps 1–4.

## [v0.24.0] — 2026-09-22

### Changed

- The CLI is rewritten from Go to Rust. The crate lives in `cli/`; the Go
  sources, `go.mod`, `go.sum`, and `.goreleaser.yaml` are gone. The three
  verbs, their flags, their exit codes, the bytes they write, and the
  `.zharness/base/manifest.json` schema are unchanged — a manifest written by
  Go v0.23.1 is read, updated, and uninstalled without a forced reinstall.
  **Migration:** install the new binary the same way; nothing in a consumer
  repository changes. Building from source is now `cd cli && cargo build
  --release` instead of `go build ./cmd/zharness`.
- Help, usage, and error text now comes from clap, not cobra: `Available
  Commands:` and `Flags:` render as `Commands:` and `Options:`, and clap adds
  its own `-h, --help  Print help` line. Exit codes are unchanged — 0 for
  help and for a bare invocation, 1 for a usage error, not clap's default 2.
  **Migration:** anything parsing help text must be updated; anything
  checking exit codes needs no change.
- Releases publish under the `cli/vX.Y.Z` tag itself, named `zharness X.Y.Z`,
  instead of goreleaser's bare `vX.Y.Z` tag. The archives keep their
  `zharness_{os}_{arch}.tar.gz` names and `checksums.txt` is still written.
  **Migration:** `scripts/install-zharness.sh` already resolves the latest
  release by name, so it needs no change; a script that downloads by bare tag
  must switch to the `cli/v...` tag.
- darwin/amd64 is no longer built. Apple discontinued x86_64 macOS and GitHub
  is retiring its Intel runners, so the matrix ships darwin/arm64 and both
  linux architectures. **Migration:** Intel Mac users run the arm64 binary
  under Rosetta 2, or build from source with
  `cd cli && cargo build --release --target x86_64-apple-darwin`.
- The size target is enforced in CI: the `size-gate` job fails if the
  linux/amd64 stripped binary exceeds 1,850,000 bytes. The local release
  build is 732,648 bytes (823,888 for musl), against the Go v0.23.1 baseline
  of 3,715,506.

### Removed

- `cli/cmd/`, `cli/internal/`, `cli/go.mod`, `cli/go.sum`, and
  `cli/.goreleaser.yaml`. **Migration:** none for consumers; contributors
  build with cargo.

## [v0.23.1] — 2026-09-21

### Changed

- Every live instruction that routed agents to write scratch or reports into
  `.kit/` now points at the correct home: per-machine cache to
  `.zharness/cache/` (already gitignored for every consumer), durable plans
  to `docs/plans/active/`, and durable evidence to `docs/audit/`,
  `docs/research/`, or `docs/templates/`. `TestNoLegacyKitPaths` guards
  against the path reappearing in `skills/`, `rules/`, `scripts/`, or docs.
  No CLI runtime behavior changed; historical records describing `.kit/` as
  it was are left untouched.

## [v0.23.0] — 2026-09-19

### Added

- `zharness update --check [--all]` reports drift from the running binary
  without writing and exits 1 on drift; `--all` checks every repository in
  `~/.config/zharness/repos`, which `install`/`update` register and `uninstall`
  removes. `scripts/install-zharness.sh` runs it after an upgrade, and
  `scripts/install-git-hooks.sh` replaces a stale zharness-owned pre-commit hook.
- `update` migrates a single 9-section active plan to the 5-section format in
  place, `## Validation` bytes unchanged (ADR 0012). Any other heading set, or
  more than one active plan, is left alone with a `notice`.
- Plans carry spec and evaluation criteria as fields: Goal `success_signal:`,
  `actors:` and a per-requirement `acceptance:`; tasks `output:`/`check:`/
  `stop_if:`, high-risk phases `escalate_when:`; `to-plan` traces every
  requirement to a check; `check` records `requirements:` coverage and
  `rollback_point:` in Validation.

### Changed

- `update` no longer merges. `docs/PROJECT.md` is written only when absent. The
  `AGENTS.md` block is replaced between its markers; if it was edited since the
  last write, `update` prints the diff, writes nothing, and exits 1 unless
  `--force` (ADR 0011).
- The plan is five sections — Goal, Phases and Verification, Log, Validation,
  Current State and Next Action — scaled by lane (`tiny` needs no plan). Phase
  `status:` is a bare line under `phase_slug:`. Closing `handoff` compacts Log
  and Validation and writes `lifecycle_status: completed`.
- `check` has three modes: `gate`, `full`, `bounded`.
- Stages name model tiers (deep/standard/fast) instead of model names.

### Removed

- Three-way merge, `update --continue`/`--abort`, the update stash,
  `.zharness/conflicts.json`, and `.zharness/base/upstream/` (deleted on the
  next `update`).
- `intake_id`/`story_id` and the unused check/handoff/spec/plan templates.

**Upgrade:** run `zharness update` in each consumer repository, or
`zharness update --check --all` to list the ones that drift. Anyone scripting
`update --continue`/`--abort` must drop it.

## [v0.22.1] — 2026-09-19

### Changed

- Repository guidance is consolidated into a single `AGENTS.md`; the root
  `CLAUDE.md` is deleted. `scripts/verify-doc-links.sh` now scans `AGENTS.md`
  instead of `CLAUDE.md`. No `zharness` behavior change. Consumers that want
  Claude Code to load `AGENTS.md` keep a thin `CLAUDE.md` containing `@AGENTS.md`.

## [v0.22.0] — 2026-09-17

### Changed

- `WORKFLOW.md`: cite `docs/playbooks/*.md` and `docs/WORKFLOW.md` by section
  and step number, never by line (`:NN`) — `zharness update` fresh-overwrites
  these files, so line anchors drift silently and the doc-link guard never
  validates the `:NN` suffix. Run `zharness update` in consumer repositories
  to pick up the convention.

## [v0.21.0] — 2026-09-15

### Changed

- Playbooks: `zharness install`/`update` now write 8 playbooks. Full-mode `work`
  execution moves to `playbooks/work-full.md`, and the Validation entry format
  moves to `playbooks/check-validation.md`. Each is loaded only by the mode that
  needs it, so bounded `work` reads 3142 bytes instead of 9813 and bounded or
  review `check` reads 9718 instead of 15597. Run `zharness update` in consumer
  repositories to pick up the split.
- The 6 spine playbooks, `WORKFLOW.md`, and their `SKILL.md` triggers are
  trimmed per `git show 3bab3c0:docs/audit/playbook-token-audit.md` with no change in behavior.

### Fixed

- `work`: the in-session gate sets a clean non-final phase `checked`. The final
  phase stays `in-progress` for an independent `check full`, which rejects a
  `checked` phase.
- `watzup`: section reads fall back to `awk` when `scripts/plan-slice.sh` is absent.
- `brainstorm`: step 7 checks for any non-empty active plan before locking.

## [v0.20.1] — 2026-09-15

### Fixed

- `work`: auto mode selects durable execution only when the request names or
  continues an initiative. Direct bounded work no longer requires an active plan.
- `check`: default to auto mode. Direct changes select bounded; initiative checks
  validate the total active-plan count, selected phase, and Current State before
  selecting gate. Invalid initiative state stops instead of falling back to bounded.
- `check`: announce the resolved mode after read-only preflight and before checks
  or writes; re-read required state after compaction. Full review remains explicit.

### Changed

- Update the work skill to 1.4.1 and check skill to 1.7.0. Skills are installed
  separately from the CLI; run `zharness update` in consumer repositories to refresh
  their managed playbooks after upgrading the binary.
- Record the context-cost audit and ten routing smoke scenarios, including the
  corrected multiple-plan ambiguity. Runtime compaction and cost savings remain
  unproven experiments.

## [v0.20.0] — 2026-09-08

Remediates the 2026-09-07 third-party integrity review
(`git show 3bab3c0:docs/audit/2026-09-07-integrity-review.md`). Its eight findings collapse into
three root causes, each fixed as a mechanism rather than as a patch: ownership
inferred from filesystem state, stash restore written as a loop rather than a
transaction, and revision selection made ad hoc at each guard call site. See
ADR 0008 and ADR 0009.

### Added

- `feat(installer)`: `.zharness/base/ownership.tsv` — a durable ledger fixing each
  managed path's origin (`created_by_installer` / `preexisting`) on first decision
  and never revising it. All provenance is decided and persisted before the first
  managed byte is written, so an interrupted install cannot leave unattributed
  files behind. An installation predating the ledger is seeded from the manifest
  and `.orig` evidence the previous code already relied on.
- `feat(guards)`: `zharness_guard_revspec` — one revision selector for all three
  events (`staged` / `push` / `pr`), replacing three ad-hoc call sites. It fails
  closed when no base revision resolves rather than silently guarding an empty
  range. Companions `zharness_guard_plan_paths` and `zharness_guard_old_blob`.
- `docs`: `check.md` gains **What the Guards Cannot Check** — `judge: independent`
  is testimony rather than attestation, an unrecognized entry format is ignored
  rather than rejected, and a range guard only compares endpoints.

### Fixed

- `fix(installer)` (F01): creating `AGENTS.md` no longer confers ownership of prose
  written into it later; uninstall strips the managed block and keeps the rest.
- `fix(installer)` (F06): a reinstall no longer captures the first install's
  generated bytes as that file's pre-install original.
- `fix(installer)` (F07): uninstall removes only the `.gitignore` lines it added and
  leaves an identical rule the consumer already had.
- `fix(installer)` (F04): `stash.tsv` gains an existence column. v1 collided "absent"
  with "present but empty" into a zero-byte blob and restore read zero bytes as a
  deletion request, so aborting an update deleted a file that had merely been empty.
  A v1 stash is now reported as ambiguous instead of resolved by a guess.
- `fix(installer)` (F05): stash restore validates the whole inventory and reads every
  payload before touching the working tree, and names exactly what failed instead of
  half-applying. The stash directory survives any failure.
- `fix(guards)` (F02/F03/F08): a push of more than one commit was guarded only at
  `HEAD~1`; everything earlier in the range went unchecked. CI now checks out full
  history (`fetch-depth: 0`) and passes the event SHAs in explicitly.

### Changed

- `refactor(installer)`: uninstall reports what it removed and what it kept, with a
  reason per kept path, replacing the unconditional claim that "consumer-owned files
  were never touched". Unknown provenance is kept, never resolved by deleting.
- `ci`: the two `HEAD~1 HEAD` guard steps collapse into one range-guarded step, and
  the guard-core extraction check asserts the new selector functions are present.

## [v0.19.0] — 2026-09-08

### Added

- `feat(guards)`: New pre-commit/CI guard `zharness_guard_completed_plan_phases_done`
  rejects a plan staged or pushed under `docs/plans/completed/` whose `Current
  State` declares `lifecycle_status: completed` while any phase in `## Phases
  and Verification` is not `status: done`.

## [v0.18.0] — 2026-09-07

### Added

- `feat(installer)`: Identity template now defines explicit slots for `run from:`,
  `tests:`, `types:`, `lint:`, `build:`, and `format:` (accepting `n/a`). Deliberately
  conflicts on `zharness update` for repositories using the legacy template to prompt
  owner re-configuration.
- `test(cli)`: Automated embedded-to-projected parity test `TestProjectionParity`
  under `cli/docs/embedded/parity_test.go` running in CI to enforce the byte-identical
  playbook invariant.
- `skills`: Payload-local `references/` directories added to `encode-invariant` and
  `improve-harness` to eliminate external doc-tree dependencies in consumer checkouts.

### Changed

- `docs/PROJECT.md`: Format gate changed from bare `gofmt -l cli` to `test -z "$(gofmt -l cli)"`
  so unformatted Go files reliably fail the gate.
- `git` skill: Dynamic base branch resolution for `/git pr` and `/git merge` verifying
  remote tracking branches (`refs/remotes/origin/`) before local heads; stack-neutral
  staging and lockfile grouping for Go (`go.mod`/`go.sum`), Rust (`Cargo.toml`/`Cargo.lock`),
  and Python (`pyproject.toml`/`uv.lock`/`poetry.lock`); co-located tests commit with the source they cover.
- `playbooks`: Proof re-execution contract in `check.md` explicitly documents inherited
  exported environment variables; `watzup.md` resolves base branch dynamically;
  `brainstorm.md` adds a `zharness install` absence branch for consumer checkouts.

### Fixed

- `git` skill: PR creation no longer collapses `$BASE` to current branch `$HEAD` in
  single-branch, shallow, or worktree checkouts lacking a local default branch checkout.

## [v0.17.0] — 2026-09-03

### Fixed

- `zharness update`: a playbook or `docs/WORKFLOW.md` with no recorded
  merge base — `.zharness/base/` lost, or predating base tracking — used to
  stay stuck on stale content forever (R18 refused to invent an ancestor).
  These files are pure upstream mirrors, never a legitimate consumer
  customization surface, so `install`/`update` now fresh-overwrite them
  unconditionally: no diff, no compare, no conflict. Three-way merge stays
  for `docs/PROJECT.md` and the marked `AGENTS.md` block, the two managed
  files consumers do own. See `docs/decisions/0007-fresh-overwrite-for-playbooks-and-workflow.md`.

### Changed

- Hand-edits to a playbook or `WORKFLOW.md` are now silently discarded on
  the next `zharness update`, with no conflict marker warning first — the
  accepted cost of the fix above.

## [v0.16.3] — 2026-09-02

### Changed

- `check.md` gate: if `scripts/record-check.sh` exists, run proofs through
  it (timeout → gtimeout → unbounded; 3-line pass / 10-line fail tail).
  If it is absent, capture to a temp file, print the same tails, and keep
  the command's exit code. Nested Validation bullets still cite the raw
  commands so the hook re-executes them.

### Fixed

- `scripts/record-check.sh`: same timeout resolver as the pre-commit hook,
  so stock macOS no longer fails with `timeout: command not found`.

### Added

- `git show 3bab3c0:docs/audit/wave-session-ab-protocol.md`: paired worktree A/B for
  same-session vs wave-boundary restart. Does not change `work.md` step 11.

## [v0.16.2] — 2026-08-30

### Changed

- Handoff close: after absorb and `git mv`, a completed plan is a run log
  (cite the ADR or guard, never the completed path). It may later be deleted
  when no recovery audience remains; if unsure, keep. Deletion is not part
  of close.

## [v0.16.1] — 2026-08-30

### Added

- `escalate_when` on `work.md` and `WORKFLOW.md`: ask the owner and stop
  when locked schema or requirements would change, the same verification
  command failed twice, or a product rule conflicts. Retry cap stays one
  targeted fix. Not a plan field. Not a hook.

## [v0.16.0] — 2026-08-30

### Added

- Handoff absorb gate: an initiative cannot `git mv` to `completed/` without
  an `absorb:` line in `## Decisions` (`absorb: none` is valid). A
  class-of-failure or expensive-to-reverse decision must already live in an
  ADR or a native guard.
- Pre-commit R5: at most one non-empty file under `docs/plans/active/`; zero
  is a valid idle state.
- Pre-commit H3: a newly added `mode: full` Validation entry that also
  declares `judge: same-session` is rejected. Full checks require an
  independent judge.
- Source-repo skills `encode-invariant` and `improve-harness` (not part of
  `zharness install`).
- `LICENSE` (MIT), `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`,
  and `.github/dependabot.yml`.

### Changed

- Consumer `README.md` and `AGENTS.md` rewritten around the three-verb
  installer. Workflow diagrams no longer mention `zharness init` or a local
  database.
- Live contract and architecture describe the v0.16 protocol. The binary
  surface is unchanged from v0.15: `install` / `update` / `uninstall`.

### Fixed

- Guard entry hashes no longer depend on trailing blank lines, which had
  re-executed the previous Validation entry on every append.
- Skill validation actually runs on `skills/<category>/<name>/SKILL.md`.
  Load-time errors stay fail-closed; format checks are warnings.

## [v0.15.1] — 2026-08-28

### Fixed

- Pre-commit guard: the verdict token is read from a Validation entry's first
  line and now matches the repository's `verdict \`APPROVED\`` grammar —
  previously every real APPROVED entry was silently skipped by the guard.
- Pre-commit guard: Validation entries without a leading timestamp are now
  visible to both fail-closed guards.
- Installer: `.zharness/base/original/` naming is collision-free (with a
  legacy fallback so v0.15.0-captured originals still restore), and diff3
  falls back to a conservative whole-side hunk above an 8M-cell LCS cap.
- Non-spine `git`/`interview` skills no longer reference binary commands
  deleted in v0.15.
- Pre-commit guard: proof re-execution no longer depends on GNU `timeout`
  being installed. The wrapper is resolved at call time (`timeout`, else
  `gtimeout`, else the command runs unbounded with a warning), so a proof's
  verdict follows its own exit code. On stock macOS every proof previously
  exited 127 (`timeout: command not found`) and the guard rejected each
  honest APPROVED entry.
- Guard fixture suite: the entry-count assertion compares numerically, so
  BSD `wc -l` padding can no longer produce a false FAIL on macOS.
- Pre-commit guard: the old-side entry set no longer uses a bash 4
  associative array. The hook's shebang is `#!/bin/bash`, which on macOS is
  bash 3.2: `local -A` failed there, the hex hash was then evaluated as an
  arithmetic array subscript, and the shell died with "value too great for
  base" on the first old-side entry — so every commit touching a plan that
  already had a Validation entry was rejected with an opaque error. Membership
  is now a hash file plus `grep -Fxq`, identical on every bash.
- Guard fixture suite: the decisive accept and reject cases are re-run under a
  legacy bash 3.x when one is present, so the guard core cannot regress into a
  bash-4-only construct.

## [v0.15.0] — 2026-08-28 (breaking)

### Changed

- **BREAKING**: the entire `zharness` lifecycle command surface (init,
  migrate, import, db rebuild/status, query views, intake, story, trace add,
  decision add, memory, run create, plan complete/abandon, resume, preflight,
  check record, handoff record, validate, audit) and SQLite are deleted from
  source. The binary is being reduced to install / update / uninstall.
- State lives in git-committed markdown alone (`docs/plans/**`). Lifecycle
  bookkeeping is hand-appended markdown gated by the repository's pre-commit
  hook, which now owns both fail-closed guarantees: proof re-execution for
  APPROVED Validation entries and the independent-judge rule for high-risk
  lanes (`scripts/install-git-hooks.sh`; CI re-runs the same guards).

### Removed

- The SQLite database (`harness.db`) is no longer created, read, or written
  by the binary.

### Upgrade guidance

- **Pin `v0.14.x`** if you still need the old lifecycle binary — that line
  keeps a fully working product with its own `harness.db`.
- Your existing `harness.db` (and its `-wal`/`-shm` sidecars) is
  **consumer-owned bytes**: nothing in this or future releases deletes it.
- New consumers need no initialization at all: markdown plus git is the whole
  system of record.
