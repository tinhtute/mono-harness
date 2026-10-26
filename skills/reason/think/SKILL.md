---
name: think
version: "1.1.0"
model: opus
description: "Reason hard before building: attack premises, run named thinking lenses, compare real alternatives, give one verdict. Use for design choices, is-it-worth-it, triaging asks. Not for bugs."
argument-hint: "[decide|evaluate|triage|twice|lens <name>] [question, idea, @file refs]"
compatibility: Designed for Claude Code
---

# Think: Reason Before You Build

## Outcome Contract

- Outcome: a rough question becomes one defensible recommendation whose weakest assumption is named.
- Done when: the goal, constraints, chosen direction, the rejected alternative and why, the most fragile assumption, and the next step are stated; nothing load-bearing is silently assumed.
- Evidence: repo state, docs and ADRs under `docs/decisions/`, live config values, primary-source docs, and explicit user preferences. Memory is a lead to re-verify, never evidence.
- Writes: **none** — no code, plan, or report. Keep a result via `brainstorm lock`; an approved build goes to `to-plan` or `work`.

## Modes

Resolve from a leading subcommand, else the request.

| Mode | Activate when | Do |
|---|---|---|
| `decide` (default) | "how should I", "which approach", design choice | The Process below |
| `evaluate` | "is it worth it", "keep/remove X", "có nên làm không", commercial or pivot judgment | `references/mode-evaluation.md`: one Kill/Keep/Pivot verdict |
| `triage` | 3+ independent unbuilt asks or screenshots | `references/mode-triage.md`: per-item bucket table |
| `twice` | Interface, module, or data-model shape | `references/design-it-twice.md`: 3+ radically different designs |
| `lens <name>` | A named pattern ("pre-mortem this") | That lens only, from `references/lenses.md` |

An error, crash, failing test, or "why is this broken" → one line: it belongs to `hunt`; route there. Fuzzy intent → `brainstorm grill`.

## Process (`decide`)

1. **Frame.** The decision in one sentence and what "good" means (success signal, constraints, who pays the cost). Sources conflict, or two readings cost differently → name the conflict and ask which wins; never silently pick.
2. **Ground before opining.** Read `AGENTS.md`/`CLAUDE.md` and only the matching rule or ADR. Open the real config for any default, env var, or setting the answer depends on; never quote one from memory. Separate facts from decisions: find facts yourself (repo, docs, sub-agents for wide searches); put only decisions to the user.
3. **Official and proven first.** Check built-ins and ecosystem standards in live primary docs; the official solution wins unless you can say why it falls short. For a hard or repeatedly-tuned problem, study 2–3 mature projects and name what you take from each.
4. **Generate real alternatives.** Genuinely different, not variations, beside the brute-force option (simplicity-gate). Interface shape is the crux → switch to `twice`.
5. **Run the lenses.** Pick 3–5 that fit from `references/lenses.md`; its Core four almost always apply (e.g. **attack angles** for external dependencies, scale, data migration; **deletion test**, **depth/seam** for module design; **entity delta** when the plan adds settings, flags, commands, or services). One sentence per lens finding; nothing found → one line.
6. **Deform or discard.** A lens finds a hole → change the design to survive it; it shatters the approach → drop it and say why. Never hide a failed lens.
7. **Recommend.** One direction: effort, risk, and the existing code it builds on. Name one alternative only if the call is close (>40% the user would prefer it).

A question only running something can settle (does this state model feel right?) → recommend a throwaway prototype answering exactly that; building it needs the user's go-ahead. A reversible call inside the approved scope is decided and reported, not asked.

## Grill-lite

Decisions only the user can make → `references/grill-lite.md`.

## Hard Rules

- **No placeholders.** "To be decided", "details later", "similar to step N" mean the thinking is unfinished.
- **Zero-setup default.** Anything every user must install or configure (hook, MCP server, config key, new runtime or language) first says why a built-in or fixed default cannot do the job. A second language or runtime in a single-stack project needs explicit approval.
- **Phases stand alone.** After phase N ships, the system works even if N+1 never lands; "Phase 0: investigate" belongs in this thinking, not the plan.

## Gotchas

- Design rejected → ask what specifically failed; re-enter with narrowed constraints, never from scratch.
- A rework that would remove the product's differentiator → check docs for a deliberate choice; deliberate → Keep.

## Output

```
Verdict:        [one recommended direction, one sentence]
Why:            [2–3 reasons tied to this user's constraints, not generic trade-offs]
Rejected:       [the closest alternative and why it lost]  (omit if none was close)
Assumes:        [most fragile assumption → what happens if it fails]
Lenses:         [lens → finding, one line each]
Open:           [decisions only the user can make, as a frontier]  or  [none]
Next:           [the one concrete step: brainstorm lock / to-plan / work bounded / prototype / hunt]
```

`evaluate` and `triage` use their reference's format instead. Keep prose short; the block is the answer.

Defer to: `brainstorm` (grill, lock), `to-plan` (locked plan), `hunt` (errors, regressions), `check` (built code).
