---
name: ambition
version: "1.0.0"
description: "Rewrite a task so it is done to a field-leading standard through one lens (depth, altitude, range), then lint the rewrite for raw material, instruments, a refutable assumption and an outside judge. Use for 'be ambitious', 'make this deeper', 'what would an expert do'."
argument-hint: "[depth|altitude|range] [task or prompt]"
compatibility: Designed for Claude Code
---

# Ambition: Same Goal, Higher Bar

## Outcome Contract

- Outcome: one rewritten prompt the user can copy, held to the standard a field-leading expert would use.
- Done when: `scripts/lint-prompt.sh --lens <lens>` exits 0 on the rewrite.
- Authorization: rewrite only. Run the task only when the user says so.

## Lens

Resolve from a leading subcommand, else the request.

| Lens | Use when | Read |
|---|---|---|
| `depth` (default) | Do this task really well | `references/depth.md` |
| `altitude` | The task is one step toward an outcome the user named | `references/altitude.md` |
| `range` | The work needs fields beyond the obvious one | `references/range.md` |

Depth keeps the goal and scope; drop any suggestion that makes the job bigger rather than better. Altitude and range may widen it, so state the widening in one line and let the user choose.

## Steps

1. Take the task after the subcommand, else the most recent request; none → ask for it in one line and stop.
2. Name the field, then fill each slot from the lens reference with the actual thing, not the category. Unknown → say so; never invent a source or tool.
3. Write the rewrite in the user's voice with one labeled line per slot (`Field:`, `Raw:`, `Instruments:`, `Assumption:`, `Judge:`, `Pass:`, `Fail:`, plus the lens extras).
4. Pipe it to `scripts/lint-prompt.sh --lens <lens>`. Each `fail:` line names a slot to make concrete; fix and re-run until `ok`. A pass proves the slots are filled, not that they are right.

## Output

The field, one line per expert move, then the rewrite in a single fenced block and the lint result. Offer in one line to run it; on yes, route through `mono`.

Defer to: `prompt-leverage` (clarity and structure, no higher bar), `think` (whether the task is worth doing), `brainstorm` (scope and plan).
