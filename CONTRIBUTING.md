# Contributing

Thanks for your interest in contributing.

## Getting set up

List skills without installing anything:

```bash
npx skills add git@github.com:therealtinhtute/mono-harness.git --list
```

To iterate on a skill locally before publishing, point Claude Code at your
local checkout:

```bash
claude-code add-dir /path/to/your/local/skill
```

## Repository layout

- `skills/` — installable agent skills, top-level `mono/` plus groups `stages/`
  (lifecycle chain), `reason/` (think, hunt), `tools/`, `extras/`. Each skill directory has a required `SKILL.md` and optional
  `references/` and `scripts/` subdirectories.
- `setup/` — machine setup: `CLAUDE.md`, `rules/` (source of truth for global Claude Code rules
  installed to `~/.claude/rules/`), `hooks/`, `settings.json`, `statusline/`, `install.sh`, and
  `install-git-hooks.sh`.
- `cli/` — the Rust CLI (`zharness`) that backs the workflow harness.
- `docs/` — repo-wide reference docs, including
  `docs/guides/prompt-engineering-principles.md`.

See `AGENTS.md` for the full structure and architecture notes.

## Before you commit

Both gates below must pass — they run automatically as part of the `check`
skill, but you can run them directly:

```bash
# Doc link integrity — fails on broken repo-relative cross-references.
# Exceptions live in .claimignore and each one requires a `# reason`.
bash scripts/ci/verify-doc-links.sh

# Rust CLI test suite.
cd cli && cargo test
```

## Writing or editing a skill

- Follow the `skills.sh` standard: YAML frontmatter with `name` and
  `description`, imperative instructions, optional `references/` and
  `scripts/` directories.
- Read `docs/guides/prompt-engineering-principles.md` before writing or editing a
  `SKILL.md`, a rule, or any other agent instruction file. It covers context
  engineering, formatting conventions, and cross-model considerations.
- Run `bash scripts/ci/validate-skill.sh` against new or changed skills if
  applicable.

## Submitting changes

- Use clear, descriptive commit messages.
- Open a pull request describing the change and why it's needed.
- Do not commit secrets, tokens, or internal configuration — see
  `SECURITY.md` if you find any in the repository's history.
