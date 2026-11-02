# Playbook: feature

1. `brainstorm` — classify the lane and `lock` the Goal; a tiny request needs no plan and goes straight to `work bounded`; a high-risk lane runs `to-plan` before step 3.
2. `librarian` / `read` — prior art per [prior-art.md](../references/prior-art.md); skip for a tiny request; a wide-open design re-routes to the `research` or `prototype` playbook. A new or changed interface, module, or data shape → `think twice`, sketched from the caller's usage before types and internals.
3. `work full` — red → green per requirement; each `done` names its acceptance check; a runtime change is exercised once per [check-exercise.md](../../stages/check/references/check-exercise.md) and reported in the PR's `## Exercised`. Friction against the chosen shape (casts, always-present optionals, piling special cases) → stop and return to `think twice` instead of patching around it.
4. `check` — the lane's final mode per [check.md](../../stages/check/references/check.md) (`gate` for normal, `full` for high-risk or on request); an inconclusive or wrong-surface result is not a pass. A contested design (a close `Rejected:` call from `think`, or the owner disputed the shape) → ask the owner whether to run `check full` with the multi-model panel in [check-review.md](../../stages/check/references/check-review.md).
5. `handoff` — when a plan exists: record Current State; close the plan after a clean final check.

Reply: the outcome, what you chose and why, the acceptance results, and the furthest delivery state reached.
