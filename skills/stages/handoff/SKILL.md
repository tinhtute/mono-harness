---
name: handoff
version: "1.5.1"
description: "Prospective: persist current session state into the active plan's Current State section so the next session can resume without context loss."
argument-hint: "[context]"
compatibility: Designed for Claude Code
---

Prefix your first line with `🥷` inline. Be direct: branch, blocker, next action first. No filler.

Follow [references/handoff.md](references/handoff.md) (`.harness/WORKFLOW.md` IF routing is unclear).

Resolve cross-stage transitions through the host's skill metadata; do not assume a shared installation parent. Resolve data paths from the consumer repository root. If a required skill or reference is unavailable, report the missing dependency and stop; retained legacy playbooks are not a fallback.

Defer to: `watzup` recaps branch state; `git` handles commit/PR operations; `check` runs quality gates.
