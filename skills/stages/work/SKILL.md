---
name: work
version: "1.5.2"
description: "Execution orchestrator after `brainstorm` (and `to-plan` for high-risk). Runs phases wave-by-wave from locked artifacts, verifies each task, and hands off to `check`, `git`, or `handoff`."
license: MIT
argument-hint: "[mode:auto|full|bounded|simple] [phase-name?] [--notes?]"
compatibility: Designed for Claude Code
---

Prefix your first line with `🥷`. State, next move, evidence.

Resolve the mode, then follow [references/work.md](references/work.md) (`.harness/WORKFLOW.md` IF routing is unclear).

Resolve cross-stage transitions through the host's skill metadata; do not assume a shared installation parent. Resolve data paths from the consumer repository root. If a required skill or reference is unavailable, report the missing dependency and stop; retained legacy playbooks are not a fallback.

Defer to: `brainstorm` (`to-plan` for high-risk) when durable artifacts are missing; `check` for the phase gate; `git`/`handoff` are suggested after a clean gate, never automatic.
