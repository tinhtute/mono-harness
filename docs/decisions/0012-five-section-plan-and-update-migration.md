# 0012 — Five-section plan format, migrated by `update`

## Status

Accepted. 2026-09-19. Decision 2 amended by [0014](0014-outcome-spec-normal-plans.md). Authority: R8–R13 of `git show 3bab3c0:docs/plans/completed/zharness-slim.md`.

The implementation citations below were repointed from the Go sources to the Rust port in the v0.24 cutover; the decisions and their rationale are unchanged, and symbol names in the decision text are the Go ones as decided.

## Context

An active plan had nine `## ` sections (Outcome, Authority and Requirements,
Non-goals, Approach and Risks, Phases and Verification, Progress, Decisions,
Validation, Current State and Next Action), plus minted `intake_id`/`story_id`
identifiers that no guard or CLI read. Every plan paid for all nine regardless
of size, and a closed plan kept every start/done line forever.

The pre-commit guard parses three headings verbatim (`## Validation`,
`## Phases and Verification`, `## Current State and Next Action`) and the
fields `lane:`, `phase_slug:`, `status:` and `lifecycle_status:`
(`scripts/install-git-hooks.sh:45`, `scripts/install-git-hooks.sh:51`,
`scripts/install-git-hooks.sh:244`, `scripts/install-git-hooks.sh:251`). The guard core is frozen: it must
stay byte-identical so CI and installed hooks agree.

## Decision

1. **Five sections.** `## Goal` (outcome, requirements, non-goals),
   `## Phases and Verification` (approach first), `## Log` (timestamped
   `start|done|blocked|decision` entries, with `### Decisions`), `## Validation`,
   `## Current State and Next Action`. The three hook-parsed headings are
   unchanged. The skeleton lives only in `docs/playbooks/brainstorm.md` (*Plan Skeleton*).
2. **Lanes scale depth.** `tiny` needs no plan; `normal` is one flat phase;
   `high-risk` keeps phases, waves and tasks.
3. **Bare phase status.** A phase's lifecycle is `status:` on its own line
   directly under `- phase_slug:`, with no bullet. The completed-plan PHASE-DONE
   check matches only `/^[[:space:]]*status:/` (`scripts/install-git-hooks.sh:251`), so the older `    - status: X`
   bullet was invisible to it, and that check fires only when Current State reads
   `lifecycle_status: completed` (`scripts/install-git-hooks.sh:244`), which closing
   `handoff` now writes (`docs/playbooks/handoff.md`, step 6).
4. **Compaction at close.** Closing `handoff` drops Log `start`/`done` entries
   and all but the last Validation entry per phase; everything else is kept
   byte for byte (`docs/playbooks/handoff.md`, step 6).
5. **`update` migrates one legacy plan.** A single active plan whose headings are
   exactly the nine-section set (any order) is rewritten in place
   (`cli/src/installer/migrate.rs`): sections merge, `intake_id`/`story_id`
   lines drop, phase `- status:` bullets become bare. The Validation body is
   copied byte for byte and re-checked before writing
   (`cli/src/installer/migrate.rs`). A plan already in the five-section
   shape is left alone silently; any other heading set, or more than one active
   plan, is left untouched with a `notice`; an unreadable plan or a migration
   that would change Validation makes `update` refuse before any write. The decision is
   made before the first write (`cli/src/installer/update.rs`).

Rejected:

- Keeping nine sections: every plan, however small, paid for four sections the
  guard never reads, and closed plans grew without bound.
- Teaching the guard the bulleted `- status:` form: that edits the frozen guard
  core, so CI and installed hooks would disagree until every hook is reinstalled.
- A separate `migrate` command: the owner chose migration inside `update`, so an
  upgraded repository needs no extra step.

## Consequences

- Migration is one-way. Nothing restores the nine-section layout; the
  pre-migration file survives only in git history.
- The guard still ignores a bulleted `- status:` line. A plan hand-written in
  the old form escapes PHASE-DONE until it is migrated. That gap is not encoded
  as a guard because the guard core is frozen; the playbooks and the migration
  are the mitigation.
- The migration converts every `- status:` bullet in Phases, including a
  task-level one; the playbooks forbid task status fields, so a conforming plan
  has none.
- `migrate.go` is transitional: delete it once no consumer repository holds a
  nine-section active plan.

## Authority

- `git show 3bab3c0:docs/plans/completed/zharness-slim.md` — R8–R13; owner approval 2026-09-19;
  the `migrate.go` transitional-code decision in `### Decisions`.
- `scripts/install-git-hooks.sh` — the guard core this format must satisfy.
- `docs/decisions/0011-update-without-three-way-merge.md` — the `update` shape
  the migration runs inside.
