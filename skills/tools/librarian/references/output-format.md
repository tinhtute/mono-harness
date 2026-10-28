# Output Format for GitHub Research Findings

Structured Markdown format for research findings, reported inline or saved to `docs/research/{topic}.md` when a plan cites them.

## File Structure

```markdown
---
title: {topic}
description: {one-line summary of findings}
status: active
created: YYYY-MM-DD
tags: [github, {repo-name}, {additional-tags}]
---

## Summary
(1-3 sentences)

## Locations
- `path` or `path:lineStart-lineEnd` — what is here and why it matters
- Include GitHub blob/tree URL when helpful
- If nothing found: `- (none)`

## Evidence
- `path:lineStart-lineEnd` — short note on what this proves
- Include concise snippets only when they add clarity
- For path-only answers, command evidence is enough

## Searched (optional, if incomplete/not found)
- Queries, filters, and probes used
- Scope and limits

## Next Steps (optional)
- 1-3 narrow fetches/checks to resolve remaining ambiguity
```

## Section Details

### Frontmatter

**Required fields:**
- `title` — topic or query being researched
- `description` — one-line summary of what was found
- `status` — `active` (current findings) or `archived` (superseded)
- `created` — date in YYYY-MM-DD format
- `tags` — array with `github` + repo name + relevant tags

**Example:**
```yaml
---
title: NewCmdRoot function in cli/cli
description: Found main definition in pkg/cmd/root/root.go with 3 usage sites
status: active
created: 2026-04-23
tags: [github, cli, cobra, command-structure]
---
```

### Summary Section

**Purpose:** High-level answer in 1-3 sentences.

**Guidelines:**
- Lead with the answer, not the process
- State confidence level if partial
- Mention key repos/files

**Examples:**

✅ **Good:**
```markdown
## Summary
The `NewCmdRoot` function is defined in `cli/cli:pkg/cmd/root/root.go:42-56` and
returns a configured `*cobra.Command`. Found 3 usage sites across the codebase.
```

✅ **Good (partial):**
```markdown
## Summary
Found 12 examples of `useEffect` usage in facebook/react repo (limited to 20 search
results). All examples follow the hooks pattern with dependency arrays.
```

❌ **Bad:**
```markdown
## Summary
I searched the repo and found some files and then cached them and read them.
(describes process, not findings)
```

### Locations Section

**Purpose:** List where things are, with brief context.

**Format:**
- Cached file: `.zharness/cache/github/owner/repo/path:lineStart-lineEnd`
- Uncached path: `owner/repo:path`
- Include GitHub URL when helpful: `https://github.com/owner/repo/blob/ref/path#L42-L56`

**Guidelines:**
- One bullet per location
- Brief note on what's there and why it matters
- If nothing found, write `- (none)`

**Examples:**

✅ **Good:**
```markdown
## Locations
- `.zharness/cache/github/cli/cli/pkg/cmd/root/root.go:42-56` — main definition, returns *cobra.Command
  - https://github.com/cli/cli/blob/trunk/pkg/cmd/root/root.go#L42-L56
- `.zharness/cache/github/cli/cli/pkg/cmd/root/root_test.go:15-20` — test usage
- `.zharness/cache/github/cli/cli/cmd/gh/main.go:8` — import statement
```

✅ **Good (structure only):**
```markdown
## Locations
- cli/cli:pkg/cmd/root/ — command root package
- cli/cli:pkg/cmd/version/ — version command
- cli/cli:pkg/cmd/auth/ — auth commands
(from tree API, files not cached)
```

❌ **Bad:**
```markdown
## Locations
- Found it in root.go
(no path, no line range, no context)
```

### Evidence Section

**Purpose:** Prove your claims with cited snippets or command output.

**Guidelines:**
- One bullet per piece of evidence
- Include line-numbered snippets (5-15 lines max)
- Brief note on what this proves
- For path-only claims, command output is sufficient

**Examples:**

✅ **Good (code evidence):**
```markdown
## Evidence
- `.zharness/cache/github/cli/cli/pkg/cmd/root/root.go:42-46` — function signature confirms return type

    42  func NewCmdRoot() *cobra.Command {
    43      cmd := &cobra.Command{
    44          Use:   "gh",
    45          Short: "GitHub CLI",
    46      }
```

✅ **Good (path evidence):**
```markdown
## Evidence
- Tree API output confirms directory structure:
  ```
  pkg/cmd/root/root.go
  pkg/cmd/root/root_test.go
  pkg/cmd/version/version.go
  ```
```

✅ **Good (search evidence):**
```markdown
## Evidence
- `gh search code "useEffect" --repo facebook/react --limit 20` returned 12 matches
- All matches in `packages/react/src/` directory
- Pattern: `useEffect(() => { ... }, [deps])`
```

### Searched Section (Optional)

**Purpose:** Document search scope when results are incomplete or nothing found.

**When to include:**
- No results found
- Partial results (hit search limits)
- Narrow scope (only searched specific repos)

**Examples:**

✅ **Good:**
```markdown
## Searched
- `gh search code "NonExistentFunction" --repo cli/cli --limit 30` — 0 results
- `gh api repos/cli/cli/git/trees/trunk?recursive=1` — checked full tree, no matches
- Scope: cli/cli repo only, trunk branch
```

✅ **Good (partial):**
```markdown
## Searched
- `gh search code "useEffect" --owner facebook --limit 20` — 12 results (may be more)
- Cached top 3 examples for citation
- Scope: facebook org repos, limited to 20 results
```

### Next Steps Section (Optional)

**Purpose:** Suggest concrete next actions to resolve remaining questions.

**Guidelines:**
- 1-3 specific commands or checks
- Only include if there's genuine ambiguity
- Make suggestions actionable

**Examples:**

✅ **Good:**
```markdown
## Next Steps
- Search other repos in cli org: `gh search code "NewCmdRoot" --owner cli --limit 30`
- Check if pattern exists in other CLI tools: `gh search code "NewCmd" --limit 50`
```

✅ **Good:**
```markdown
## Next Steps
- Fetch and inspect test file to understand usage: `gh api repos/cli/cli/contents/pkg/cmd/root/root_test.go`
- Check git history for when this was introduced: `gh api repos/cli/cli/commits?path=pkg/cmd/root/root.go`
```

❌ **Bad:**
```markdown
## Next Steps
- Do more research
- Look at other files
(too vague, not actionable)
```

## Complete Example

```markdown
---
title: useEffect hook usage in React
description: Found 12 examples in facebook/react, all follow hooks pattern with deps
status: active
created: 2026-04-23
tags: [github, react, hooks, useEffect]
---

## Summary
Found 12 examples of `useEffect` usage in facebook/react repo (limited to 20 search
results). All examples follow the hooks pattern with dependency arrays. Cached 3
representative examples for detailed citation.

## Locations
- `.zharness/cache/github/facebook/react/packages/react/src/ReactHooks.js:150-165` — main hook implementation
  - https://github.com/facebook/react/blob/main/packages/react/src/ReactHooks.js#L150-L165
- `.zharness/cache/github/facebook/react/packages/react-reconciler/src/ReactFiberHooks.js:1200-1250` — reconciler implementation
- `.zharness/cache/github/facebook/react/packages/react-dom/src/client/ReactDOMComponent.js:89-95` — usage example

## Evidence
- `.zharness/cache/github/facebook/react/packages/react/src/ReactHooks.js:150-155` — hook signature

    150  export function useEffect(
    151    create: () => (() => void) | void,
    152    deps: Array<mixed> | void | null,
    153  ): void {
    154    const dispatcher = resolveDispatcher();
    155    return dispatcher.useEffect(create, deps);

- Search confirmed pattern: all 12 results use `useEffect(() => {...}, [deps])` format

## Searched
- `gh search code "useEffect" --repo facebook/react --limit 20` — 12 results
- Scope: facebook/react repo only, may be more examples beyond limit
- Cached top 3 for detailed analysis

## Next Steps
- Search for `useEffect` without deps array: `gh search code "useEffect(() =>" --repo facebook/react`
- Check React docs for official examples: `gh search code "useEffect" --repo facebook/react --path docs/`
```

## Tips

1. **Lead with findings, not process** — readers want answers, not methodology
2. **Cite precisely** — line ranges make findings verifiable
3. **Keep snippets short** — 5-15 lines, not 50
4. **State scope clearly** — "searched X with limit Y" prevents overconfidence
5. **Include URLs** — GitHub blob links help readers verify
6. **Use optional sections wisely** — only include Searched/Next Steps when needed

## Saved Findings

Report findings inline. Save to `docs/research/{topic}.md` only when a plan will cite them, with frontmatter:
```yaml
---
title: {topic}
description: {one-line summary}
status: active
created: {date}
tags: [github, {repo-name}]
---
```
