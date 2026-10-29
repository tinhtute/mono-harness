# Playbook: ship

Optional add-on, outside the core lifecycle: the lifecycle (`brainstorm` → `work` → `check` → `git`) ends at a commit or an opened PR, and "ship" here means landing verified PRs and then tagging, publishing, or deploying (see [SDLC Stage Coverage](../../stages/README.md#sdlc-stage-coverage)). `work`, `check`, and `git` never release on their own. Tag, publish and deploy run only on the owner's explicit request. Merging a PR runs on request too, with one carve-out: the [land](#land) step merges a PR on its own when it judges it low risk and `AGENTS.md` § Unattended Shipping says `Auto-merge: low-risk`.

## Stacked or not

Git/PR workflow and release are separate: opening, stacking, and merging PRs is `git`; steps 7-10 (changelog, tag, delivery check, rollback) are the release. Stack PRs only when one of these holds:

- a later change needs code from an earlier PR that is not merged yet (dependency ordering);
- the layers are independently reviewable, for example a schema migration, then the API, then the UI;
- parallel work must proceed on top of an unmerged base.

Otherwise do not stack: one bounded change is one branch and one PR, and no extra branch or PR exists only for ceremony. Independent small changes each get their own PR from the base branch, or land as one PR when they are one change.

- Small change: a README typo fix is one branch and one PR; run `check` and `git`, then step 6 for that PR.
- Dependent sequence: PR 1 adds a database column, PR 2 (based on PR 1) reads it in the API, PR 3 (based on PR 2) shows it in the UI; each is reviewed on its own diff and landed bottom-up per steps 3-6.

In the steps below, "bottom of the stack" and "contiguous run" collapse to the single PR when nothing is stacked.

## Steps

1. `watzup` — list commits since the last published tag (the tag is the baseline, not a local version file); verdict release / skip, bump patch (fixes) / minor (feat) / major (breaking), and the key risk in one sentence.
2. `security-review` (Claude Code built-in) — the diff since that tag; a high-severity finding blocks the release until fixed or explicitly waived by the owner.
3. `check full` — per PR, bottom of the stack first: record its verdict with the head SHA it covers. Also check every shipped surface: CLI `--help` and version output, install path, migrations, config defaults.
4. Land only the contiguous verified run from the bottom: stop at the first PR without a pass; a verified PR above it waits.
5. Re-check each verdict still describes the code: `git patch-id` at the verdict SHA equals the current head's, otherwise re-run step 3 for that PR.
6. `git` — merge bottom-up, one PR at a time, guarded by the verified head: `gh pr merge <n> --<method> --match-head-commit <sha>`, `<method>` from `AGENTS.md` § Unattended Shipping `Merge method` (default `squash`); confirm the base right before. Touch no branch or base while the run lands.
7. `write` — CHANGELOG entry and release notes from the commit list; breaking changes first, each with its migration step.
8. `git` — bump the version, commit, tag and push; never force-push a published tag.
9. Verify the delivery: the release CI run passes, the artifact or deploy is reachable, and its version output matches the tag.
10. Name the rollback before closing: the previous tag, and the exact revert or redeploy command.

## Land

Run on any green PR, or when asked to land one; it replaces steps 3–6 for a single PR outside a release.

1. Preconditions: `gh pr view <n> --json mergeable,headRefOid,baseRefName` is `MERGEABLE`; `gh pr checks <n> --watch --interval 30` passes (cap 60 min); no unresolved review thread. Any fails → stop, report the blocker.
2. Judge the risk on the head SHA per [check-risk.md](../../stages/check/references/check-risk.md): one independent fresh-context judge returns the `## Risk` section.
3. Write it into the PR body through a file: `gh pr view <n> --json body --jq .body > "$f"`, replace or append `## Risk`, `gh pr edit <n> --body-file "$f"`.
4. Head moved since step 1 → the verdict is stale; start over once, moved again → stop.
5. Act:
   - low risk and `Auto-merge: low-risk` in `git show origin/<base>:AGENTS.md` (the base's copy; a PR cannot opt itself in) → `gh pr merge <n> --merge --delete-branch --match-head-commit <sha>` (never `--auto`), confirm `state` is `MERGED`, print the Merged Message from check-risk.md;
   - low risk without the opt-in → report `merge-ready` with the verdict;
   - needs review → print the review line and **Where to look** items; never merge.

Reply: the `## Risk` verdict block, then the Merged Message or the review line.

Reply (release): the verdict and version, each PR's verdict SHA and how it landed, the security result, the release URL or deploy evidence, and the rollback command.
