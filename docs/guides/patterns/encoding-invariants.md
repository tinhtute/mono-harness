# Encoding Invariants

Convert an accepted architecture, reliability, security, or quality rule into
repository-native validation. The repository remains the system of record; a
check enforces policy but does not create it.

Follow `.harness/WORKFLOW.md` and the host-resolved `handoff` skill's absorb rules before
editing. Do not invent product policy.

## 1. Establish Authority

Locate an accepted document or explicit owner decision that says what must be
true. Record its path and exact rule. Code organization, repeated patterns,
tests, tool defaults, and undocumented preferences are convention; they do not
authorize a new invariant.

Stop before editing when no accepted authority exists or when two materially
different boundaries fit the words.

## 2. Define The Boundary

Write the invariant before choosing a tool:

| Field | Required content |
| --- | --- |
| Authority | Accepted source and exact rule |
| Scope | Files, modules, configuration, or runtime objects covered |
| Allowed | At least one conforming example |
| Forbidden | The precise structure or behavior to reject |
| Exceptions | Only exceptions stated by the same authority |
| Diagnostic | Violating item, broken rule, authority pointer, and next action |

Keep adjacent preferences outside the check.

## 3. Reuse Native Validation

Find this repository's existing validation owner. Typical owners here:

- `bash scripts/ci/test-guards.sh` and `scripts/install-git-hooks.sh` (ZGUARD-CORE)
- `bash scripts/ci/verify-doc-links.sh`
- `cd cli && cargo test`

Implement the smallest deterministic check at the lowest layer that can inspect
the whole accepted scope. Do not add a `zharness` subcommand, a new linter, or a
parallel framework.

Failures must be actionable: violating item, broken rule, authority path, next
action. Avoid bare `validation failed`.

## 4. Prove Both Directions

- **Positive proof:** a known allowed case passes.
- **Negative proof:** a recoverable fixture or test mutation fails for the
  intended rule. Do not leave a violating product file in the tree.

A green suite with no exercised violation does not prove the guard can detect
recurrence.

## 5. Discover And Report Enforcement

Do not install hooks, choose a CI provider, or mutate branch protection as part
of encoding a rule unless the user separately authorizes that.

| Level | What can be claimed |
| --- | --- |
| Local validation | The owning command exists; state whether it was run and passed |
| Optional hook | A convenience entrypoint may run the command |
| CI | A checked-in workflow invokes the command, or none was found |
| Branch protection | Merge blocking verified externally, or unverified |

A green CI job is not proof of merge blocking.

## Handback

1. accepted authority and encoded scope
2. validation owner and smallest check added
3. positive and negative proof with observed results
4. local, hook, CI, and branch-protection levels separately
5. gaps, exceptions, and unverified external enforcement
