# Risk Verdict

Decides whether a green PR needs a person. Used by the land step of the `mono` ship playbook (`skills/mono/playbooks/ship.md` § Land). The change sets the tier, not the author: the verdict reads the diff at one commit, never the plan's declared lane.

## Checks

Measure on the judged commit against the merge base: `git diff --numstat "origin/$BASE...$SHA"`. Any hit means **needs-review**.

| Check | Needs review when |
|---|---|
| Size | more than 400 changed lines (added plus deleted), not counting docs, tests, generated files and lockfiles |
| Always-review paths | the diff touches a path in `AGENTS.md` § Unattended Shipping `Always-review paths`, any CI configuration, a dependency manifest or lockfile, or a migration or schema |
| Tests | a test file or case removed, an assertion removed or loosened, a skip or ignore marker added, or an expected value changed to match new output without a stated reason |
| Exercise | the PR body's `## Exercised` section reports `wrong:` |
| Plan | the diff does something the PR's plan or Goal did not set out to do, or omits a planned phase, without saying so in the PR body |

## Judgment Test

When no check hits, the verdict is **low risk** only if the judge can name what the checks would miss in this diff and why a person reading it would not catch more: a behavior change hidden in a small diff, a public contract, data written in a new shape, a path nothing exercised. Cannot name it, or what it names needs a person → **needs-review**. Doubt means review.

## Judge

One fresh-context sub-agent judges; the session that wrote the code is the worst judge of its risk. Brief it with the PR number, `$SHA`, `$BASE`, this file, and `AGENTS.md` § Unattended Shipping, and ask for the filled `## Risk` section and nothing else. With no sub-agents available, judge from this rubric alone and record `judge: same-session`; a same-session verdict is never low risk.

## Risk Section

Written into the PR body, replacing any earlier `## Risk` section:

```markdown
## Risk

**Verdict:** low risk | needs review, judged on <full SHA> (judge: independent | same-session)

- Size: <n> counted lines (<n> excluded) → ok | over 400
- Always-review paths: none | <paths>
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
