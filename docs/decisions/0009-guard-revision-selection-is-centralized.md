# 0009 — One revision selector for every guard; completed plans are validated like active ones

## Status

Accepted. 2026-09-08. Authority for F02, F03, and F08 in
`git show 3bab3c0:docs/plans/completed/audit-integrity-remediation.md`. Extends guard-v3 coverage;
it does not change any verdict semantics.

## Context

The 2026-09-07 integrity audit reported three findings against the fail-closed
guards. They are one defect: **each call site picks its own git revision and its
own path namespace, ad hoc.**

- The pre-commit hook reads staged blobs for the Validation-entry guard
  (`install-git-hooks.sh:328`) but globs the working tree for the single-active-plan
  guard (`:207`). Two nonempty plans can be staged while one worktree copy is
  truncated, and the commit is accepted (F08).
- Both the hook and CI select `docs/plans/active/*.md` for the entry guard
  (`install-git-hooks.sh:328`, `cli-ci.yml:71`). A plan closing out — created
  directly under `completed/`, or `git mv`d there with its final proof changed —
  reaches only `zharness_guard_completed_plan_phases_done`, which checks phase
  consistency and never executes a proof or requires a judge. The evidence that
  justifies closing an initiative is the evidence least likely to be checked
  (F02).
- CI checks out with `fetch-depth: 2` and diffs `HEAD~1 HEAD` (`cli-ci.yml:71,77`).
  A push of two commits validates only the tip: an unverified plan entry in the
  first commit lands clean if the second commit touches something else (F03).

This sits under the README goal *Invariants enforced, not assumed*. A guard that
runs against the wrong revision is not a weaker guard; it is a guard that
reports success about a state nobody is shipping.

## Decision

**1. `zharness_guard_revspec` is the single source of the revision under test.**
A new function inside the `ZGUARD-CORE` block takes an event
(`staged`, `push`, `pr`) and emits the base and head to diff:

- `staged` → the index. Every guard, including the plan count, reads blobs via
  `git show :<path>`, never the working tree.
- `push` → `$GITHUB_EVENT_BEFORE..$GITHUB_SHA`. An all-zero or unreachable
  `before` (first push, force-push, shallow clone) falls back to the merge base
  with the default branch, and when that is also unavailable the guard **fails
  closed** with a message naming the missing history rather than passing.
- `pr` → `merge-base(base_ref, head_sha)..head_sha`.

Every guard call site consumes this function. No call site computes `HEAD~1`.

**2. Completed plans go through the entry guard.** The selector widens to both
namespaces, and rename detection (`--diff-filter=ACMR -M`) resolves a
`active/ → completed/` move to its destination path so the closing plan's final
Validation entries are proof-executed and judge-checked. The phase-consistency
guard still runs; it is an addition to evidence validation, never a substitute
for it.

**3. The worktree check becomes advisory, not gating.** Counting nonempty files
under `docs/plans/active/` is still useful feedback while working, but it does
not decide a commit. Gating reads the index.

**4. CI fetches enough history to honour the spec.** `fetch-depth: 0` on the
guard job. A guard cannot select a base it did not fetch.

## Consequences

- A push whose earlier commit carries a failing proof is now rejected, where it
  previously passed. This is the intended behavior change and it can reject
  history that already landed on `master`; the first run after this ships may
  fail on pre-existing commits and must be reconciled deliberately, not by
  weakening the selector.
- Closing a plan now re-executes its final proofs. A plan whose closing entry
  cites a machine-local or non-reproducible command will be rejected at
  completion instead of silently accepted — the same failure mode
  `docs/plans/completed/macos-guard-portability.md` already recorded for active
  plans, now reaching the moment of closure too.
- A shallow or first-push CI run with no resolvable base fails closed. This is a
  deliberate choice against the alternative — passing when the guard cannot see
  what it is guarding.
- An endpoint diff still cannot detect an entry introduced and removed inside
  the same push range. That limit is documented, not closed here; closing it
  requires per-commit iteration, which is deferred.
- No change to which entries count as visible, which verdicts anchor, or the
  independent-judge rule. Guard-v3 semantics are untouched.

## Authority

- `git show 3bab3c0:docs/audit/2026-09-07-integrity-review.md` — F02, F03, F08, and the finding
  that most guard defects live between the policy, syntax, and execution layers
  rather than inside any one of them.
- `README.md` — *Invariants enforced, not assumed*.
- `scripts/install-git-hooks.sh` — the `ZGUARD-CORE` block is the authoritative
  guard implementation; `scripts/test-guards.sh` extracts it verbatim, so the
  change lives inside the BEGIN/END markers.
- `git show 3bab3c0:docs/plans/completed/macos-guard-portability.md` — R2, establishing that
  guard changes belong inside ZGUARD-CORE so the code under test is the code
  that runs.
