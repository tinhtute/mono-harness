# GitHub CLI Command Patterns

`scripts/gh-search.sh` runs the known-good calls: `preflight`, `branch`, `search`, `tree`, `ls`, `fetch`, `lines`. Run it with no arguments for usage. This file keeps what the script does not do: ad-hoc tree filters, local refinement of cached files, and error, cache and scope rules.

## Pattern 3: Filter Tree Paths

Filter tree output with jq:
```bash
jq -r '.tree[] | select(.type=="blob" and (.path | startswith("src/"))) | .path' tree.json | head
```

Examples:
```bash
# Find all TypeScript files
jq -r '.tree[] | select(.type=="blob" and (.path | endswith(".ts"))) | .path' tree.json

# Find files in specific directory
jq -r '.tree[] | select(.type=="blob" and (.path | startswith("pkg/cmd/"))) | .path' tree.json

# Count files by extension
jq -r '.tree[] | select(.type=="blob") | .path' tree.json | sed 's/.*\.//' | sort | uniq -c
```

## Pattern 6: Refine Locally After Caching

Use local tools on cached files:
```bash
# Search with ripgrep (line numbers)
rg -n '<pattern>' ".zharness/cache/github/$REPO"

# Search with grep (line numbers)
grep -rn '<pattern>' ".zharness/cache/github/$REPO"

# Find files
find ".zharness/cache/github/$REPO" -name "*.ts"

# Count lines
wc -l ".zharness/cache/github/$REPO/$FILE"
```

Examples:
```bash
REPO='cli/cli'

# Find all occurrences of "NewCmd"
rg -n "NewCmd" ".zharness/cache/github/$REPO"

# Find TypeScript files
find ".zharness/cache/github/$REPO" -name "*.ts"

# Search for imports
rg -n "^import.*from" ".zharness/cache/github/$REPO"
```

## Error Handling

### Private Repo Access
If `gh api` returns 404 or 403:
```bash
gh api "repos/owner/private-repo/contents/file.ts?ref=main" 2>&1 | grep -q "404\|403"
if [ $? -eq 0 ]; then
  echo "Access denied or repo not found"
fi
```

### Rate Limiting
Check rate limit status:
```bash
gh api rate_limit --jq '.rate | {limit, remaining, reset: (.reset | strftime("%Y-%m-%d %H:%M:%S"))}'
```

### Validate Repo Exists
```bash
gh repo view "$REPO" --json name,owner,defaultBranchRef > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Repo not found or not accessible: $REPO"
fi
```

## Cache Management

The cache persists across sessions with no automatic cleanup; the user clears it with `trash .zharness/cache/github/` (or a single repo).

## Scope Limits

- Max 5 repos per query (use --repo filters to narrow)
- Max 30 search results per gh search call (default)
- If scope too broad, ask user to narrow before searching
- Private repos: if 404/403, report access constraint clearly

## Anti-Patterns
- Deep-diving before `gh repo view` confirms the repo exists
- Citing paths not confirmed at HEAD — cached or outdated results go stale
