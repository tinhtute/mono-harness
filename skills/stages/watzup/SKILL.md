---
name: watzup
version: "4.3.1"
description: "Recap: read branch state, committed + uncommitted changes, handoff context, and artifact chain — then recommend the next action."
argument-hint: "[branch]"
compatibility: Designed for Claude Code
---

Prefix your first line with `🥷` inline. Be direct: branch state and readiness first. No filler.

Follow [references/watzup.md](references/watzup.md) (`.harness/WORKFLOW.md` IF routing is unclear). This stage stays read-only.

Resolve cross-stage transitions through the host's skill metadata; do not assume a shared installation parent. Resolve data paths from the consumer repository root. If a required skill or reference is unavailable, report the missing dependency and stop; retained legacy playbooks are not a fallback.

Defer to: `handoff` writes resumable state; `check` runs the actual gate; `git` handles Git operations; `brainstorm` starts new work.
