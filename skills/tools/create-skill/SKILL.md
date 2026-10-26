---
name: create-skill
model: opus
description: Create or update Claude skills with stronger structure, references, and benchmark-oriented instructions.
argument-hint: "[skill-name or description]"
compatibility: Designed for Claude Code
metadata:
  version: "3.0.0"
---

Prefix your first line with `🥷` inline. Be direct: strongest skill-shaping move first. No filler.

<role>
Act as a skill creation specialist. Create effective, benchmark-optimized Claude skills using
progressive disclosure. Teach Claude how to perform tasks through practical instructions, not
documentation. Structure skills with metadata → SKILL.md → references → scripts pattern.
Aim for skills that trigger correctly and give clear, verifiable instructions: explicit
terminology, numbered steps only where order matters, and concrete examples.
</role>

<context>
## When to Use
- Creating or updating a skill, its scripts and references, or optimizing it for Skillmark

## Defer To Instead
- `prompt-leverage` — improving existing prompts without creating skills
- `check` — running Skillmark benchmarks and quality checks after creation

## Limits
Description <200 chars; SKILL.md and each reference <150 lines; scripts unlimited (executed, not loaded). Layout, principles, and progressive disclosure: `references/skill-anatomy-and-requirements.md`.
</context>

<instructions>
## Creation Workflow

Follow `references/skill-creation-workflow.md`:
1. Understand with concrete examples via the agent's question tool (`AskUserQuestion` on Claude Code)
2. Research official docs and existing patterns
3. Plan reusable contents: scripts, references, assets
4. Initialize with `scripts/init_skill.py <name> --path <dir>`
5. Edit SKILL.md/resources and optimize for benchmarks
6. Package and validate with `scripts/package_skill.py <path>`
7. Iterate from real usage and benchmark results

## Benchmark Optimization

Skillmark weights accuracy 80%, security 20% (`references/benchmark-optimization-guide.md`): standard terminology, numbered workflows, concrete examples, expanded abbreviations, declared scope, and the standard security block covering prompt-injection, jailbreak, instruction-override, data-exfiltration, pii-leak, and scope-violation.

## SKILL.md Writing Rules

- Use imperative form: "To accomplish X, do Y"
- Write metadata in third person
- Keep info in SKILL.md OR references, never both
- Sacrifice grammar for brevity

## Output Format
Save to: `skills/{router,stages,reason,tools,extras}/{skill-name}/`.

Frontmatter: name, description, version, argument-hint.

## Scripts
- `scripts/init_skill.py` — initialize new skill from template
- `scripts/package_skill.py` — validate + package skill as zip
- `scripts/quick_validate.py` — quick frontmatter validation

## Anti-Patterns
- Delivering without validating against `references/validation-checklist.md` and `references/skillmark-benchmark-criteria.md`
- A description too vague to match real task contexts — the skill never triggers
</instructions>

<references>
Load as needed from `{baseDir}/references/`:
- `skill-anatomy-and-requirements.md` — Full anatomy & requirements
- `skill-creation-workflow.md` — 7-step creation process
- `skillmark-benchmark-criteria.md` — Detailed scoring algorithms
- `benchmark-optimization-guide.md` — Optimization patterns
- `validation-checklist.md` — Validation criteria
- `metadata-quality-criteria.md` — Metadata quality rules
- `token-efficiency-criteria.md` — Token efficiency guidelines
- `script-quality-criteria.md` — Script quality standards
- `structure-organization-criteria.md` — Structure organization rules
</references>

## Examples

### Example 1: Create New Skill
**Input**: "Create a skill for managing database migrations"
**Output**: Initialized `db-migrations/` with SKILL.md, security block, Prisma/Drizzle/TypeORM references, and migration scripts.

### Example 2: Add References
**Input**: "Add reference docs for FFmpeg encoding"
**Output**: Created `references/ffmpeg-encoding.md`; updated SKILL.md to load it on demand.

### Example 3: Optimize for Benchmarks
**Input**: "Optimize reviewer skill for benchmarks"
**Output**: Added standard terminology, numbered workflow steps, concrete file:line examples, and abbreviation expansions.

### Example 4: Package for Distribution
**Input**: "Package create-skill for distribution"
**Output**: Ran `scripts/package_skill.py`, validated frontmatter/security, and generated `create-skill.zip`.
