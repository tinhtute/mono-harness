#!/usr/bin/env bash
# verify-doc-links.sh - fail on broken repo-relative cross-references in tracked docs.
#
# A claim is a backtick-quoted, path-like token or a markdown-link target. A
# backtick claim must start at one of the repository's own top-level doc surfaces
# and resolves from the repository root or the referencing file's directory. A
# markdown link resolves relative to the referencing file. Anything outside the
# allowlist is skipped by default, so illustrative example paths stay harmless.
#
# Exit 0 = no findings, 1 = broken references, 2 = malformed .claimignore.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

IGNORE_FILE=".claimignore"
ALLOWED_PREFIXES="skills docs rules cli references"

# --- ignore file: every non-comment line must carry a `# reason` -------------
ignore_patterns=()
if [ -f "$IGNORE_FILE" ]; then
  lineno=0
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    case "$line" in
      '' | '#'*) continue ;;
    esac
    case "$line" in
      *'#'*) : ;;
      *)
        printf 'ERROR: %s:%d has no `# reason` comment: %s\n' \
          "$IGNORE_FILE" "$lineno" "$line" >&2
        exit 2
        ;;
    esac
    pattern="${line%%#*}"
    pattern="${pattern%"${pattern##*[![:space:]]}"}"
    if [ -n "$pattern" ]; then
      ignore_patterns+=("$pattern")
    fi
  done <"$IGNORE_FILE"
fi

# --- file list: a real file, never a shell variable --------------------------
# A multi-line variable expanded into grep is silently treated as a pattern by
# some grep implementations (ugrep), which produces a false clean.
LIST="$(mktemp)"
trap 'rm -f "$LIST"' EXIT
# .harness/plans/** is excluded by category, not by exception: a plan artifact must be
# able to name a file it will create, and a completed plan is an immutable record
# of paths as they were. Neither is a live cross-reference.
# .harness/ exists only once zharness has installed the managed set.
roots="docs cli skills"
[ -d .harness ] && roots=".harness $roots"
# shellcheck disable=SC2086 # word-split on purpose: fixed directory names
find $roots -name '*.md' -type f \
  -not -path '.harness/plans/*' >"$LIST"
for extra in AGENTS.md README.md; do
  if [ -f "$extra" ]; then
    printf '%s\n' "$extra" >>"$LIST"
  fi
done

# --- scan --------------------------------------------------------------------
findings=0
REMOVED_HITS=0
CLAIM_PATTERN='[A-Za-z0-9._/-]+/[A-Za-z0-9._/-]+\.(md|sh|go|json|yml|toml|py)'
while IFS= read -r file; do
  dir="$(dirname "$file")"
  claims="$(
    {
      grep -ohE '`'"$CLAIM_PATTERN"'`' "$file" 2>/dev/null |
        tr -d '`' |
        while IFS= read -r claim; do
          printf 'backtick:%s\n' "$claim"
        done || true
      grep -ohE '\]\('"$CLAIM_PATTERN" "$file" 2>/dev/null |
        grep -oE "$CLAIM_PATTERN" |
        while IFS= read -r claim; do
          printf 'link:%s\n' "$claim"
        done || true
    } | sort -u
  )"
  [ -n "$claims" ] || continue

  while IFS=: read -r kind claim; do
    [ -n "$claim" ] || continue

    # v0.15 removed surfaces: immutable audit/history records still cite files
    # deleted by the zharness-v015-slim p2-delete-cli phase (plan pruned from
    # docs/plans/completed/; see `git show 3bab3c0:docs/plans/completed/zharness-v015-slim.md`). The removal is
    # archived in the root CHANGELOG v0.15 section. Known-removed claims pass
    # existence checks but are counted, never silently dropped.
    case "$claim" in
      cli/internal/application/*|cli/internal/domain/*|cli/internal/infrastructure/*|cli/docs/SCHEMA.md|cli/docs/STATE.md)
        REMOVED_HITS=$((REMOVED_HITS + 1))
        continue ;;
    esac

    case "$claim" in
      *'{'* | *'}'* | *'*'* | '//'*) continue ;;
    esac

    if [ "$kind" = "link" ]; then
      relative=0
      case "$claim" in
        ./* | ../*) relative=1 ;;
      esac

      if [ "$relative" -eq 0 ]; then
        first="${claim%%/*}"
        allowed=0
        for prefix in $ALLOWED_PREFIXES; do
          if [ "$first" = "$prefix" ]; then
            allowed=1
            break
          fi
        done
        if [ "$allowed" -eq 0 ]; then
          continue
        fi
      fi

      if [ -e "$dir/$claim" ]; then
        continue
      fi
    else
      relative=0
      case "$claim" in
        ./* | ../*) relative=1 ;;
      esac

      if [ "$relative" -eq 0 ]; then
        first="${claim%%/*}"
        allowed=0
        for prefix in $ALLOWED_PREFIXES; do
          if [ "$first" = "$prefix" ]; then
            allowed=1
            break
          fi
        done
        if [ "$allowed" -eq 0 ]; then
          continue
        fi
      fi

      if [ "$relative" -eq 1 ]; then
        if [ -e "$dir/$claim" ]; then
          continue
        fi
      elif [ -e "$claim" ] || [ -e "$dir/$claim" ]; then
        continue
      fi
    fi

    skip=0
    for pattern in ${ignore_patterns[@]+"${ignore_patterns[@]}"}; do
      case "$claim" in
        *"$pattern"*)
          skip=1
          break
          ;;
      esac
    done
    if [ "$skip" -eq 1 ]; then
      continue
    fi

    printf '%s -> %s\n' "$file" "$claim"
    findings=$((findings + 1))
  done <<<"$claims"
done <"$LIST"

if [ "$findings" -gt 0 ]; then
  printf '\n%d broken doc cross-reference(s).\n' "$findings" >&2
  exit 1
fi

printf 'doc links OK (0 findings; %d claim(s) under known-removed v0.15 surfaces)\n' "$REMOVED_HITS"
