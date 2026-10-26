---
name: to-plan
version: "1.4.2"
description: Generate the approach, phases, waves, and checks inside the locked `.harness/plans/active/{slug}.md`. Use after `brainstorm` for a `high-risk` plan; a `normal` plan goes straight to `work`.
argument-hint: "[mode:full|phase] [phase-name?]"
compatibility: Designed for Claude Code
---

Be direct: executable steps, not planning prose.

Resolve the mode, then follow [references/to-plan.md](references/to-plan.md) (`.harness/WORKFLOW.md` IF routing is unclear).

Resolve cross-stage transitions through the host's skill metadata; do not assume a shared installation parent. Resolve data paths from the consumer repository root. If a required skill or reference is unavailable, report the missing dependency and stop; retained legacy playbooks are not a fallback.

Defer to: `work` for a normal plan (lock already wrote its phase); `brainstorm` when the locked input is missing or weak; `work` executes the phase next; `check` gates after implementation.
