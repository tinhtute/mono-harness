---
status: active
lane: normal
---
# Move non-ADLC skills to monoclaudian

## Goal
- outcome: monoharness ships only skills the ADLC/SDLC workflow uses. `tldraw-diagram`, `prompt-leverage`, `create-skill`, `create-cli`, `turbo-mono-platform` and the full `write` skill (with `evals/01–08`) live in github.com/tinhtute/monoclaudian under `skills/`, installed by its `install.sh`. monoharness keeps a slim `mono-write` with only what its playbooks need (polish a research draft; CHANGELOG/release notes). Breaking change.
- success_signal: `git ls-files skills/tools/{tldraw-diagram,prompt-leverage,create-skill,write} skills/extras evals/0*` is empty in monoharness; `skills/tools/mono-write/SKILL.md` exists; `git grep -nwE "tldraw-diagram|prompt-leverage|create-skill|create-cli|turbo-mono-platform" -- skills cli scripts .github AGENTS.md README.md site` has no live hits; every AGENTS.md gate passes; monoclaudian has `skills/<name>/SKILL.md` for the 6 skills, `npx skills add` of it lists them, and its CI is green.
- actors: owner; agents loading skills via `npx skills add` from either repo.
- authority: owner 2026-11-06: move the 5 skills plus `write`; clone `write` fully to monoclaudian; harness keeps only the part it needs; merge #241 first, new PR. Lead decision: harness copy is named `mono-write` to avoid a duplicate `write` skill when both repos are installed (matches `mono-*` agents).
- requirements:
  - R1: monoclaudian gains `skills/{tldraw-diagram,prompt-leverage,create-skill,create-cli,turbo-mono-platform,write}` byte-identical to monoharness master `5769342`, plus `evals/01–08` and `evals/results` if tracked; `install.sh` installs its skills via `npx skills add git@github.com:tinhtute/monoclaudian.git -a claude-code codex pi -g -y`; README lists them; CI validates its SKILL.md frontmatter. | acceptance: `diff -r` of each skill vs `git show 5769342:` tree is empty; CI green | source: owner
  - R2: monoharness deletes those skills and evals; skills that referenced them (`ambition`, `mono/SKILL.md` gated list, `learn`, playbooks research/ship) are updated so no live reference names a moved skill; `write` steps call `mono-write`. | acceptance: success_signal grep; `bash scripts/ci/validate-skills.sh`; `cd cli && cargo test` | source: owner
  - R3: `skills/tools/mono-write/SKILL.md` covers only: polishing a research/learn draft (strip AI patterns, EN/VI) and CHANGELOG/release-notes prose; it defers full writing work to `write` from monoclaudian when installed. | acceptance: validate-skill passes; SKILL.md names both jobs and the deferral | source: owner
  - R4: docs (README, AGENTS.md, CONTRIBUTING, site, CHANGELOG Unreleased BREAKING, docs/guides) reflect the move; historical docs keep original names with notes where they would become false. | acceptance: `bash scripts/ci/verify-doc-links.sh` 0 findings | source: owner
- non-goals:
  - NG1: no change to `read`, `learn`, `librarian`, `think`, `hunt`, `ambition`, `arena`, `git` behavior beyond reference updates.
  - NG2: no new eval suite for `mono-write`.

## Phases and Verification
- approach: copy to monoclaudian from master `5769342` and delete here in one PR each; rejected: keep `write` here and import from monoclaudian (reverse dependency).
- phase_slug: `main`
  status: planned
  - goal: R1, R2, R3, R4 | depends_on: none
  - surfaces: monoclaudian `skills/`, `evals/`, `install.sh`, README, CI; monoharness `skills/`, `evals/`, `scripts/ci/test-skill-scripts.sh`, docs, site | avoided: `cli/src/installer/**`
  - phase check: `bash scripts/ci/validate-skills.sh && bash scripts/ci/verify-doc-links.sh && bash scripts/ci/test-guards.sh && bash scripts/ci/test-skill-scripts.sh && (cd cli && cargo test)` plus the success_signal grep; monoclaudian CI green

## Log

## Validation

## Current State and Next Action
- active_phase: none
- lifecycle_status: planned
- blockers: none
- open_items: none
- exact_next_action: work full phase main
