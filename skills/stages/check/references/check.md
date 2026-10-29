# Playbook: check

Durable `gate` runs automated checks and records the verdict in `## Validation`; `work` runs it after every phase. `full` includes the gate and adds the complete Security, Performance, Architecture, and Code Quality review, once, on the final phase of a plan whose lane requires it.

## Lane Matrix

This table is the single source of truth for lane → proof, review depth, and judge. The commit-time guard (`setup/install-git-hooks.sh`, R3/R4) and `scripts/ci/test-guards.sh` read the same rows; change all three together. The guard applies the rows at the effective lane: a diff that touches an always-review path from [check-risk.md](check-risk.md) raises the declared lane to `high-risk` (R6).

| Lane | Required proof | Final check mode | Review depth | Judge |
|---|---|---|---|---|
| `tiny` | `output` | `bounded` | scoped review of the diff | `same-session` allowed |
| `normal` | `output`, `unit` | `gate` | automated gate and plan alignment; no manual review | `same-session` allowed |
| `high-risk` | `output`, `unit`, `integration` | `full` | complete four-area review | `independent` |

Whether a green PR needs a person is a separate, commit-bound verdict: [check-risk.md](check-risk.md).

**Final check mode rule:** `full` IF the plan's lane is `high-risk` or the owner explicitly invoked `check full`; else the lane's mode above. A plan's existence or its phase count never selects `full`. Report the rule as the reason: `mode: full (lane high-risk)`, `mode: full (explicit)`, `mode: gate (lane normal, final phase)`.

## Preconditions and Modes

1. Preserve invocation intent:
   - `auto` (default) — a direct change → resolve to `bounded` without reading any plan; a named durable initiative → `gate`, and invalid initiative state never falls back to `bounded`. Ambiguous → ask. `auto` never resolves to `full`, and an active plan's mere existence never selects `gate`.
   - `gate`, `full` (never run by `work`), `bounded` (aliases: `simple`, `review`).
2. Durable → read [check-durable.md](check-durable.md) now.
3. After the preflight succeeds, print the resolved mode before running checks or writing state: `mode: {resolved} ({reason})`. A failed preflight reports its blocker instead.

**Zero-write rule:** `bounded` is always response-only and never appends to Validation. Invocation intent wins: an active plan never upgrades `bounded`.

## Steps

1. **Load scope** — the diff and verification commands; gate/full also the phase and the `## Log`/`## Validation` tails.
2. **Classify** — depth by blast radius; scope on target, drift, or incomplete (a surface violation blocks a clean verdict).
3. **Run the automated gate** — tests, types, lint, build, in repository order. IF `scripts/workflow/record-check.sh` exists → `bash scripts/workflow/record-check.sh -- "cmd1" "cmd2"`; else keep each exit code (never let a pipe hide it). Cite the raw commands.
4. **Plan alignment** (gate/full) — `check-durable.md` step 4.
5. **Manual review** — `gate` does not perform manual review; the gate, plan alignment, and proof classes are its whole check. `full`, or `bounded` on a diff: read [check-review.md](check-review.md) now.
6. **Proof classes** — the lane's required proof from the Lane Matrix; record the classes you proved in the entry's `proof_classes:` line. A missing class blocks an approvable verdict: name it in `proof_gaps:`. A runtime change's `output` proof is its exercise: read [check-exercise.md](check-exercise.md).
7. **Verdict** — critical issue or plan contradiction → `REQUEST_CHANGES`; major findings → at least `APPROVE_WITH_REQUESTS`; else `APPROVED`. Declare the judge (`same-session` IF you authored the diff, else `independent`) and the model. A `same-session` approval names one aspect not independently verified. `full` and `high-risk` require `judge: independent` (Lane Matrix).
8. **Evidence and plan state** (gate/full) — `check-durable.md` steps 8–11.

## Output Format

```text
mode: gate | full | bounded
depth: quick | standard | deep
scope: on target | drift | incomplete
gate: pass | fail
verdict: APPROVED | APPROVE_WITH_REQUESTS | REQUEST_CHANGES
judge: independent | same-session (judge_model: {model identifier})
enforcement: hook | ci | local-only
verification: exact command -> pass | fail | not-run
proof_gaps: none | exact missing classes
```
