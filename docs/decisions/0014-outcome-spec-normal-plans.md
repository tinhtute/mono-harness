# 0014 — A normal plan is its Goal plus one phase that lock writes

## Status

Accepted. 2026-10-12. Authority: the owner's answers of 2026-10-12 recorded in `docs/plans/completed/outcome-spec.md` (`## Goal`). Amends decision 2 of [0012](0012-five-section-plan-and-update-migration.md).

## Context

ADR 0012 decision 2 made a `normal` plan "one flat phase" (`docs/decisions/0012-five-section-plan-and-update-migration.md:31`), and `to-plan` wrote its flat task list (`git show c8a8429:cli/docs/embedded/playbooks/to-plan.md`, *Owned Plan Section*). A normal cycle therefore ran five stages: lock, to-plan, work, check, handoff. The 2026 research (`docs/research/2026-10-12-agent-sdlc-practice.md`) found that current models split a reviewable change into steps on their own; what they still need is the done-condition (`acceptance:`), durable state (`## Log`), and executable guards. The task list repeated what the acceptance checks already say, and `to-plan` cost a whole stage per normal cycle.

## Decision

1. **A normal plan is the Goal plus one phase `main`.** `brainstorm lock` writes it: `goal:` names every requirement, and `phase check:` runs the Goal's acceptance commands. No task list.
2. **`to-plan` is for `high-risk` only.** For a `normal` plan it stops and routes to `work`. A normal cycle is lock → work → check → handoff.
3. **`work` without tasks works each requirement in turn**; each `done` Log entry names the requirement and its acceptance check.
4. **A single-phase plan skips the same-session gate.** Its only phase is also its final phase, which needs an independent `check full` before closing `handoff`; running the gate first would review the same diff twice. `work` sets the next action to `check full` directly. Added by the owner on 2026-10-12 after the dry run measured a normal cycle at 30.6 KB (23.1 KB without the duplicate gate).
5. **Nothing else changes.** The five sections, the guard-parsed headings and fields, check preflight, handoff, `tiny`, and `high-risk` (phases, waves, independent judge) stay as ADR 0012 set them. Plans that already carry a task list stay valid; `update` migrates nothing.

Rejected: a phaseless normal plan, because check preflight, handoff and the guard's completed-plan check all select a phase, so each would need a new path; merging `normal` into `high-risk`, because it makes ordinary work heavier.

## Consequences

Easy: a normal cycle loses one stage and its playbook read. The guard needs no change: its completed-plan check still sees one `phase_slug:` with `status:` (`scripts/install-git-hooks.sh:289-293`). Hard: a normal plan no longer has a written step list to resume from mid-phase; the `## Log` `done` entries per requirement and Current State carry that instead.

## Authority

- Owner answers, 2026-10-12: normal = Goal + 1 auto phase; skip `to-plan` for normal; keep three lanes; run the change as `high-risk` with a new ADR.
- `docs/decisions/0012-five-section-plan-and-update-migration.md:31` — the decision amended here.
- `scripts/install-git-hooks.sh:289-293` — the completed-plan check that reads `## Phases and Verification`.
