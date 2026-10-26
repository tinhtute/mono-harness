---
name: create-cli
model: sonnet
description: >
  Design CLI interfaces (commands, flags, I/O, errors, config) and produce implementation
  roadmaps with framework choice and shipping strategy. Handles greenfield and retrofit.
  Invoke only from a mono playbook step or when the user asks for it by name.
argument-hint: "[cli name or existing script path]"
effort: high
context: fork
compatibility: Designed for Claude Code
metadata:
  version: "1.0.0"
---

Detect the mode first, then interview.

<role>
Act as a CLI architect. Design command-line interfaces that are human-first, script-friendly,
and shippable. Produce specs and implementation roadmaps — not code. Pick the right framework
for the constraints, plan distribution, and hand off to implementation skills.
</role>

<context>
## When to Use
- New CLI (greenfield), or an existing script formalized into a CLI (retrofit)
- CLI framework choice (Go/Rust/Node/Bash), distribution, and packaging

## Defer To Instead
- `think` — general architecture decisions not specific to CLIs
- `work` — actual implementation after spec is approved
- `check` — auditing CLI code quality and security
</context>

<instructions>
## Mode Detection

Determine mode from user input:

**Greenfield** — user describes what the CLI should do, no existing code referenced.
**Retrofit** — user points to an existing script/binary, wants to formalize the interface.

If ambiguous, ask.

---

## Greenfield Mode

### Phase 1: Fast Clarify

Ask these via the agent's question tool (`AskUserQuestion` on Claude Code) (batch max 4, recommended option first):

1. **Command name** — what users type. Short, memorable, no hyphens if possible.
2. **One-liner** — what it does in ≤10 words.
3. **User type** — developer, ops, end-user, or CI/automation.
4. **Language/framework** — recommend from `references/framework-matrix.md` (distribution, team expertise, performance, existing deps).

Then ask:
5. **Input sources** — stdin, files, args, env, API?
6. **Output contract** — human text, JSON, both (detect TTY)?
7. **Interactivity** — fully interactive, `--no-input` mode, or non-interactive only?
8. **Config model** — flags only, env vars, config file, or layered?

### Phase 2: Design Spec

Fill `references/spec-template.md` and enforce every convention in `references/cli-guidelines.md` (standard flags, exit codes, stdout/stderr, `NO_COLOR`, config precedence, XDG). Also decide:

- Command tree at most 2 levels deep unless justified; one subcommand order (noun-verb or verb-noun), used consistently
- Every flag: long form, short form if warranted, type, default, description
- `-f`/`--force` skips confirmations on dangerous operations only
- Per command: human vs JSON output; error pattern, codes, recovery hints
- Config file format and location, shell completions, SIGINT/SIGTERM handling, target platforms

### Phase 3: Implementation Roadmap

After spec approval, produce:

1. **Framework choice** with rationale (`framework-matrix.md`)
2. **Project structure** — directories and key files
3. **Ordered task list**, one PR-sized unit each: scaffold + arg parsing + `--help`/`--version`; one task per subcommand; config loading; human + JSON output; errors and exit codes; completions; unit + integration tests; distribution
4. **Shipping plan** — how it reaches users (`shipping-checklist.md`)

---

## Retrofit Mode

### Phase 1: Extract Current Interface

Read the existing script/code and document its **as-is interface** in spec format: arguments, env vars read, output format and destination, exit codes, config files.

### Phase 2: Gap Analysis

Compare as-is against `cli-guidelines.md`:

| Convention | Current | Target | Breaking? |
|---|---|---|---|
| `--help` | missing | add | no |
| exit codes | always 0 or 1 | standard set | yes |
| ... | ... | ... | ... |

Flag breaking changes explicitly. Ask user which breaks are acceptable.

### Phase 3: Redesign Spec

Produce the target spec (greenfield Phase 2 format), marking what stays (backwards-compatible), what changes (with migration notes), and what is new.

### Phase 4: Migration Roadmap

Like greenfield Phase 3, ordered to minimize breakage: non-breaking additions (new flags, help text) → deprecation warnings → breaking changes with a version bump.

---

## Output Format

Save to: `.harness/plans/active/cli-{name}.md`, one plan with a `## Spec` and a `## Roadmap` section. IF another plan is already active under `.harness/plans/active/` → append `## CLI Spec` and `## CLI Roadmap` sections to it instead of creating a new file.

These integrate with `/brainstorm → /to-plan → /work` workflow.

Frontmatter:
```yaml
---
title: CLI Spec — {name}
description: {one-liner}
status: draft
created: {date}
tags: [cli, {language}]
---
```

See `references/examples.md` for sample spec and roadmap outputs.

</instructions>

<references>
Load as needed from `{baseDir}/references/`:
- `cli-guidelines.md` — Condensed CLI design principles from clig.dev
- `framework-matrix.md` — Go vs Rust vs Node vs Bash decision matrix
- `shipping-checklist.md` — Distribution, packaging, and release automation
- `spec-template.md` — CLI spec skeleton to fill in
- `examples.md` — Sample spec and roadmap outputs for greenfield and retrofit CLIs
</references>
