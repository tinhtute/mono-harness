# Playbook: work (fan-out)

Loaded by [work-full.md](work-full.md) step 4 when a wave runs tasks on sub-agents. The main agent owns every worker's output: it frames, briefs, integrates and verifies; workers never merge, rebase, or edit outside their scope.

## When to fan out

- Only tasks the plan marks independent. Work one agent finishes in the session runs sequentially; prefer fewer, broader workers over many thin ones.
- Shape: **partition** (disjoint slices, all required), **race** (N workers on one identical brief; declare `first pass`, `rank all` or `best-of` before spawning), or **review panel** (read-only reviewers on one diff).
- State the done predicate for the wave before spawning: what each worker returns and what the combined tree must pass.

## Separate before spawning

Instructions are not concurrency control; a fence in the brief's prose is not a lock.

1. List each task's write set from its `owner:` scope, then grep the files each task will edit (docs that cite moved paths, CI workflows, `AGENTS.md`, contracts, ignore lists).
2. Any file in two write sets → give it one owner, or hold it for the main agent after the merge. Never let two workers edit one file.
3. A task that moves or rewrites shared tooling (git hooks, scripts a hook or CI calls, installers) lands first; reinstall the hook before spawning the rest, or every other worktree's commit breaks.
4. Each writer gets its own worktree or branch; read-only workers get their own scratch output path outside the repo.

## Models per role

Pass `model` explicitly on every dispatch and name it in the brief; never rely on the parent default. On Claude Code with the setup installed, dispatch the role's agent instead of `general-purpose` so the role and model show in the agent list: `worker` (`sonnet`), `lead` (`opus`), `verifier` (`fable`, read-only), `test-runner` (`haiku`, read-only: runs a suite and returns only failures). `setup/models.json` is the policy for these; `scripts/ci/test-agent-models.sh` fails when an agent's `model:` disagrees with it.

| Role | Model |
|---|---|
| Mechanical edits (moves, renames, link fixes) | fast tier (e.g. `sonnet`, `haiku`) |
| Ordinary implementation | the session's default tier |
| Cross-cutting design, concurrency, subtle algorithms | strongest-judgment tier |
| Verifier, judge, cross-review | a different model family from the worker |

The owner's named model wins over this table. Evidence of the model that ran is the dispatch parameter and the sub-agent transcript's assistant `model` field; harness entries such as an advisor attachment are not the worker's model.

## The brief

Pointers, not copies. A field you cannot fill is a task not yet scoped; do not spawn it.

```
GOAL       one sentence a stranger with no chat access can execute
SCOPE      paths it may write; paths it may not; its worktree or branch
CONTEXT    plan path + phase/task id, files to read, upstream reports pasted in full
ACCEPTANCE checkable criteria, one per line
VERIFY     the exact check command, plus known gotchas (hook path, commit-msg format)
TIMEBOX    a time budget; on expiry return partial findings and stop
FORBIDDEN  no merge, rebase, force-push, --no-verify, or fixes outside SCOPE
REPORT     PASS | ISSUES | BLOCKED; branch, commit SHA (or dirty-diff hash), the commands actually run and their output, deviations
```

Size it to the task: a one-command task collapses the template to a paragraph that still names goal, scope, check and report. Shared exploration runs once into a scratch file outside the repo, and briefs point at it.

## Fan out

Spawn the whole wave in one message, in the background, each with its own worktree. Never resume a worker to check on it; read its branch, `git status`, or the task list. A worker that will not be reused is stopped, and its stop confirmed.

## Aggregate

1. A report is a claim: reject it unless it names the tested source and the acceptance output.
2. Accept only after checking that source, its diff against SCOPE, and its acceptance check yourself.
3. A rejected or missing result gets one fresh worker with consolidated scope (the original brief, later directives, the prior report and branch). A second miss → log `blocked` and plan around it; a gap never counts as a pass.
4. Race: apply the rule declared up front. For a design bakeoff, score each candidate against a 3–6 point rubric, ask a cross-family judge for its pick, choose one base, and graft the best part of each loser by hand; wild divergence means the brief was under-specified, so reframe and re-run rather than averaging.

## Integrate

1. Merge accepted branches one at a time; resolve conflicts against the plan, never by taking one side blindly.
2. Edit the held shared files once, after the merges.
3. Review the shared interfaces, then run the full phase check on the combined tree.
4. `high-risk` phases: a verifier on a different model family from the workers reviews the combined diff before the gate.
5. Each `done` names the worker's model, branch and commit SHA. Removing worker worktrees and branches is a delete: do it only with the owner's approval.
