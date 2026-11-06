# PROJECT — identity (answer inline; this is the single forced write step at
# brainstorm lock; keep the whole file at or under 50 lines)

## What is this project?
- zharness: an install/update/uninstall binary that scaffolds and maintains a
  markdown-first workflow harness (playbooks, identity docs, guards) in a
  consumer git repository. v0.15 deleted SQLite and every lifecycle command.
  v0.16 is the protocol on that surface: absorb at close, at most one active
  plan, independent judge for `full` checks. The binary stays off the PATH.

## Who is it for?
- The owner and contributor agents working in this repository, plus consumers
  who `zharness install` the managed doc set into their own repos.

## Non-goals
- No hidden or deprecated lifecycle commands; no parallel control-plane state
  (no task database, no derived index).
- No edits to consumer repositories beyond the managed set; no fabricated
  backfill of consumer history.
- No application runtime, credentials, schema validation, or product policy.
- No scanning or merging of `~/.claude`, `~/.codex`, `~/.agents`,
  `~/.config/opencode` (except the single codex config line in R7); the only
  other home-directory file zharness writes is its repo registry
  `~/.config/zharness/repos`.

## What are the gate commands?
- run from: the repository root
- tests: `cd cli && cargo test`
- types: n/a (the Rust compiler is the type gate; `build:` covers it)
- lint: `cd cli && cargo clippy --all-targets -- -D warnings`
- build: `cd cli && cargo build`
- format: `cd cli && cargo fmt --check`
- also required: `bash scripts/ci/verify-doc-links.sh`
- Phase gates per plan: doc links, cargo tests, S4 `rg -i "sqlite|harness\.db" cli/`
  = 0, kill-list bounded scan = 0 actionable, kill-switch smoke.

## Architecture in one breath
- runtime shape: one Rust binary (`cli/src/main.rs`) exposing exactly install /
  update / uninstall; everything else is git-committed markdown under `docs/`
  plus fail-closed pre-commit guards (proof re-execution, high-risk and full
  independent-judge, at most one active plan).
- where state lives: `.harness/plans/active/*.md` (append-only Log /
  Validation) and `.zharness/base/` (sha256 manifest + ownership
  ledger), plus the repo registry `~/.config/zharness/repos` — no SQLite anywhere.
- entrypoints: `cli/src/cli.rs`; embedded doc set under
  `cli/docs/embedded/` projected to `docs/`; hooks via
  `scripts/install-git-hooks.sh`.

## What are we working on right now?
- plan: none active; last completed `git show 3bab3c0:docs/plans/completed/zharness-slim.md`
- follow-up: none for `stop_if:` / `escalate_when:` — `work-full.md` step 4 gates them
  fail-closed as procedure text, pinned by the contract in `cli/src/embedded.rs`;
  no runtime or hook checks agent behavior (zharness has no task runtime).
