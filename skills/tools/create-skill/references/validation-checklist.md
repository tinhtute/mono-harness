# Skill Validation Checklist

Quick validation before packaging. Run `scripts/package_skill.py` for automated checks.

## Critical (Must Pass)

### Metadata
- [ ] `name`: kebab-case, descriptive
- [ ] `description`: under 200 characters, specific triggers, not generic

### Size Limits
- [ ] SKILL.md: under 150 lines
- [ ] Each reference file: under 150 lines
- [ ] No info duplication between SKILL.md and references

### Structure
- [ ] Every reference is pointed to with a load trigger
- [ ] Ends with a `Defer to:` line naming sibling skills
- [ ] No host boilerplate copied in (persona, prefixes, question-tool wording)
- [ ] SKILL.md exists with valid YAML frontmatter
- [ ] Unused example files deleted
- [ ] File names: kebab-case, self-documenting

## Scripts (If Applicable)

- [ ] Tests exist and pass
- [ ] Cross-platform (Node.js/Python preferred)
- [ ] Env vars: respects hierarchy `process.env` > `$HOME/.claude/skills/${SKILL}/.env` (global) > `$HOME/.claude/skills/.env` (global) > `$HOME/.claude/.env` (global) > `./.claude/skills/${SKILL}/.env` (cwd) > `./.claude/skills/.env` (cwd) > `./.claude/.env` (cwd)
- [ ] Dependencies documented (requirements.txt, .env.example)
- [ ] Manually tested with real use cases

## Quality

### Writing Style
- [ ] Imperative form: "To accomplish X, do Y"
- [ ] Third-person metadata: "This skill should be used when..."
- [ ] Concise, no fluff

### Practical Utility
- [ ] Teaches *how* to do tasks, not *what* tools are
- [ ] Based on real workflows
- [ ] Description names concrete trigger phrases
- [ ] Interfaces (inputs, outputs, done criteria) over sample transcripts

## Integration

- [ ] No duplication with existing skills
- [ ] Related topics consolidated (e.g., cloudflare + docker → devops)
- [ ] Composable with other skills

## Automated Validation

Run packaging script to validate:

```bash
scripts/package_skill.py <path/to/skill-folder>
```

Checks performed:
- YAML frontmatter format
- Required fields present
- Description length (<200 chars)
- Directory structure
- File organization

Fix all errors before distributing.

## Subagent Delegation Enforcement

When a skill requires subagent delegation (via the Agent tool):

1. **Name the agent and the reason** - "Spawn the `tester` subagent so test output stays out of the main context"
2. **Show the call** - Name the agent type, the prompt, and what it should return
3. **State the done check** - Say what proves the subagent ran (its report, a result file)
4. **Mark requirements clearly** - Use a table listing which steps delegate and why
5. **Say who does what** - "The subagent runs the tests; the main agent reads its report"

**Anti-pattern (weak):**
```
- Use `tester` agent for testing
```

**Correct pattern (enforceable):**
```
- Spawn the `tester` subagent to run the tests and report failures, so test logs stay out of the main context
```
