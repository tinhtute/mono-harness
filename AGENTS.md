# AGENTS.md

This file provides guidance to coding agents (Claude Code, Codex, etc.) working in this repository.

## Repository Overview

This is the personal mono-harness repository for `therealtinhtute`: a `skills.sh`-compatible agent skill set for the SDLC, plus `zharness`, the Rust CLI/protocol that keeps that lifecycle legible and portable across coding agents. See README.md's Goals/Non-goals for the full scope.

## Layout and Pipeline

Skills live in `skills/mono/` and `skills/{stages,reason,tools,extras}/<name>/`; the `zharness` crate in `cli/`; machine setup (global CLAUDE.md, rules, hooks, settings, installers, statusline) in `setup/`; protocol, ADRs, and plans in `docs/`; workflow procedures in each owning skill's `references/`. The workflow chain and its stage contracts: `skills/stages/README.md`.

Plans are committed markdown (`.harness/plans/active/{slug}.md`); pre-commit guards (`setup/install-git-hooks.sh`) enforce proof re-execution, an independent judge on high-risk and `full` checks, and at most one active plan. Edit procedures in `skills/stages/<stage>/references/`. For the managed router, change `cli/docs/embedded/WORKFLOW.md` and copy the same bytes to `.harness/WORKFLOW.md`; `cd cli && cargo test --test projection_parity` checks this mirror. Editing a file under `skills/stages/*/references/` → run `cd cli && cargo test`: contracts in `cli/src/embedded.rs` and `cli/tests/skill_reference_resolution.rs` pin their text and companion files, which `validate-skill.sh` does not check.

## Gate Commands

`check` runs these at a phase gate or before a PR; a plain commit needs only the
pre-commit hook. They sit at two different levels of the
ladder in `docs/guides/patterns/encoding-invariants.md` — declare the level, do not
assert enforcement the repository does not have.

```bash
# [CI] Rust CLI: format, lint, test — .github/workflows/cli-ci.yml, job `build-test`
cd cli && cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test

# [CI] Rust CLI size target — .github/workflows/cli-ci.yml, job `size-gate`
cd cli && cargo build --release --target x86_64-unknown-linux-musl && test "$(wc -c < target/x86_64-unknown-linux-musl/release/zharness)" -le 1850000

# [CI] Guard fixture tests for the pre-commit hook's ZGUARD-CORE block — .github/workflows/cli-ci.yml, job `hook-guard`
bash scripts/ci/test-guards.sh

# [CI] Doc link integrity (broken repo-relative cross-references) — .github/workflows/docs-ci.yml, job `doc-links`, on any tracked *.md change.
# Exceptions live in .claimignore, each one requires a `# reason`.
bash scripts/ci/verify-doc-links.sh

# [CI] Skill frontmatter (every tracked SKILL.md; warnings never fail) — .github/workflows/skills-ci.yml, job `validate-skills`, on any SKILL.md change.
bash scripts/ci/validate-skills.sh
```

The pre-commit hook also runs `scripts/ci/validate-skill.sh` on changed skills
once installed with `bash setup/install-git-hooks.sh --force`.

Run a single Rust test: `cd cli && cargo test --lib installer::registry::tests::registry_update_registers`.

## Architecture Notes

- **Prompt engineering:** before writing or editing skills (SKILL.md), rules (setup/rules/*.md), or any agent instruction file, read `docs/guides/prompt-engineering-principles.md` — context engineering, formatting syntax, language rules, few-shot patterns, anti-patterns, cross-model awareness.
- **Skill format:** All skills follow the `skills.sh` standard — YAML frontmatter with `name` and `description`, imperative instructions, optional `references/` and `scripts/` directories.
- **setup/rules/ directory:** Source-of-truth for rules installed to `~/.claude/rules/`. Keep in sync with installed versions.
- **`site/` is hand-authored, not generated.** A static GitHub Pages site (`.github/workflows/pages.yml` deploys on push to `site/**`) that narrates the same architecture/workflow story as `docs/`; it does not regenerate from `docs/*.md` and can drift — it was last brought in line with v0.24.0.

<!-- ZHARNESS:BEGIN -->
## Harness

Start from the requested outcome; the repository is the system of record. Read `.harness/WORKFLOW.md` and only the material the task needs.

- Answers, reviews, diagnoses, plans, and status reports are read-only.
- A bounded change needs no plan: implement and validate.
- Use one `.harness/plans/active/` file when work spans sessions, has dependencies, or needs recovery; move it to `.harness/plans/completed/` only after validation.
- Before adding an externally observable policy, find its repository authority; IF materially different choices remain open → stop before edits (a configurable default is not authority).
- Claim completion only with executable or observable evidence.

`zharness` only installs, updates, and uninstalls. There is no task database. There is no parallel control-plane state.
<!-- ZHARNESS:END -->
