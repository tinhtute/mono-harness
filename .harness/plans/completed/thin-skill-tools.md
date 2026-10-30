---
status: completed
lane: standard
---
# Thin skills: move repeatable prose into scripts

## Goal
- outcome: Every skill whose repeatable steps live as prose commands becomes a thin guide around a script: the prose says when to run it and how to read its output; the script does the repeatable part and signals through exit codes.
- success_signal: each new script passes its own fixture run (hit and miss); `bash scripts/ci/validate-skills.sh`, `bash scripts/ci/verify-doc-links.sh` and `cd cli && cargo test` pass; each touched SKILL.md is shorter than before.
- actors: the owner (ní); the lead agent.
- authority: owner mental model 2026-10-30 ("A skill can be a thin guide around a tool. The prose explains when to use the tool and how to interpret evidence. The script preserves the repeatable part."); audit 2026-10-30 found gaps in `git`, `librarian`, `create-cli`; pattern reference `skills/reason/ambition/scripts/lint-prompt.sh`.
- requirements:
  - R1: `skills/tools/git/scripts/scan-staged.sh` runs the staged secret regex and the risky-filename check, prints `file:line` only (never the value), exits 0 clean, 1 hit, 2 usage error. | acceptance: fixture repo in a temp dir: staged fake `AKIA…` key → rc=1 with `file:line`; clean stage → rc=0 | source: `skills/tools/git/SKILL.md:43-47`
  - R2: `skills/tools/git/scripts/group-staged.sh` prints the staged files grouped by kind (`docs`, `test`, `config`, `deps`, `code`), keeps a manifest with its lockfile and a co-located test with its source. | acceptance: fixture with `Cargo.toml`+`Cargo.lock`, `foo.go`+`foo_test.go`, `README.md` → 3 groups as specified | source: `skills/tools/git/SKILL.md` Step 3
  - R3: git SKILL.md Steps 2–3 call the scripts and say how to read their output; the inline regex block and grouping prose are removed. | acceptance: `grep -c AKIA skills/tools/git/SKILL.md` = 0; `validate-skill.sh skills/tools/git` passes
  - R4: `skills/tools/librarian/scripts/gh-search.sh` wraps the patterns in `references/gh-patterns.md` as subcommands (`branch`, `code`, `tree`, `file`, `blame`/`history` as present), one known-good `gh` call each. | acceptance: `gh-search.sh branch cli/cli` prints a branch name, rc=0; bad subcommand → rc=2 | source: `skills/tools/librarian/references/gh-patterns.md`
  - R5: librarian SKILL.md and `gh-patterns.md` point to the script; the reference keeps only patterns the script does not cover. | acceptance: `verify-doc-links.sh` passes; `validate-skill.sh skills/tools/librarian` passes
  - R6: `create-cli` gets a script only if its references hold a repeatable check (e.g. shipping checklist items that are mechanically checkable); otherwise record "judgment-only, no script" in this plan. | acceptance: decision line in this plan with `file:line` evidence | source: `skills/extras/create-cli/references/shipping-checklist.md`
- non-goals:
  - NG1: No scripts for judgment-only skills (think, learn, arena, write, stages, mono).
  - NG2: No change to the pre-commit hook or `scripts/ci/**` (always-review paths).
  - NG3: No `zharness` CLI change.

## Phases and Verification
- approach: One skill per phase, modeled on `ambition/scripts/lint-prompt.sh` (bash, `set -euo pipefail`, exit 0/1/2, fixture run proves hit and miss). Rejected: one shared skills-wide script — couples unrelated skills.
- risks: the secret scan prints a secret value → script cuts to `file:line`, and the fixture asserts the value is absent from output. `gh-search.sh` needs network/auth → acceptance runs on a public repo; offline returns rc≠0 with a message, not a hang.
- seams: `skills/tools/git/{SKILL.md,scripts/}`, `skills/tools/librarian/{SKILL.md,scripts/,references/gh-patterns.md}`, `skills/extras/create-cli/references/`.
- phase_slug: `git-scripts`
  status: done
  - goal: R1, R2, R3 | depends_on: none
  - T1 write `scan-staged.sh` + fixture run — check: R1 acceptance
  - T2 write `group-staged.sh` + fixture run — check: R2 acceptance
  - T3 thin git SKILL.md — check: R3 acceptance
  - phase check: `bash scripts/ci/validate-skill.sh skills/tools/git && bash scripts/ci/verify-doc-links.sh`
- phase_slug: `librarian-script`
  status: done
  - goal: R4, R5 | depends_on: none
  - T4 write `gh-search.sh` — check: R4 acceptance
  - T5 point SKILL.md and reference at it — check: R5 acceptance
  - phase check: `bash scripts/ci/validate-skill.sh skills/tools/librarian && bash scripts/ci/verify-doc-links.sh`
- phase_slug: `create-cli-review`
  status: done
  - goal: R6 | depends_on: none
  - T6 read references, decide script or no script, record evidence — check: R6 acceptance
  - decision: judgment-only, no script. `skills/extras/create-cli/SKILL.md:20` produces specs and roadmaps, not code; `references/shipping-checklist.md` is plan-time choices and config templates for a CLI not yet built, so there is nothing to check mechanically.
- final check: `bash scripts/ci/validate-skills.sh && bash scripts/ci/verify-doc-links.sh && (cd cli && cargo test)`
