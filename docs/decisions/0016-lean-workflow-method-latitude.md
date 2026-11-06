# 0016 — Revise prompt-level method constraints; keep product and authority boundaries

## Status

Accepted owner decision, 2026-10-13 and 2026-10-20 (`docs/plans/completed/lean-sdlc-workflow.md`, Goal authority). Recorded before candidate implementation, following the [0015](0015-skill-owned-procedures-and-safe-retirement.md) precedent of an owner-required ADR-first initiative. Candidate edits under this decision are made in phase `f2-candidate`. The candidate is promoted only if the B/C comparison in the plan shows a targeted gain with no predicate regression; otherwise this ADR is superseded by a no-promotion record and B (`da9fed6`, tag `baseline/playbooks-to-skills-B`) stays live. Preserves [0014](0014-outcome-spec-normal-plans.md) and [0012](0012-five-section-plan-and-update-migration.md) unchanged.

## Context

After the [0015](0015-skill-owned-procedures-and-safe-retirement.md) migration, six workflow skills own their procedures. Several rules in those procedures limit how the model does the work, not what it may change. Examples: a numeric bounded cap (`skills/workflow/work/references/work.md:8`), a second-failure stop (`skills/workflow/work/references/work-full.md:20`, `skills/workflow/work/references/work.md:20`), forced model metadata (`skills/workflow/work/SKILL.md:3`) and a mid-phase model-switch ban (`docs/WORKFLOW.md:22`). `docs/guides/prompt-engineering-principles.md:13`, `:15`, `:53` and `:82` state numeric or model-family generalizations without sources. The owner wants fewer of these method rules and still requires every authority and proof boundary.

## Decision

1. **Boundary rules stay; method rules may change.** A rule is a boundary when it protects scope, authority, durable state, independent review or proof. It is a method rule when it only prescribes how the agent works inside approved scope. The candidate may revise method rules. It may not revise boundary rules without a new authority record.
2. **Inventory.** This is the keep/change/remove map for the candidate. "Enforcement" names the executable guard, or "prompt only" when no guard exists. No prompt rule is claimed to make agent behavior deterministic.

   | Rule (source at B `da9fed6`) | Kind | Disposition | Enforcement |
   |---|---|---|---|
   | At most one active plan (`scripts/install-git-hooks.sh:244`) | boundary | keep | pre-commit guard R5 |
   | Five plan sections and parsed fields ([0012](0012-five-section-plan-and-update-migration.md), [0014](0014-outcome-spec-normal-plans.md) decision 5) | boundary | keep | pre-commit guards; `scripts/test-guards.sh` |
   | Independent judge for high-risk and `full` (`scripts/install-git-hooks.sh:23`, `skills/workflow/work/references/work-full.md:23`) | boundary | keep | pre-commit guard R3 rejects `same-session`; independence itself is testimony |
   | Normal = Goal + `main`, no to-plan, single final `check full` ([0014](0014-outcome-spec-normal-plans.md) decisions 1–4) | boundary | keep | prompt only |
   | Log append-only, sole execution-status source (`skills/workflow/work/references/work-full.md:8`) | boundary | keep | prompt only |
   | Bounded mode writes no durable artifact (`skills/workflow/work/references/work.md:12`) | boundary | keep | prompt only |
   | `git` owns outward actions; no implicit commit/push/PR/merge/deploy (`skills/workflow/git/SKILL.md:14`) | boundary | keep | prompt only |
   | Missing skill/reference stops; no legacy fallback (`skills/workflow/work/SKILL.md:17`, [0015](0015-skill-owned-procedures-and-safe-retirement.md) decision 2) | boundary | keep | prompt only |
   | Red → green for behavior; never weaken tests (`skills/workflow/work/references/work-full.md:18`) | boundary | keep; may add a justified observable equivalent | prompt only |
   | Bounded rejects > five files or ~100 lines (`skills/workflow/work/references/work.md:8`) | method | change: route on uncertainty, impact, dependency and recoverability; file count is information only | prompt only |
   | Same verification failed twice → stop (`skills/workflow/work/references/work-full.md:20`, `skills/workflow/work/references/work.md:20`) | method | change: no-progress rule; a repeat without new evidence blocks | prompt only |
   | `model:` frontmatter on six core skills (`skills/workflow/{brainstorm,to-plan,work,check,handoff,watzup}/SKILL.md`) | method | remove; describe capability roles. no validator or contract test references `model:` | prompt only |
   | Tier table and "Do not switch model mid-phase" (`docs/WORKFLOW.md:22`, `cli/docs/embedded/WORKFLOW.md:22`) | method | change: capability roles plus a transfer brief | `projection_parity` keeps the two copies equal |
   | Instruction budget ~150–200 (`docs/guides/prompt-engineering-principles.md:13`) | claim | remove, or source and qualify | none |
   | Exponential vs linear degradation (`docs/guides/prompt-engineering-principles.md:15`) | claim | remove, or source and qualify | none |
   | Vietnamese ~50% token penalty (`docs/guides/prompt-engineering-principles.md:53`) | claim | remove, or source and qualify | none |
   | Negative instructions cause the banned behavior (`docs/guides/prompt-engineering-principles.md:82`) | claim | qualify; keep the positive-phrasing advice | none |
   | Degradation is uniform across all instructions (`docs/guides/prompt-engineering-principles.md:14`) | claim | qualify as a test-before-keeping practice | none |
   | Dash vs numbered-list token counts (`docs/guides/prompt-engineering-principles.md:43`) | claim | remove | none |
   | English has highest compliance and lowest token cost (`docs/guides/prompt-engineering-principles.md:49`) | claim | qualify | none |
   | n² attention budget and context rot (`docs/guides/prompt-engineering-principles.md:11`) | claim | source to Anthropic's context-engineering post (2025-09-29) | none |
   | Undated model-family prompting table, "Latest Claude" (`docs/guides/prompt-engineering-principles.md:119-123`) | claim | date as observation; not product policy | none |

3. **Escalation.** If a candidate edit changes plan grammar, a guard, the independent-review policy, outward permission or the unsupported-host scope, stop and amend authority first. Do not drop the assertion that protects it.

Rejected: adopting external workflows wholesale (duplicate state and runtime), removing process and relying on the model (loses recovery and proof), and adding prompts without measurement (no attribution).

## Consequences

Method rules become unverified until the B/C comparison runs. C (`253d6f8`) is installed but unevaluated; to roll back, reinstall the six core skills from B (`da9fed6`) with the command in [lean-workflow.md](../evals/lean-workflow.md#status-and-re-evaluation). Rollback to B reverts the candidate's semantic edits only. It does not undo the [0015](0015-skill-owned-procedures-and-safe-retirement.md) migration. A model change after acceptance needs a fresh baseline.

## Authority

Owner requests of 2026-10-13 and 2026-10-20 recorded in the Goal of `docs/plans/completed/lean-sdlc-workflow.md`.
