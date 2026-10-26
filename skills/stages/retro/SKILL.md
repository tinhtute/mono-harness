---
name: retro
model: opus
description: "Session retrospective: evidence-cited, severity-ranked findings about the agent's environment, then one user-approved fix — a guard or a rerun-gated experiment. Invoke only from a mono playbook step or when the user asks for it by name."
---

Be direct: the top finding and its evidence first.

Follow `references/retro.md` — it holds this skill's operating logic, including the digest script and the approval gate before any edit. A missing `zharness` binary is never a reason to stop.

Defer to: `work` when the fix grows into a locked initiative; `handoff` absorb when closing a plan.
