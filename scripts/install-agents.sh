#!/usr/bin/env bash
# install-agents.sh — Install the harness agents (agents/mono-*.md) for Claude Code.
# Safe to run multiple times: an identical file is left alone, a differing one
# is backed up as <name>.md.backup.<timestamp> before it is overwritten.
# The pre-rename agents (lead, worker, verifier) are retired, never deleted:
# each is renamed to <name>.md.retired.<timestamp>.
#
# Usage:
#   bash scripts/install-agents.sh
#   CLAUDE_DIR=/some/dir bash scripts/install-agents.sh   # default: $HOME/.claude

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
DEST_DIR="$CLAUDE_DIR/agents"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LEGACY_AGENTS="lead worker verifier"

mkdir -p "$DEST_DIR"
count=0
changed=0
for src in "$REPO_DIR/agents/"*.md; do
  [ -f "$src" ] || continue
  dest="$DEST_DIR/$(basename "$src")"
  count=$((count + 1))
  if [ -f "$dest" ]; then
    if cmp -s "$src" "$dest"; then
      echo "  = unchanged: $dest"
      continue
    fi
    cp "$dest" "$dest.backup.$TIMESTAMP"
    echo "  ↩ backed up: $dest -> $dest.backup.$TIMESTAMP"
  fi
  cp "$src" "$dest"
  changed=$((changed + 1))
  echo "  ✓ installed: $dest"
done

if [ "$count" -eq 0 ]; then
  echo "no agents found in $REPO_DIR/agents" >&2
  exit 1
fi

retired=0
for name in $LEGACY_AGENTS; do
  legacy="$DEST_DIR/$name.md"
  [ -f "$legacy" ] || continue
  mv "$legacy" "$legacy.retired.$TIMESTAMP"
  retired=$((retired + 1))
  echo "  ⊘ retired: $legacy -> $legacy.retired.$TIMESTAMP"
done

echo "✓ $count agent(s) in $DEST_DIR: $changed installed or updated, $((count - changed)) unchanged, $retired legacy retired"
