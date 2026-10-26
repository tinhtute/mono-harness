---
name: hunt
version: "1.1.0"
model: opus
description: "Find the root cause before any fix: build a red-capable repro loop, rank falsifiable hypotheses, prove, fix, sweep siblings. Also triages bug issues/PRs. Use on errors, crashes, regressions."
argument-hint: "[diagnose|fix|bisect|regression|sweep|triage] [symptom, error, issue/PR ref]"
compatibility: Designed for Claude Code
---

# Hunt: Diagnose Before You Fix

## Outcome Contract

- Outcome: the root cause is proven before any fix.
- Done when: one sentence explains the cause, every observed symptom fits it, and the fix (or handoff) is verified by the same loop that reproduced the bug.
- Evidence: loop command and output, source trace, logs or state, targeted test/build output, runtime evidence for UI/native defects.
- Authorization: "diagnose", "investigate", "why", "look into", "debug", "xem thử", "sao lỗi" is report-only. Edit code only on a request to fix, change, or implement, or while that authorization holds for the same unfinished task; never covers commit, push, publish, or anything destructive.

**Do not touch code until you can write:**
> "I believe the root cause is [X at file:line / condition] because [evidence]."

Not "a state management issue" but "stale cache in `useUser` at `src/hooks/user.ts:42` because the dependency array omits `userId`". Less specific → no hypothesis yet.

## Modes

Resolve from a leading subcommand, else the request.

| Mode | Activate when | Does |
|---|---|---|
| `diagnose` (default) | Error, crash, test failure, "not working", "why" | Steps 1–4, report only |
| `fix` | "fix it", "sửa đi" | Full loop, steps 1–7 |
| `bisect` | "used to work", "broke after update", a known-good commit or version | Step 1 is a bisect harness; read `references/bisect-regression.md` |
| `regression` | Same issue after a fix, or a "good" screenshot/version/file to compare | The reference is the oracle; read `references/bisect-regression.md` |
| `sweep` | After a root-cause fix, "anywhere else like this?", "còn chỗ nào giống vậy không" | Step 6 only, on a named pattern; read `references/fix.md` |
| `triage` | Issue/PR queue, "look at #42", "what needs my attention", label/close/brief | `references/triage.md` replaces steps 2–7; its bug check reuses step 1 |

## The Loop

### 1. Build a feedback loop (this is the skill)

Spend most effort here; load `references/feedback-loops.md` for ten loop recipes, tightening, and flaky bugs.

Exit criterion: **one command already run**, shown with (redacted) output, that is:

- Red-capable: drives the real code path and asserts the user's exact symptom, not "didn't crash".
- Deterministic: same verdict every run (flaky: a pinned, high reproduction rate).
- Fast (seconds).
- Agent-runnable: unattended; a human only through `scripts/hitl-loop.template.sh`.

No theory from reading code before this command exists. No loop possible → stop, list attempts, ask for environment access, a redacted artifact (HAR, log, core dump, recording), or temporary instrumentation. Only the reporter has the environment → hand them a read-only probe script (prints env, the disputed value, the state the hypothesis turns on; nothing secret): one command, one block pasted back.

### 2. Reproduce and minimise

- The loop must show the **user's** failure, not a nearby one.
- List every symptom in the user's words, including "unrelated" ones.
- Cut inputs, callers, config, data, and steps one at a time, re-running, until every remaining one is load-bearing.

### 3. Hypothesise: 3–5 ranked, falsifiable

Each states its prediction:
> "If X is the cause, then changing Y makes the bug disappear / changing Z makes it worse."

No prediction → sharpen or discard. Covers only some symptoms → symptom-level guess. Show the ranked list to the user before testing if present; do not block on it.

### 4. Instrument, then confirm or discard

- Every probe maps to one prediction; one variable at a time.
- Debugger/REPL first, then targeted logs at hypothesis boundaries; tag every temporary log with a unique prefix (`[DEBUG-a4f2]`); never "log everything and grep"; playbook: `references/logging-techniques.md`.
- By bug class: pure logic (off-by-one) → static reading; lifecycle/async/event-order → log while hypothesising; rendering → DevTools layers before logs; performance → before/after numbers: baseline, bisect, re-measure.
- Run the probe that would fail if the hypothesis were wrong. Contradicted → discard it and re-orient on what the probe showed. A log that changes the behavior is timing/lifecycle evidence, not noise.

For a recurring or runtime-state symptom (caches, queues, generated output, PATH, locale, timeouts, entry points), read `## Gotchas` in `references/failure-patterns.md`, list its headings (`grep -n '^## '`), and read only the section matching the symptom before adding a second fix. Domain traps: `references/ime-unicode.md` (IME, cursor drift, emoji), `references/rendering-debug.md` (PDF, print, fonts).

### 5–7. Fix, sweep, clean up

`fix`, or `bisect`/`regression` with fix authorization: read `references/fix.md` and run steps 5–7.

## Hard Rules

- **Same symptom after a fix: hard stop.** Re-read the execution path before touching code.
- **Three failed hypotheses → stop**, report with the Handoff format in `references/output.md`, ask how to proceed.
- **Measure the lower layer first** for system or tooling symptoms: OS capture vs post-processing, service vs UI, toolchain vs assertion, network vs client handling.
- **External tool failure: diagnose before switching** (server up, key valid, config right).
- **Magic number tuned three times: stop.** Unify into one named token; find the missing constraint.
- **Redact every secret** in commands, outputs, and artifacts you show (`<REDACTED>`); build loops against env vars.
- **Fix the cause inside the authorized scope.** A prerequisite refactor is fine if you state why; unrequested features and unrelated refactors are not.

## Output

Report with the block and status in `references/output.md`; blocked → its Handoff format.

Defer to: `check` (diff review, no symptom), `think` (is it worth it), `brainstorm` (product decision), `git` (commit).
