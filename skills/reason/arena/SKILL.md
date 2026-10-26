---
name: arena
version: "1.0.0"
description: "Design bakeoff: sub-agents build one artifact several ways, a rubric picks the base, the best parts of the rest are grafted on. Use when the right design is unclear."
argument-hint: "[artifact to design] [runners and models]"
compatibility: Designed for Claude Code
---

# Arena: Build It Several Ways, Keep the Best

Prefix your first line with `🥷` inline. Verdict first: the winning base and what was grafted onto it.

## Outcome Contract

- Outcome: one artifact built from the strongest candidate, improved with the best parts of the others.
- Done when: every candidate is scored on the same rubric, the base and each graft are named with the rubric point they win, and the merged artifact passes its check.
- Evidence: each candidate's output path, the score table, the judge's pick, and the final check output.
- Writes: candidates go to scratch paths outside the repo; only the merged artifact lands in the repo.

## Process

1. **Frame.** Name the artifact, a 3–6 point rubric, the runners (2–4) and each runner's model, and one output location per runner. Mixing model families widens the spread.
2. **Fan out.** Spawn every runner in one message, in the background, on an identical brief built per `work` [work-fanout.md](../../stages/work/references/work-fanout.md); only the output path differs.
3. **Cross-judge.** Score each candidate yourself, then ask a judge for its pick and reasons; a judge on a different model family from the runners is recommended.
4. **Pick a base.** The highest rubric total wins; on a tie, the simpler candidate.
5. **Graft by hand.** Copy the best part of each loser into the base, one rubric point at a time; never merge whole candidates.
6. **Verify.** Run the artifact's check on the merged result.

Candidates that diverge wildly mean the brief was under-specified: reframe the rubric or the brief and re-run; never average them.

## Output

```
Base:     [runner, model, total score]
Grafts:   [from runner → part, rubric point it wins]
Scores:   [table: runner × rubric point]
Judge:    [pick, model, one-line reason]
Check:    [command and result]
```

Defer to: `work` (fan-out core and integration), `think` (when the question is a decision, not an artifact), `check` (gating the merged result).
