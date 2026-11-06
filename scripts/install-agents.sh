#!/usr/bin/env bash
# install-agents.sh — Install the harness agents (agents/mono-*.md) for Claude Code.
# Safe to run multiple times: an identical file is left alone, a differing one
# is backed up as <name>.md.backup.<timestamp> before it is overwritten.
#
# Usage:
#   bash scripts/install-agents.sh
#   CLAUDE_DIR=/some/dir bash scripts/install-agents.sh   # default: $HOME/.claude

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
DEST_DIR="$CLAUDE_DIR/agents"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

mkdir -p "$DEST_DIR"
count=0
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
  echo "  ✓ installed: $dest"
done

if [ "$count" -eq 0 ]; then
  echo "no agents found in $REPO_DIR/agents" >&2
  exit 1
fi
echo "✓ $count agent(s) installed to $DEST_DIR"
