---
name: create-skill
model: opus
description: Create or update Claude skills with progressive disclosure, lean context, clear boundaries, and benchmark-ready instructions.
argument-hint: "[skill-name or description]"
version: "4.0.0"
compatibility: Designed for Claude Code
---

# Create Skill

## Outcome Contract

- Outcome: a skill that triggers on the right requests and carries only the context the model needs.
- Done when: the description names concrete triggers, the body covers outcome and routing, detail lives in trigger-loaded `references/`, a `Defer to:` line names its siblings, and validation passes.
- Evidence: `scripts/package_skill.py <path>` output, plus `bash scripts/ci/validate-skill.sh <path>` inside this repo.

Before writing or editing any SKILL.md, read `references/context-engineering.md`. It sets the rules this skill enforces: judgment over rules, interfaces before examples, progressive disclosure, one source of truth, and no host boilerplate.

## Workflow

Full procedure: `references/skill-creation-workflow.md`.

1. Understand: collect real requests the skill must handle. Ask the user only when the trigger or scope is unclear.
2. Research: read official docs and the nearest existing skills. Do not duplicate one.
3. Plan the split. Name the triggers in the description. Put the outcome contract and routing in the body. Put mode-specific or long detail in `references/`, and deterministic work in `scripts/`.
4. Initialize: `scripts/init_skill.py <name> --path <dir>`.
5. Write: state interfaces (inputs, outputs, commands, done criteria) rather than sample transcripts. Point to each reference from the step that needs it.
6. Validate: `scripts/package_skill.py <path>`, then check against `references/validation-checklist.md`.
7. Iterate from real runs. Cut lines that do not change behavior.

## Limits

- Description: under 200 characters.
- SKILL.md and each reference: under 150 lines. Scripts have no limit because they are executed, not loaded.
- Layout and loading levels: `references/skill-anatomy-and-requirements.md`.

Save new skills to `skills/{stages,reason,tools,extras}/<name>/`.

## Benchmarks

For Skillmark scoring, read `references/benchmark-optimization-guide.md` and `references/skillmark-benchmark-criteria.md`.

## References

Load on demand from `references/`:

- `metadata-quality-criteria.md`: wording the description.
- `token-efficiency-criteria.md`: cutting the size of SKILL.md.
- `structure-organization-criteria.md`: deciding the split between the body and `references/`.
- `script-quality-criteria.md`: adding scripts.

Defer to: `prompt-leverage` (improve a prompt without making a skill), `check` (benchmarks and review after creation).
