# Prompt Engineering Principles

Reference for writing effective prompts, skills (SKILL.md), and rules. Read this before creating or editing any skill or rule file.

Complements: `skills/tools/create-skill/references/writing-effective-instructions.md` (HOW), `token-efficiency-criteria.md` (SIZE). This file covers WHY and SYNTAX.

## Core Principle: Context Engineering

Context = all tokens the LLM sees at inference (system prompt + tools + examples + history + data). Not just "the prompt."

- LLMs have a finite **attention budget** — n² pairwise relationships, so recall degrades gradually as context grows (context rot; [Anthropic, Effective context engineering for AI agents, 2025-09-29](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents))
- Guiding rule: find the **smallest set of high-signal tokens** that maximize desired outcome
- Each added instruction competes for attention; test whether a new line changes behavior before keeping it

## Formatting Syntax

### XML Tags vs Markdown

| Use | For |
|-----|-----|
| XML tags | Boundaries between content blocks — documents, examples, output schemas, data |
| Markdown headers | Hierarchy within a single instruction block |
| Never both | Don't wrap XML then add redundant Markdown headers inside |

### Inside XML Tags

| Content type | Format | Example |
|---|---|---|
| Rules/constraints | Dash list, no indent, no blank lines | `- Max 200 words\n- Vietnamese only` |
| Examples | Flat key:value, no prose | `input: ...\noutput: ...` |
| Documents/data | Attributes for metadata, flat content | `<document source="x" date="y">content</document>` |
| Output schema | Template directly, no explanation | `{verdict}: {reason}` |
| Context/background | Compact paragraph, no headers inside | One flowing paragraph |

### Bullets vs Paragraphs

- ≥4 independent items (order doesn't matter) → **bullets** (compliance drops in paragraph form)
- ≤3 related items with causal dependency → **paragraph** (preserves logic chain)
- Reasoning context + discrete rules → **paragraph first, then bullets**

## Language Rule

| Content | Language | Rationale |
|---------|----------|-----------|
| Instructions, rules, constraints | English | Usually tokenizes compactly; keep one language per instruction set |
| Example outputs | Target language | Model captures tone/style |
| Data, documents | Original language | Don't translate — meaning loss |

Non-Latin-script instructions often tokenize into more tokens for the same meaning; measure with the target model's tokenizer before assuming a ratio.

## Interfaces Before Examples

Examples narrow exploration: the model copies their shape instead of using judgment. Design the interface first.

- Behavior: express it through the tool or file shape (enum values, named parameters, one stated invariant) rather than sample calls.
- Output format or tone: a single example is fine when a schema cannot carry it; use XML with `id` attributes.
- Spec: prefer a reference in code (test suite, HTML mockup, function to port) over a prose description.
- Audit any remaining example when instructions change: stale examples silently contradict new rules.

## System Prompt Altitude

The Goldilocks zone between two failure modes:

| Extreme | Problem |
|---------|---------|
| Brittle if-else logic | Fragile, high maintenance, breaks on new scenarios |
| Vague guidance ("be helpful") | Non-deterministic, model must guess |

**Optimal**: specific enough to guide behavior, flexible enough for model heuristics.

Practice:
1. Start with minimal prompt (essential intent only)
2. Test with best available model
3. Add instructions ONLY when testing shows a failure mode
4. Test: "would removing this line change model behavior?" If no → delete it

## Positive Framing

Prefer stating the wanted behavior. A bare prohibition ("don't hallucinate", "never do X") names the unwanted behavior without saying what to do instead; keep a prohibition when it marks a hard boundary, and pair it with the positive action.

| ❌ Negative | ✅ Positive |
|---|---|
| Don't hallucinate | Only cite sources from provided documents |
| Never use informal language | Use formal academic tone |
| Don't include code | Respond in prose only |

## Constraint-First Pattern

Put constraints BEFORE the task. Model reads constraints first → applies during generation.

```
Format: 3 bullet points, each under 15 words. Vietnamese. No introduction.

Task: Summarize the attached article.
```

Not:
```
Summarize the attached article. Keep it to 3 bullet points...
```

## Anti-Patterns

| Anti-Pattern | Why it fails | Fix |
|---|---|---|
| Instruction stacking (>10 rules) | Attention degrades monotonically per rule | 5-8 critical rules; progressive disclosure for rest |
| Conflicting instructions | Model oscillates or picks randomly | Audit for contradictions; use conditional framing |
| Overly prescriptive (line-by-line HOW) | Limits model problem-solving | Specify WHAT + WHY, let model decide HOW |
| Cargo-culting CoT | Adds variability on simple tasks | Measure effectiveness before applying |
| Missing output schema | Downstream parsers break silently | Always define schema explicitly |
| Auto-generated instructions | Bloated, not universally applicable | Craft every line deliberately |
| Using prompt as linter | Expensive, unreliable, wastes budget | Use deterministic tools (Biome, eslint) + hooks |

## Cross-Model Awareness

Observations as of 2026-10-21, not product policy; recheck against the vendor's current prompting guide when the model changes ([Claude prompt engineering overview](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/overview)).

| Model type | Prompting style |
|---|---|
| Reasoning (o-series, extended thinking) | High-level goals. Trust the model. Don't say "think step-by-step" — it manages its own reasoning. |
| Standard GPT / non-thinking | Explicit step-by-step. Define exact output. |
| Claude 5 family (as of 2026-10-21) | Calibrates length to complexity. Follows "be conservative" literally. Shorter by default. (Local observation.) |

## The Iteration Rule

- First prompt is never optimal — treat as code: version, test, iterate
- Define success criteria before writing the prompt
- Add instructions only when testing shows they're needed
- Pin model versions in production (e.g., `gpt-4.1-2025-04-14`)
- Re-evaluate prompts on model upgrades — behavior shifts between versions

## Application to Skills & Rules

When writing SKILL.md or setup/rules/*.md in this repo:

- SKILL.md body < 150 lines — move detail to `references/`
- Write instructions in English, imperative form
- One rule per dash-item — atomic, testable
- Use progressive disclosure: SKILL.md → references/ → scripts/
- Constraint-first in every instruction block
- Include 2-3 examples in target output language
- Delete any line that doesn't change model behavior
