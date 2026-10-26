---
name: learn
version: "1.0.0"
description: "Research an unfamiliar domain from primary sources into notes or a publish-ready draft, keeping contradictions visible. Use for deep dives. Not for one-URL lookups (use read)."
argument-hint: "[quick|deep|write|canonical] [topic or source dir]"
compatibility: Designed for Claude Code
---

Support the user's thinking; do not replace it.

## Mode

| Mode | Entry | Exit |
|---|---|---|
| Quick Reference (default when unsure) | Collect | Digest: notes only |
| Deep Research | Collect | Self-review: publish-ready draft |
| Write to Learn (materials supplied) | Outline | Self-review |
| Canonical Article ("one page is enough") | Collect | Self-review, plus worked examples, common mistakes and 3–5 Further Reading picks |

Ask only when two modes would change the deliverable.

## Phases

1. **Collect** — primary sources only: papers, official docs and blogs, builders' posts, reference repos. Three ordered steps:
   - Discover: `read` search maps the landscape, then 2–3 deep searches on the best sub-topics. Output is a URL list.
   - Fetch: every URL through `read`, which owns the cascade, privacy and paywall checks.
   - File: pass `read` the source directory (default: scratchpad `learn/<topic>/sources/`); move, never refetch.
   Target 5–10 sources for a post, 15–20 for a survey.
2. **Digest** — read each source fully; keep a claim only if it recurs in the source, predicts new cases, or is specific to that source rather than generic wisdom. Summarizing is not digesting.
3. **Outline** — every section names its sources; a section without one is cut or sent back to Collect.
4. **Fill in** — section by section; a section that resists writing goes back to Digest for that sub-topic only.
5. **Refine** — edits only: cut repetition, flag broken flow and unexplained terms, then run `write` to strip AI patterns.
6. **Self-review** — the user reads the draft linearly, twice; fix what they mark.

## Hard Rules

- No Fill in before every outline section has a source.
- Contradictions stay visible: state both positions and each one's evidence.
- Every factual claim cites a fetched source URL or file.
- Stop at publish readiness; never post, upload or publish unless asked.

## Output

The mode's exit artifact, its saved path, and a Sources list (URL, tier, one-line why). Prose for conclusions, a diagram only when relationships carry the point.

Defer to: `read` for every search and fetch; `write` for prose polish; `think` when the question is a decision, not a domain.
