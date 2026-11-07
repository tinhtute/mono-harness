# AGENTS.md

This file provides guidance to coding agents (Claude Code, Codex, etc.) working in this repository.

## Repository Overview

This is the personal mono-harness repository for `therealtinhtute`: a `skills.sh`-compatible agent skill set for the SDLC, plus `zharness`, the Rust CLI/protocol that keeps that lifecycle legible and portable across coding agents. See README.md's Goals/Non-goals for the full scope.

## Layout and Pipeline

Skills live in `skills/mono/` and `skills/{stages,reason,tools}/<name>/`; the `zharness` crate in `cli/`; the harness agents (`mono-lead`, `mono-worker`, `mono-verifier`) in `agents/`, their model policy in `models.json`, installed by `bash scripts/install-agents.sh`; machine setup (global CLAUDE.md, rules, settings, mods, installer, statusline) lives in the separate repo https://github.com/tinhtute/monoclaudian; protocol, ADRs, and plans in `docs/`; workflow procedures in each owning skill's `references/`. The workflow chain and its stage contracts: `skills/stages/README.md`.

Plans are committed markdown (`.harness/plans/active/{slug}.md`); pre-commit guards (`scripts/install-git-hooks.sh`) enforce proof re-execution, an independent judge on high-risk and `full` checks, and at most one active plan. Edit procedures in `skills/stages/<stage>/references/`. For the managed router, change `cli/docs/embedded/WORKFLOW.md` and copy the same bytes to `.harness/WORKFLOW.md`; `cd cli && cargo test --test projection_parity` checks this mirror. Editing a file under `skills/stages/*/references/` → run `cd cli && cargo test`: contracts in `cli/src/embedded.rs` and `cli/tests/skill_reference_resolution.rs` pin their text and companion files, which `validate-skill.sh` does not check.

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

# [CI] Agent model policy (agents/*.md vs models.json) — .github/workflows/cli-ci.yml, job `agent-models`
bash scripts/ci/test-agent-models.sh

# [CI] zharness installer script fixtures — .github/workflows/cli-ci.yml, job `install-script`
bash scripts/ci/test-install-zharness.sh

# [CI] Guard fixture tests for the pre-commit hook's ZGUARD-CORE block — .github/workflows/cli-ci.yml, job `hook-guard`
bash scripts/ci/test-guards.sh

# [CI] Doc link integrity (broken repo-relative cross-references) — .github/workflows/docs-ci.yml, job `doc-links`, on any tracked *.md change.
# Exceptions live in .claimignore, each one requires a `# reason`.
bash scripts/ci/verify-doc-links.sh

# [CI] Skill frontmatter (every tracked SKILL.md; warnings never fail) — .github/workflows/skills-ci.yml, job `validate-skills`, on any SKILL.md change.
bash scripts/ci/validate-skills.sh

# [CI] Skill script and check-panel tests — .github/workflows/skills-ci.yml, jobs `skill-scripts`, `risk-facts`, `panel-merge`
bash scripts/ci/test-skill-scripts.sh && bash scripts/ci/test-risk-facts.sh && python3 -I scripts/ci/test-panel-merge.py
```

The pre-commit hook also runs `scripts/ci/validate-skill.sh` on changed skills
once installed with `bash scripts/install-git-hooks.sh --force`.

Run a single Rust test: `cd cli && cargo test --lib installer::registry::tests::registry_update_registers`.

## Exercise

The recipe `skills/stages/check/references/check-exercise.md` starts from. Run `zharness` against a throwaway repository, never this one:

```bash
cd cli && cargo build -q && BIN=$PWD/target/debug/zharness
export XDG_CONFIG_HOME=$(mktemp -d)   # keep the real repo registry untouched
T=$(mktemp -d) && cd "$T" && git init -q
"$BIN" install     # expect rc=0; .harness/WORKFLOW.md, .harness/PROJECT.md, AGENTS.md, .gitignore created
"$BIN" uninstall   # expect rc=0; `git status --porcelain` is empty afterwards
```

## Architecture Notes

- **Prompt engineering:** before writing or editing skills (SKILL.md), rules (`rules/*.md` in the monoclaudian repo), or any agent instruction file, read `docs/guides/prompt-engineering-principles.md` — context engineering, formatting syntax, language rules, interfaces before examples, anti-patterns, cross-model awareness.
- **Skill format:** All skills follow the `skills.sh` standard — YAML frontmatter with `name` and `description`, imperative instructions, optional `references/` and `scripts/` directories.
- **Rules live in monoclaudian:** `~/.claude/rules/` is installed from the monoclaudian repo; edit rules there, not here.
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

## Unattended Shipping

Read by the land step of `skills/mono/playbooks/ship.md` and the rubric in `skills/stages/check/references/check-risk.md`.

- Auto-merge: low-risk
- Always-review paths: scripts/install-git-hooks.sh, scripts/ci/**, .github/**, cli/src/installer/**, cli/Cargo.toml, cli/Cargo.lock
- Merge method: merge (the repo disables GitHub auto-merge, so wait for green with `gh pr checks --watch`, never `gh pr merge --auto`)
