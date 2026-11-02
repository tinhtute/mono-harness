# Claude Code Setup

Bootstrap kit for a new machine. Installs global `~/.claude/` config from this repo.

## Quick start

```bash
bash setup/install.sh
```

After install: edit `~/.claude/settings.json` → set `ANTHROPIC_AUTH_TOKEN`.

## Contents

| File | Installed to | Notes |
| :--- | :--- | :--- |
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | Voice, hard rules, working style |
| `settings.json` | `~/.claude/settings.json` | Template; only copied if file doesn't exist |
| `statusline/` | `~/.claude/statusline.{sh,py}` | Statusline installers, run by `install.sh` (slim) or by hand (`setup-pulse.sh`) |
| `install-git-hooks.sh` | `.git/hooks/` of this repo | Pre-commit/pre-push guards; not run by `install.sh` |
| `rules/*.md` | `~/.claude/rules/` | English coaching; retires rules folded into `CLAUDE.md` |

## Prerequisites

- **Node.js** v18+ (required by `npx skills add` in `install.sh`)
- **jq** (required by statusline) — `brew install jq` or `apt install jq`
- SSH key configured for `git@github.com:therealtinhtute/mono-harness.git`

## Hooks overview

Tool guards (`rm` → `trash`, sensitive files, private URLs to web tools) and the compaction rule reminder live in the `ninja-kit` Claude mod (`setup/mods/ninja-kit`, installed to `~/.claude/mods/ninja-kit` and loaded through `CLAUDE_CODE_PLUGIN_DIRS`); test it with `claude plugin test setup/mods/ninja-kit`.

The `cache-guard` mod (`setup/mods/cache-guard`, installed and loaded the same way) shows a band above the prompt when the model or effort changes while context is at or above `threshold` percent (default 40, set under `pluginConfigs."cache-guard".options`), with Compact and Skip buttons, because the switch drops the prompt cache; test it with `claude plugin test setup/mods/cache-guard`.


from therealTINHTUTE with love
