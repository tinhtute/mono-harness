# Workflow Harness — Concept

The lifecycle skill chain (`watzup, brainstorm, to-plan, work, check, git, handoff`; `git` lives in `tools/`) is a markdown-first lifecycle. The 6 spine skills are thin triggers that defer to references inside their installed skill directories. This doc locks the mental model.

## 4-Layer Model

- **harness** — gone as a runtime since v0.15. Markdown plus git is the system of record; the archive trail lives in the root CHANGELOG and git history (`git show 3bab3c0:docs/plans/completed/` for the pre-prune plans).
- **workflows** — the lifecycle contract itself: `Intent → Plan → Trace → Proof → Handoff/Resume`. Tool-independent; describes what must happen, not how.
- **skills** — the 10 `SKILL.md` files under `skills/stages/`. The 6 spine skills (`brainstorm`, `to-plan`, `work`, `check`, `handoff`, `watzup`) route to their own `references/{stage}.md`. Companions resolve within that skill; cross-stage transitions use host metadata and repository data paths use the consumer root. No binary sits between the skill and its references — `zharness` installs and updates the managed doc set and plays no part in running a stage.
- **cli** — `zharness`, the Rust binary reduced to install / update / uninstall for the managed doc set. Lifecycle enforcement lives in repo scripts plus the pre-commit hook.

## Lifecycle

### Intent → Intake — `brainstorm`
A raw idea, notes, or files enter through `brainstorm`. It classifies the request into a risk lane (tiny / normal / high-risk) persisted in the plan's frontmatter `lane:` field and locks the result into one evolving plan at `.harness/plans/active/{slug}.md`, owning that plan's Goal section. A tiny request creates no plan and goes straight to `work bounded`. The lane lives nowhere else — no separate store exists.

### Story/Plan — `to-plan`
On the high-risk lane, `to-plan` writes the locked plan's Phases and Verification (approach and risks, then phases, waves, tasks, checks) into that same file. A normal plan skips it: `brainstorm lock` writes one phase `main` whose check is the Goal's acceptance commands (ADR 0014).

### Trace — `work`
`work` executes the active phase wave-by-wave, verifying every task, and appends execution state to the plan's append-only Log section.

### Proof — `check`
`check` runs the automated gate, evaluates the required-proof matrix for the plan's lane (tiny/normal/high-risk), and appends a deterministic verdict with nested proof-command sub-bullets to the plan's Validation section; the pre-commit hook re-executes every cited proof itself at commit time and rejects false claims. Missing required proof always fails, naming the missing evidence.

### Handoff/Resume — `handoff`, `watzup`
`handoff` updates the plan's Current State and Next Action directly and, on final clean closure, records an `absorb:` line then moves the plan from `.harness/plans/active/{slug}.md` to `.harness/plans/completed/{slug}.md`. `watzup` renders a session-start recap from Git state plus the plan alone.

`git`, `retro`, `hunt`, and `think` sit outside this spine — see mapping table below. `hunt` diagnoses a concrete symptom (and triages issue/PR queues); `think` reasons about a decision and writes nothing, handing a result worth keeping to `brainstorm lock`.

## SDLC Stage Coverage

The workflow chain covers plan → code → verify → commit/PR, and the core lifecycle ends there: at a committed change, or an opened PR when the work calls for one. Deployment, release management, and production monitoring are explicitly **out of scope** for the chain: `check`'s automated gate and manual review end at a clean local verdict — nothing in `work`, `check`, or `git` merges to a release line, ships a build artifact, runs a release, or watches one in production. This is a declared non-goal, not an ambient gap (G1 of the SDLC gap analysis; see `docs/decisions/0004-docs-directory-deletion-655c6ac.md`).

"Ship" means one thing in this repository: the optional `mono` [ship playbook](../mono/playbooks/ship.md), which lands already-verified PRs and then tags, publishes, or deploys, each step only on the owner's explicit request. It is an add-on that composes the skills above by name, not a stage of the chain and not a skill; preparing a branch or PR is `git`, not shipping. A real deploy target still needs its own agreed scope before the playbook grows past tag-and-publish.

A single bounded change needs one branch and one PR (or just a commit). Stack PRs only when a later change depends on an earlier unmerged one, or when the layers are independently reviewable; see the playbook's [Stacked or not](../mono/playbooks/ship.md#stacked-or-not) section.

## No Version Gate

There is no binary in the execution path, so there is nothing to version-gate. Each spine skill reads its independently installed references. The host must expose all six workflow skills; a fresh repository clone alone does not supply that dependency. Missing required skills/references stop workflow execution with a dependency report, without a retained-procedure fallback.

The old `preflight` readiness call and its `MIN_ZHARNESS_VERSION` documentation gate were deleted in v0.15. What `zharness` still does — `install` / `update` / `uninstall` — is scaffold the managed docs, fresh-overwriting WORKFLOW.md and conservatively retiring recorded legacy procedures, replacing the hash-guarded AGENTS.md block, and writing PROJECT.md only when absent, which is a setup concern, not a per-stage one.

### Non-spine skills do not stop on a missing binary

`git` owns no plan sections, and `brainstorm grill`/`raw` write nothing until a lock is approved. A missing `zharness` binary is never a reason to refuse staging, committing, or grilling an intent. The 6 spine skills are the same: markdown plus git is the system of record.

## Thin-Trigger Template

Every one of the 6 spine skills follows this shape, ≤30 rendered lines including frontmatter:

```markdown
---
name: {skill-name}
description: {what the skill does and when to use it — skills.sh discovery and triggering read this line}
---

{Resolve the invocation mode when the stage has one, then} follow [references/{stage}.md](references/{stage}.md) inside this installed skill. Read `.harness/WORKFLOW.md` first if routing is unclear. Resolve cross-stage transitions through host skill metadata and repository data paths from the consumer root. Report a missing required skill or reference and stop; retained legacy procedures are not a fallback. `zharness` only manages repository docs and plays no part in running a stage.

Defer to: {one line naming the skills this stage hands off to or resumes from}
```

## Skill ↔ Plan-Section Mapping

| Skill | Owns | Mechanism |
| :--- | :--- | :--- |
| `brainstorm` | Goal: outcome, success_signal, actors, requirements with `acceptance:`, non-goals (lane in frontmatter) | skill reference + hand-edited markdown |
| `to-plan` | Phases and Verification: approach, risks, tasks with `output:`/`check:`/`stop_if:`, `escalate_when:` on high-risk; every requirement traced to a check | skill reference + hand-edited markdown |
| `work` | Log (append-only) | skill reference + hand-edited markdown |
| `check` | Validation (append-only): proofs, `requirements:` coverage, `rollback_point:` | skill reference + nested proof sub-bullets |
| `handoff` | Current State and Next Action, phase closure | skill reference + absorb line + `git mv` on completion |
| `watzup` | console recap | git + plan reads only |
| `git` | no plan sections | enrichment optional, never blocking |
| `retro` | no plan sections, except an experiment-mode `.harness/plans/active/harness-improvement-{slug}.md` | non-spine; logic `skills/stages/retro/references/retro.md`, digest `skills/stages/retro/scripts/session-digest.py`, guard mode `skills/stages/retro/references/encoding-invariants.md`, experiment mode `skills/stages/retro/references/harness-improvement.md`; never blocking on a missing binary |
| `hunt` | no plan sections | non-spine; loop and hypotheses in `skills/reason/hunt/SKILL.md`, fix/sweep `skills/reason/hunt/references/fix.md`, bisect/regression `skills/reason/hunt/references/bisect-regression.md`, triage mode `skills/reason/hunt/references/triage.md`; report-only unless a fix is requested |
| `think` | no plan sections, zero writes | non-spine; lenses `skills/reason/think/references/lenses.md`; hands off to `brainstorm lock`, `to-plan`, or `hunt` |
| `mono` | no plan sections, zero writes | non-spine entry router; playbooks `skills/mono/playbooks/*.md` compose the skills above by name |
