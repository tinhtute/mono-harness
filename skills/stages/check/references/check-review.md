# Playbook: check (manual review axes)

Loaded by [check.md](check.md) step 5 for `full`, or `bounded` on a diff.

- **Two axes, kept apart** — run them one after the other on `git diff <base>...HEAD`. Sub-agents only for `full` and only when asked (IF unspecified → ask once: single agent (Recommended) / two sub-agents), each briefed per `work-full.md` step 4 with its own axis's sources. They do not change the `judge:` declaration.
- **Spec axis** — sources: the Goal's requirements and non-goals and the phase `goal:`. Report missing, partial, wrong, or unrequested behavior, citing the requirement ID. Judge "already covered" or overlap by intent: name the goal each side serves; matching wording is not coverage.
- **Standards axis** — sources: the repository's documented standards, then Security, Performance, Architecture, Code Quality. Skip what tooling enforces. Flag as judgement, not violation: Fowler smells (Mysterious Name, Duplicated Code, Feature Envy, Data Clumps, Primitive Obsession, Repeated Switches, Shotgun Surgery, Divergent Change, Speculative Generality, Message Chains, Middle Man, Refused Bequest); tests that are implementation-coupled, tautological, or written in bulk ahead of the code; any deleted, skipped, or weakened test (a blocking finding). A state-mutating command must converge when run twice or after a crash at any step. A reported number (speedup, eval score, count) carries its run count, spread and limiter, or it is a claim. For a class-of-bug fix, search sibling instances and state whether coverage is complete.
- Report under `Spec` and `Standards` headings without merging them; step 7 weighs both.

## Multi-model panel (opt-in)

Off by default. Run it only when the owner asks for it by name and the mode is `full` or `high-risk`; never for `bounded`, `gate`, or on your own initiative. IF the owner has not named the models or a token budget → ask once; an unnamed budget means no panel.

- **Size** — 2 to 3 reviewers, each an explicit `model` per `work-fanout.md`; at most one budget of 3× a single-agent review. A reviewer that exceeds its timebox is dropped.
- **Same input** — resolve `base_sha` and `head_sha` (plus the dirty-diff hash) once. Each reviewer gets its own brief with those values and never sees another reviewer's output. Reject a report that names different SHAs.
- **Axes** — each reviewer reports under `Spec` and `Standards`. A finding carries axis, file:line or requirement ID, and evidence.
- **Dedup** — two findings are one when they share axis and file and their line ranges overlap or sit within 3 lines (a Spec finding without a file: same requirement ID). Keep the highest severity, the lowest reviewer index on a tie, and record `agreed: n/N`.
- **Priority, not proof** — order by severity, then `agreed`. Agreement never raises severity or confirms a defect: validate every finding yourself against the repository and the proof output. Conflicting severities keep the higher until you validate it; a finding you cannot validate is listed as unverified and does not block.
- **Fallback** — fewer than 2 valid reports (unavailable runner, timeout, over budget, rejected SHA) → finish as a single-agent review and print `panel: degraded (valid/N)`. The panel adds findings; it never replaces the `judge:` declaration or the evidence behind the verdict.

Each reviewer writes one JSON report; merge them with this skill's `scripts/panel-merge.py --base <sha> --head <sha> [--diff-hash <h>] --budget <tokens> <report>...`, which applies the size, same-input, dedup, priority, and fallback rules above (report schema in its docstring). Validate its findings yourself; the script only orders them.

Rationale and rejected alternatives: ADR 0018.
