# Playbook: check (durable gate and full)

Loaded by [check.md](check.md) step 2 for `gate`/`full`; numbering follows it.

## Preflight

2. **Read-only preflight** — count every non-empty markdown plan under `.harness/plans/active/` before matching the requested initiative. Require exactly one active plan in total, matching the request; IF several → list them and stop even when only one matches the request. Read only its selected phase and `## Current State and Next Action`, re-reading after any compaction; both must read `in-progress`. A missing or ambiguous phase, any other status (including unstarted, `checked`, or `done`), or a conflict → stop before checks or writes and report the exact mismatch. Never change phase status to pass preflight.

## Owned Plan State

Only gate/full may append to `## Validation` and update the phase `status:` line and `## Current State and Next Action`. `## Log` is the sole task execution-status source.

## Durable Steps

4. **Plan alignment** — diff vs Goal, phase surfaces, task checks, Log `decision`s; missing planned proof is a finding. Judge each requirement the phase `goal:` names against its `acceptance:` (else its text) and record it in the entry's `requirements:` line as `met`, `not met`, or `partial (→ <phase>)` when a later phase also names it. `not met` is a material plan contradiction; `partial` is not a finding. `full` on the final phase also judges the Goal's `success_signal:`. Record `rollback_point:`.
8. **Append evidence** — read [check-validation.md](check-validation.md), then write the entry in that format. Cite only captured output. REQUEST_CHANGES entries may cite deliberately failing commands.
9. **Declare enforcement** — no verifier runs here. The repository's pre-commit hook is the sole proof guarantee where installed (`bash scripts/install-git-hooks.sh --force`); without it → `enforcement: local-only`. Never assert enforcement the repository does not have.
10. **Sync plan state**:
    - `APPROVED`/`APPROVE_WITH_REQUESTS` → set the phase status and Current State lifecycle status to `checked`; route to `handoff` or `git` (final phase after `full` → closing `handoff`).
    - `REQUEST_CHANGES` → keep the phase and Current State lifecycle status `in-progress`, record findings as blockers, route to `work`.
11. **Verify** — re-read; statuses must match what you wrote, and Current State must agree with the Validation tail. `check` never marks a phase `done`.
