---
name: git
version: "1.3.0"
model: haiku
description: "Git operations with conventional commits. Use for staging, committing, pushing, PRs, merges. Auto-splits commits by type/scope. Security scans for secrets."
argument-hint: "cm|cp|pr|merge [args]"
compatibility: Designed for Claude Code
---

`git` owns no harness entity; a missing, stale, or broken harness never blocks it, and no harness command gates it. `cm`/`cp` follow the steps below. `pr`/`merge`: read `{baseDir}/references/workflow.md` now and follow it. Load `{baseDir}/references/branch-management.md` or `gh-cli-guide.md` only when the task needs them.

<security>
- Block destructive operations without confirmation
</security>

## Arguments

- `cm` — stage files & create commit(s)
- `cp` — stage, commit, and push
- `pr [to-branch] [from-branch]` — create a pull request (defaults: the repository's resolved base branch, current branch)
- `merge [to-branch] [from-branch]` — merge branches (defaults: the repository's resolved base branch, current branch)

No argument: ask with the agent's question tool (`AskUserQuestion` on Claude Code) (header "Git Operation", question "What would you like to do?", options `cm`, `cp`, `pr`, `merge`).

## Commit (`cm`, `cp`)

### Step 1: Stage + analyze

Review what changed first, then stage explicit paths — never a blanket stage, which the Anti-Patterns section below forbids for catching `.env`, secrets, and `node_modules`.

```bash
git status --porcelain
git add path/to/file1 path/to/file2
git diff --cached --stat && git diff --cached --name-only
```

Leave anything you did not mean to commit unstaged; if `git status --porcelain` lists a path you cannot account for, ask before staging it.

### Step 2: Security check

A repo with this harness's pre-commit hook blocks staged secrets itself. Elsewhere, run `{baseDir}/scripts/scan-staged.sh`. It prints `ok` (exit 0) or one `secret: file:line` / `file: path` line per hit (exit 1), never the value.

**Exit 1: STOP, report its lines as-is, suggest env vars or `.gitignore`, offer `git restore --staged <file>`. Do not commit.**

### Step 3: Split decision

Run `{baseDir}/scripts/group-staged.sh`; it prints `kind: file` per staged file (`deps`, `config`, `test`, `docs`, `code`). It already keeps a manifest with its lockfile (`deps`) and a co-located test with its source (`code`), because splitting either yields a commit that was never built or tested. Treat its grouping as final unless a file is plainly misfiled.

**Single commit:** same type/scope, files ≤ 3, lines ≤ 50.
**Multiple commits:** mixed types/scopes — one commit per group (`chore(config)`, `chore(deps)`, `test`, `feat`/`fix` for `code:`, `docs`). Reset and re-stage per group: `git reset && git add file1 file2 && git commit -m "type(scope): desc"`.

Search for related GitHub issues and note them in the commit/PR body.

### Step 4: Commit

```bash
git commit -m "type(scope): description"
```

**Format:** `type(scope): description`, under 72 characters, present tense/imperative ("add" not "added"), no trailing period, focused on WHAT not HOW.

**Types (priority order):** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `build`, `ci`.

**Never include AI attribution** ("Generated with Claude", "Co-Authored-By: Claude", or any AI reference) in the commit message.

### Step 5: Push (`cp`, or `cm` + explicit push request only)

```bash
git status && git log origin/$(git rev-parse --abbrev-ref HEAD)..HEAD --oneline 2>/dev/null || echo "NO_UPSTREAM"
git push origin HEAD   # or: git push -u origin HEAD if NO_UPSTREAM
```

**Never force push to `main`, `master`, `production`, `prod`, or `release/*`.** On a feature branch, force push only on explicit user request, and warn: "Force push rewrites history. Collaborators may lose work."

## Output Format

Report the summary only, never raw command output.

**Console output:**
```
✓ staged: N files (+X/-Y lines)
✓ security: passed
✓ commit: HASH type(scope): description
✓ pushed: yes/no
```

## Error Handling

| Error | Action |
|---|---|
| Secrets detected | Block commit, show files |
| No changes | Exit cleanly |
| `rejected - non-fast-forward` / push rejected | Suggest `git pull --rebase`, resolve, push again |
| No upstream branch | `git push -u origin HEAD` |
| Merge conflicts | Suggest manual resolution |
| Authentication failed | Check `gh auth status` or SSH keys |

## Anti-Patterns

- Staging everything with `git add -A` instead of specific files — catches `.env`, secrets, `node_modules`.
- Single commit when changes span multiple types/scopes — "one commit is cleaner" produces an un-reviewable diff, impossible to revert selectively.
- Skipping the security scan because "it's just config" — config files often contain secrets or tokens.
- Force pushing without explicit user confirmation — overwrites upstream work silently.

Exit condition — `cm`/`cp`: changes staged, security-scanned, committed (single or split by group); `cp` additionally pushed.

Defer to: `check` for code review before committing.
