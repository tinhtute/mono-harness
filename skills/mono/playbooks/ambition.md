# Playbook: ambition

Target: a task, a prompt, or an existing feature to rework deeper (a path, PR or plan). Writes the rewrite, then whatever the owner's chosen route writes.

1. `ambition` — pick the lens (depth by default); for an existing feature, read its code, tests and history as `Raw:` and its current tests as the floor for `Judge:`.
2. `ambition` — run `scripts/lint-prompt.sh --lens <lens>` on the rewrite until it prints `ok`.
3. The owner picks the route: run now → `feature`, `research`, or `fanout` (range, one field per sub-agent); rework in a new session → `brainstorm lock` the rewrite as the Goal of `.harness/plans/active/{slug}.md`, then `handoff`; else stop.

Reply: the field and expert moves, the rewrite in one fenced block, the lint result, and the route taken (plan path when handed off).
