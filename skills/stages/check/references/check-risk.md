# Risk Verdict

Decides whether a green PR needs a person. Used by the land step of the `mono` ship playbook (`skills/mono/playbooks/ship.md` § Land). The change sets the tier, not the author: the verdict reads the diff at one commit, never the plan's declared lane.

## Checks

Run this skill's `scripts/risk-facts.sh "origin/$BASE" "$SHA"` from the repository root. It diffs the judged commit against the merge base, reads the always-review globs from the base branch's `AGENTS.md`, and prints the mechanical facts as JSON; its header defines each field. Exit 2 means a bad argument, unknown ref, or no merge base: fix it and rerun; a verdict needs the facts. Any hit below means **needs-review**.

| Check | Needs review when |
|---|---|
| Size | `counted_lines` > 400 (docs, tests, generated files and lockfiles already excluded) |
| Always-review paths | `always_review_hits` is non-empty, `ci_config_touched` or `manifest_or_lockfile_touched` is `true`, or the diff adds or changes a migration or schema |
| Tests | `test_changes.removed_files` or `test_changes.skip_markers_added` is non-empty, or the diff removes a test case, removes or loosens an assertion, or changes an expected value to match new output without a stated reason |
| Exercise | the PR body's `## Exercised` section reports `wrong:` |
| Plan | the diff does something the PR's plan or Goal did not set out to do, or omits a planned phase, without saying so in the PR body |

## Judgment Test

When no check hits, the verdict is **low risk** only if the judge can name what the checks would miss in this diff and why a person reading it would not catch more: a behavior change hidden in a small diff, a public contract, data written in a new shape, a path nothing exercised. Cannot name it, or what it names needs a person → **needs-review**. Doubt means review.

## Judge

One fresh-context sub-agent judges; the session that wrote the code is the worst judge of its risk. Brief it with the PR number, `$SHA`, `$BASE`, this file, the absolute path of `scripts/risk-facts.sh` (or its JSON output), and `AGENTS.md` § Unattended Shipping read from the base (`git show origin/$BASE:AGENTS.md`, never the PR's own copy), and ask for the filled `## Risk` section and nothing else. With no sub-agents available, judge from this rubric alone and record `judge: same-session`; a same-session verdict is never low risk.

## Risk Section

Written into the PR body, replacing any earlier `## Risk` section:

```markdown
## Risk

**Verdict:** low risk | needs review, judged on <full SHA> (judge: independent | same-session)

- Size: <counted_lines> counted lines (<excluded_lines> excluded) → ok | over 400
- Always-review paths: none | <always_review_hits, CI config, manifest or lockfile, migration or schema>
- Tests: ok | <what was deleted or weakened>
- Exercise: ok | not exercised: <why> | wrong: <what>
- Plan: ok | no plan | <unstated deviation>
- What the checks would miss: <one or two sentences>

**Where to look** (needs review only)
- `<file>:<line>`: <the question the reviewer should answer>

**Revert:** <only when a plain `git revert` is not enough>
```

Two to five **Where to look** items, each a place and a question, never a summary of the change.

## Merged Message

After a merge, print exactly:

```text
✅ Merged #<n> <title>
   <base> ← <short merged SHA> · low risk, judged on <short SHA> · CI green
   Revert: git revert -m 1 <merged SHA>   # or the Revert line above
```

Needs review instead prints `🔎 Review #<n>: needs review on <short SHA>` followed by the **Where to look** items.
