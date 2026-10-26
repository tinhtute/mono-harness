# Playbook: fanout

1. `brainstorm` — frame the wave: the outcome, the shape (partition, race or review panel) and the done predicate; work one agent finishes in the session runs sequentially instead.
2. `work full` — separate before spawning per [work-fanout.md](../../stages/work/references/work-fanout.md): one owner per shared file, shared tooling lands first, one worktree per writer.
3. `work full` — spawn the wave in one message, in the background, an explicit model per role and a full brief each.
4. `work full` — aggregate: a report is a claim; accept only after checking its source, diff and acceptance output; one fresh retry, then `blocked`.
5. `work full` — integrate one branch at a time, edit held shared files after, run the full phase check on the combined tree.
6. `check full` — a verifier on a different model family is recommended; required judges follow the lane.
7. `git` — commit, push or PR only when the owner asks.
8. `handoff` — record Current State; close the plan after a clean final check.

A design bakeoff (several candidates for one artifact) runs `arena` instead of steps 3–5.

## Orchestrate-lite

For a long run of many units, keep the plan as the only state:

- **Standing orders:** a `## Standing Orders` section in the plan holds the rules every worker gets; paste it into every spawn and every retry brief.
- **Rolling window:** at most 10 agents in flight; when one lands or is blocked, spawn the next ready unit.
- **Land as each unit verifies:** merge a unit once its acceptance check passes on its branch, then rerun the phase check before the next merge.
- **Liveness:** read branches, `git status` and the task list; never resume an agent to ask how it is doing.
- **State:** every spawn, retry, `done` and `blocked` is a plan `## Log` entry naming model, branch and SHA. Nothing is kept outside the plan.

Reply: units landed, blocked and pending, with each one's model, branch and SHA.
