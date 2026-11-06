# Retro — operating logic

Output: at most 5 findings, severity-ranked, each in the schema below, exactly
one marked `Next`. No preamble. Steps 1–5 are read-only; step 6 edits files only
after the user approves the `Next` finding, and fixes that one finding only.

A retro targets the agent's **environment** (navigation, guards, steering,
tools, information); the session's own code is evidence, not the target. Every
finding cites evidence a reader can open: a digest line, a turn number, or
`file:line`. Report only what you can cite.

## 1. Load the session

- Default: `python3 scripts/session-digest.py` — newest Claude Code session for
  the current directory (`~/.claude/projects/<cwd with non-alphanumerics as ->/*.jsonl`).
- A named session: pass its id or `.jsonl` path.
- Another agent (Codex: `~/.codex/sessions/**/*.jsonl`) or a pasted transcript:
  read it directly and collect the signals the digest prints — token and
  compaction totals, tool-call counts, errored results, repeated identical
  calls, largest results, user prompts, and answers to structured questions.
- The digest lists sub-agent logs when they exist; digest one only when a
  finding depends on what that sub-agent did.
- Open the raw log only to confirm a specific turn the digest points at.

## 2. Read the repository's guardrails before judging

- Steering: `AGENTS.md` / `CLAUDE.md` in the repo, plus global ones if readable. Note line counts.
- Gates: the repo's check command (its AGENTS.md gate list, `package.json` /
  `Cargo.toml` / `Makefile` scripts), git hooks (`.git/hooks/`, a hook
  installer), and CI workflows.
- Review surface: whatever reviews a diff here — a review playbook, a judge,
  a `CODING_STANDARDS.md`, a review bot. Record which exist; treat anything you did not find as absent.

A check that exists but is unwired, skipped, or silently broken is the finding —
not a new check. A repo with no hook and no CI job running its lint/test is
itself a finding.

## 3. Scan these categories

Scan all seven before ranking; a category earns a finding only with evidence. A count or metric cited as evidence names what else it could be measuring (errors, skipped work, noise) and why that is ruled out.


- **Navigation** — the agent searched long or read wrong files first. Candidate fix: a pointer in the file the agent already reads.
- **Automated checks** — the agent made an error a linter, type check, test, or hook would catch.
- **Review standards** — the review surface missed a defect. Classify first:
  a **mechanical** violation (fixed pattern, banned API, import shape, file
  location) gets a deterministic check; only a **judgement** call (cross-file
  consistency, surrounding style) gets a written review rule.
- **Steering weight** — AGENTS.md/CLAUDE.md carries rules that belong in a check or review rule; it should hold navigation pointers.
- **Tool economy** — large results, repeated identical calls, a compaction, a peak context near the window, or a token-heavy custom tool in the digest.
- **No-ops** — a steering line the session shows had no effect on behaviour; removing it would change nothing.
- **Information access** — the agent lacked a log, service, or doc it needed and guessed or asked.

Steering signals: a user prompt that corrects or redirects, and a structured answer that rejects the `(Recommended)` option, each mark a place where the agent's default was wrong — trace it to a category above.

### Where the fix lives

The implementing agent carries the most context pressure (exploration, code,
debugging); the reviewer gets a diff. Put each fix where it costs least context:

| Home | Holds | Loaded |
|---|---|---|
| Check (lint, test, hook, CI) | mechanical rules | never; it runs |
| Review surface (review playbook, judge, `CODING_STANDARDS.md`) | judgement rules | at review only |
| `AGENTS.md` / `CLAUDE.md` | navigation pointers only | every session |
| Docs | reference material, reached by a pointer; extend an existing doc before writing a new one | on demand |
| Skill | a description that should trigger, or a user-invoked command | description every session |

A review surface past ~1,000 lines splits into docs behind pointers. A fix that
adds a coding rule to steering read by the implementer is the wrong home.

## 4. Rank by severity

| Severity | Meaning |
|---|---|
| `S1` | Wrong result shipped or claimed: a false completion claim, an unproven "done", a defect that passed every gate. |
| `S2` | Cost human steering or rework: a user correction, a failed commit/CI, a reverted change. |
| `S3` | Wasted budget only: tokens, time, repeated calls, no wrong outcome. |

Break ties by recurrence: a friction that will hit every future session outranks a one-off.

## 5. Report

```
### {n}. [{S1|S2|S3}] {category} — {one-line friction}
- evidence: {digest line / turn N / file:line}
- mechanical | judgement: {which, and why}
- smallest fix: {change} at {file or tool}
- home: {check | review surface | steering | docs | skill}
- fix mode: guard | experiment | human
```

Mark one finding `Next` — highest severity, then highest recurrence. End with
one question: fix `Next` now, in the mode named? Stop until the user answers.

## 6. Fix the approved finding

Before writing any steering, review rule, doc, or skill text, read
`docs/guides/prompt-engineering-principles.md` when the repo has it.

Pick the mode from the finding, not from preference:

- **guard** — the finding is mechanical AND an accepted rule already states it
  (a doc, AGENTS.md, an owner decision). Follow `encoding-invariants.md` (next to this file):
  smallest native check, positive and negative proof, enforcement level stated.
- **experiment** — anything else: a judgement call, a steering or navigation
  change, or a mechanical rule nobody has accepted yet. Copy
  `harness-improvement.md` (next to this file) to
  `.harness/plans/active/harness-improvement-{slug}.md`, make the one change, record
  native proof, and leave `Decision: pending fresh rerun`. If another plan is
  already active, ask before creating a second one — the repo guard allows one.
- **human** — the fix needs authority, access, or a policy call you lack. Say
  what and who; change nothing.

The fix is done when its proof ran. The *improvement* is claimed only after a
later, different session re-runs the representative job and sets `Decision:`
to keep, revise, or remove — until then report it as pending, not as improved.
Hooks, CI providers, and branch protection change only when the user
authorizes that file separately.

<example id="1">
### 1. [S1] Automated checks — work claimed `cargo test` green; it was never run (Next)
- evidence: digest shows 0 `cargo test` calls; turn 14 says "all tests pass"
- mechanical: a pre-commit guard can require a fresh proof line
- smallest fix: extend the existing proof guard in `scripts/install-git-hooks.sh`
- home: check
- fix mode: guard
</example>

<example id="2">
### 3. [S3] Tool economy — full `docs/ARCHITECTURE.md` read four times
- evidence: digest "repeated identical calls: Read x4"
- judgement: the agent needed one section, not a check
- smallest fix: section pointer in `AGENTS.md` Layout and Pipeline
- home: steering
- fix mode: experiment
</example>
