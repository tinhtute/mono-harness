# Playbook: ambition

Writes only the rewritten prompt; no code change, plan or commit until the owner picks a route.

1. `ambition` — pick the lens (depth by default) and rewrite the task with one labeled line per slot.
2. `ambition` — run `scripts/lint-prompt.sh --lens <lens>` on the rewrite until it prints `ok`.
3. The owner says run → route the rewrite to `feature`, `research`, or `fanout` (range with one field per sub-agent); else stop.

Reply: the field and expert moves, the rewrite in one fenced block, the lint result, and the suggested route.
