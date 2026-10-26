# Context Engineering for Skills

Current models follow instructions closely and generalize well. A skill fails more often from too much context than from too little. Give the skill the outcome, the interfaces, and the judgment calls. Leave out what the model already does well.

## Rules

| Rule | Do | Instead of |
|---|---|---|
| Judgment over rules | State the goal and the trade-off, e.g. "prefer the smallest loop that shows the user's symptom" | Long lists of MUST/NEVER rules for behavior the model already gets right |
| Interfaces before examples | Define inputs, outputs, file formats, commands, and done criteria | Sample transcripts. Models copy their surface details |
| Progressive disclosure | Keep the SKILL.md body to the trigger, outcome, and routing. Move detail into `references/` and name the trigger that loads each file | Inlining every procedure "just in case" |
| One source of truth | Each fact lives in one file. Point to it from everywhere else | Repeating the same rule in SKILL.md, a reference, and the host rules |
| No host boilerplate | Leave out persona, voice, prefixes, question-tool wording, and "be concise" | Copying global rules into every skill. The host already loads them |
| Skill-specific lead line | One sentence naming what this skill reports first, e.g. "Lead with the verdict" | Generic "be direct" lines, or a lead line beside an Output section that already says it |
| Explicit boundaries | End with `Defer to:` and name the sibling skill for each nearby task | Overlapping descriptions that make two skills trigger on the same request |

## Progressive Disclosure

Each level loads only when the one above it calls for it:

1. **Frontmatter `description`** is always in context. It decides triggering, so name the concrete triggers.
2. **SKILL.md body** loads on trigger. It holds the outcome contract, the modes or steps, and a pointer to each reference.
3. **`references/*.md`** load on demand. Write every pointer as a trigger plus a file: "For a flaky bug, read the flaky-bugs reference." A bare list of files is not enough.
4. **`scripts/`** run without being loaded into context. Use them for deterministic work.

Move a block into `references/` when it applies only to some modes, when it runs longer than about 15 lines, or when it is a lookup table. Keep it in SKILL.md when every run needs it.

## Examples: When They Earn a Place

Add an example only when an interface cannot express the point, such as tone or a judgment boundary. Keep it in `references/` and mark it as illustrative. Evaluation data belongs in its own directory and never in the body.

## Self-Check Before Delivering

- Can anything in the body be deleted without changing behavior? Delete it.
- Does any line repeat a host rule or another file? Replace it with a pointer.
- Does every reference have a trigger that tells the model when to load it?
- Is there a `Defer to:` line?
- Does `bash scripts/ci/validate-skill.sh <path>` pass? In this repo it checks for `references/` and the defer boundary.
