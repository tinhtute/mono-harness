#!/bin/bash
# Install git hooks for skill validation + v0.15 fail-closed guards
# Usage: ./install-git-hooks.sh [--force]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

# ZGUARD-CORE-BEGIN
# Core guard logic shared by the local pre-commit hook and the CI re-check.
# Two wrappers feed it pairs of plan-file contents:
#   - pre-commit: staged blob vs HEAD blob ("reads staged bytes, trusts no marker")
#   - CI job:     pushed HEAD blob vs parent blob
# Guards implemented here (zharness v0.15 p1-hook-guard, review-hardened v2, R5 one-plan):
#   R2: re-execute every nested proof command of newly added ## Validation
#       entries whose anchored verdict is APPROVED or APPROVE_WITH_REQUESTS
#       (`sh -c`, 5-minute timeout each where timeout/gtimeout is available,
#       unbounded otherwise); any non-zero exit rejects, naming
#       the failing command and its output tail. REQUEST_CHANGES proof is
#       never re-executed. No pass marker is read.
#   R3: reject `judge: same-session` on any newly added entry of a plan whose
#       frontmatter carries `lane: high-risk`. Matching strips backticks, so
#       the repository's canonical judge: `same-session` form is caught too.
#   Hardening from independent review (v2): "new entry" means its FULL TEXT
#   differs from every old-side Validation entry — timestamp-set diffing was
#   removed because replaying an existing timestamp made fresh APPROVED text
#   invisible; verdict detection is anchored to a `verdict:` token so prose
#   mentions cannot shadow it; proof bullets accept any indent >= 2 spaces;
#   an approvable verdict citing zero proofs is rejected as malformed instead
#   of being waved through.
#   Hardening v3 (guard-v3 plan R1/R2): the verdict token is read from the
#   entry's FIRST LINE only — a sub-bullet quoting another verdict can never
#   select or shadow the entry's own; and an entry STARTS at any unindented
#   `- ` line, the leading timestamp being optional, so undated entries are
#   visible to both guards.
#   R4: an approvable new entry on a plan whose frontmatter names a lane must
#       list every proof class that lane requires (check.md § Lane Matrix) in
#       its `proof_classes:` line; a missing class rejects, naming it.
#       zharness_lane_required_proof mirrors the matrix; test-guards.sh
#       fails when the two disagree.
#   R6: LANE-RAISE — R3/R4 judge an entry at the effective lane: the declared
#       lane, raised to high-risk when a staged path or a commit since the
#       default branch touches an always-review path (check-risk.md).
#   FLOOR: entries already committed at ZHARNESS_GUARD_HISTORICAL_FLOOR are
#       never re-executed. A push whose before-SHA predates the v0.24 cutover
#       makes the pre-cutover entries look new, and their proofs cannot run at
#       this HEAD (the Go tree they build is deleted, and their phase ranges no
#       longer match). The floor is a constant, not a marker an agent writes:
#       an entry that did not exist at that commit is never exempt.
#   PHASE-DONE: a plan staged/pushed under .harness/plans/completed/ whose Current
#   State declares lifecycle_status: completed must show every phase
#   status: done in ## Phases and Verification. Found 2026-09-07: a handoff
#   moved a plan to completed/ with 4 of 7 phases still reading status:
#   checked, contradicting its own Current State claim on a bare re-read.

zharness_lane_of() {                       # <content-file>
  awk '/^---$/{n++; next} n==1 && /^lane:/{sub(/^lane:[ \t]*/, ""); print; exit}' "$1"
}

zharness_dump_entries() {                  # <content-file> <outdir>
  OUT="$2" awk '
    BEGIN { out = ENVIRON["OUT"] }
    $0 == "## Validation" {inv = 1; next}
    /^## / && inv         {exit}
    inv {
      if ($0 ~ /^- /) { n++; buf[n] = $0 }
      else if (n > 0) { buf[n] = buf[n] "\n" $0 }
    }
    END {
      for (i = 1; i <= n; i++) {
        # Trim trailing whitespace before hashing. Blank lines between entries
        # are absorbed into the entry above (the else-branch takes every
        # non-"- " line), which is harmless while another "## " section follows
        # the Validation block — both sides absorb the same blank line. But when
        # Validation is the LAST section, the final entry ends at EOF with no
        # trailing blank; appending a new entry below it gives it one, its
        # SHA-256 changes, and R2 re-executes an entry nobody touched (#85).
        # Both sides run through here, so trimming keeps untouched entries
        # matched rather than invalidating them.
        sub(/[[:space:]]+$/, "", buf[i])
        print buf[i] > (out "/e" sprintf("%04d", i) ".txt")
      }
    }
  ' "$1"
}

zharness_anchored_verdict() {              # <entry-body>
  # R1: the entry's verdict lives on its own first line — the unindented
  # bullet that starts the entry. A verdict token quoted deeper in the body
  # (sub-bullet, prose, quoted prior review) must not select or shadow it.
  printf '%s\n' "$1" | head -1 \
    | grep -oE '`?verdict`?[[:blank:]]*[:`][[:blank:]]*`?(APPROVED|APPROVE_WITH_REQUESTS|REQUEST_CHANGES)' \
    | grep -oE '(APPROVED|APPROVE_WITH_REQUESTS|REQUEST_CHANGES)' | head -1 || true
}

zharness_entry_proofs() {                  # <entry-body>
  printf '%s\n' "$1" \
    | grep -oE '^[[:space:]]{2,}- `[^`]+`' \
    | sed -E 's/^[[:space:]]*-[[:space:]]*`//; s/`[[:space:]]*$//' \
    | grep -v '^$' || true
}

zharness_entry_has_same_session() {        # <entry-body>, backticks stripped first
  printf '%s\n' "$1" | sed 's/[`]//g' | grep -q 'judge:[[:blank:]]*same-session'
}

zharness_entry_has_full_mode() {           # first line only, backticks stripped
  # Same first-line rule as verdicts: a quoted `mode: full` in a sub-bullet
  # of a gate entry must not look like the entry's own mode.
  printf '%s\n' "$1" | head -1 | sed 's/[`]//g' | grep -qE 'mode:[[:blank:]]*full|[[:space:]]mode[[:blank:]]+full'
}

zharness_lane_required_proof() {          # <lane> -> classes; unknown lane -> 1
  # Mirror of check.md § Lane Matrix "Required proof" column.
  case "$1" in
    tiny) echo "output" ;;
    normal) echo "output unit" ;;
    high-risk) echo "output unit integration" ;;
    *) return 1 ;;
  esac
}

zharness_effective_lane() {               # <declared-lane> <agents-md>; changed paths on stdin
  # R6 LANE-RAISE: mirror of check-risk.md § Checks "Always-review paths".
  # A declared lane below high-risk is raised when any changed path matches
  # a built-in risky path or an AGENTS.md `Always-review paths:` glob. In a
  # `case` pattern `*` also matches `/`, so `dir/**` covers the subtree.
  local lane="$1" agents="$2" p g globs gl
  [ -n "$lane" ] || { cat >/dev/null; return 0; }
  globs='.github/* .gitlab-ci.yml *Cargo.toml *Cargo.lock *package.json *package-lock.json *bun.lock *pnpm-lock.yaml *yarn.lock *go.mod *go.sum *migrations/*'
  if [ -f "$agents" ]; then
    globs="$globs $(sed -n 's/^- Always-review paths:[[:space:]]*//p' "$agents" | tr ',' ' ')"
  fi
  # read -a splits without pathname expansion: a glob must never match the cwd.
  read -r -a gl <<< "$globs"
  if [ "$lane" != "high-risk" ]; then
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      for g in "${gl[@]}"; do
        # shellcheck disable=SC2254
        case "$p" in $g) lane=high-risk; break 2 ;; esac
      done
    done
  fi
  cat >/dev/null
  echo "$lane"
}

zharness_changed_paths() {                # staged paths plus commits since the default branch
  local base
  git diff --cached --name-only 2>/dev/null
  base=$(git merge-base HEAD origin/HEAD 2>/dev/null || git merge-base HEAD origin/master 2>/dev/null) || return 0
  git diff --name-only "$base" HEAD 2>/dev/null
}

zharness_entry_missing_proof() {           # <lane> <entry-body> -> missing classes
  local req declared c missing=""
  req=$(zharness_lane_required_proof "$1") || return 0
  declared=$(printf '%s\n' "$2" | sed 's/[`]//g' \
    | grep -E '^[[:space:]]{2,}- proof_classes:' | head -1 \
    | sed -E 's/^.*proof_classes:[[:space:]]*//; s/\(.*//' | tr ',' ' ' || true)
  for c in $req; do
    case " $declared " in *" $c "*) ;; *) missing="$missing $c" ;; esac
  done
  printf '%s' "${missing# }"
}

zharness_run_proof() {                     # <command>
  # The 300s bound is defensive, not load-bearing. Resolve the wrapper at call
  # time so the guard's verdict depends on the proof's own exit code: GNU
  # `timeout` where present, coreutils `gtimeout` on macOS, otherwise run the
  # command unwrapped. Without this, every proof on a stock macOS exits 127
  # ("timeout: command not found") and the guard rejects each honest entry.
  if command -v timeout >/dev/null 2>&1; then
    timeout 300 sh -c "$1" 2>&1
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout 300 sh -c "$1" 2>&1
  else
    echo "⚠️  no timeout/gtimeout on PATH — running proof unbounded (interrupt with Ctrl+C if it hangs)" >&2
    sh -c "$1" 2>&1
  fi
}

zharness_guard_historical_floor_hashes() {  # <root> <path> <out-file> <floor>
  # Append the sha256 of every Validation entry present in <path> at <floor>.
  # A floor that does not resolve, or a path absent there, appends nothing and
  # the guard behaves exactly as it did before this exemption existed. The
  # floor is passed at the call site, never read from the environment: an
  # ambient variable would be a bypass an agent could export.
  local root="$1" path="$2" out="$3" floor="$4"
  local blob scratch efile
  git -C "$root" rev-parse --verify --quiet "${floor}^{commit}" >/dev/null 2>&1 || return 0
  scratch=$(mktemp -d)
  blob="$scratch/floor.md"
  if ! git -C "$root" show "${floor}:${path}" > "$blob" 2>/dev/null; then
    case "$path" in
      .harness/plans/completed/*)
        git -C "$root" show "${floor}:.harness/plans/active/${path##*/}" > "$blob" 2>/dev/null || : > "$blob"
        ;;
      *) : > "$blob" ;;
    esac
  fi
  if [ -s "$blob" ]; then
    mkdir -p "$scratch/e"
    zharness_dump_entries "$blob" "$scratch/e"
    for efile in "$scratch"/e/e*.txt; do
      [ -f "$efile" ] || continue
      sha256sum "$efile" | cut -d' ' -f1 >> "$out"
    done
  fi
  rm -rf "$scratch"
}

zharness_guard_entries_of_file() {         # <path> <old-file> <new-file>
  local path="$1" old="$2" new="$3" failed=0 rc_cmd cmd out body verdict cmds scratch h efile header line missing lane
  # Old-side entry hashes live in a file, not an associative array: `local -A`
  # needs bash 4+, and macOS ships bash 3.2 as /bin/bash. There the declaration
  # fails, the hex subscript is then evaluated as arithmetic, and the shell dies
  # with "value too great for base" on the first old-side entry — taking the
  # whole guard down with it. A file plus `grep -Fxq` is exact-match membership
  # with identical semantics on every bash.
  local oldhashes

  scratch=$(mktemp -d)
  mkdir -p "$scratch/o" "$scratch/n"
  zharness_dump_entries "$old" "$scratch/o"
  zharness_dump_entries "$new" "$scratch/n"

  oldhashes="$scratch/oldhashes.txt"
  : > "$oldhashes"
  for efile in "$scratch"/o/e*.txt; do
    [ -f "$efile" ] || continue
    sha256sum "$efile" | cut -d' ' -f1 >> "$oldhashes"
  done
  # FLOOR: entries already committed at the historical floor are exempt. The
  # floor is the PR #97 merge, the last commit at which every pre-cutover
  # Validation entry was already committed.
  zharness_guard_historical_floor_hashes \
    "$(git rev-parse --show-toplevel 2>/dev/null || echo .)" "$path" "$oldhashes" 4cd86cf

  lane=$(zharness_changed_paths | zharness_effective_lane "$(zharness_lane_of "$new")" "$(git rev-parse --show-toplevel 2>/dev/null || echo .)/AGENTS.md")
  for efile in "$scratch"/n/e*.txt; do
    [ -f "$efile" ] || continue
    h=$(sha256sum "$efile" | cut -d' ' -f1)
    grep -Fxq "$h" "$oldhashes" && continue
    body=$(cat "$efile")
    header=$(head -1 "$efile")

    if [ "$lane" = "high-risk" ] && zharness_entry_has_same_session "$body"; then
      failed=$((failed + 1))
      echo "" >&2
      echo "❌ R3 JUDGE GUARD REJECTED: $path" >&2
      echo "   lane is high-risk (declared, or raised by R6 for an always-review path) and a newly added ## Validation" >&2
      echo "   entry declares a same-session judge. An independent judge is required." >&2
      echo "   offending entry starts: $header" >&2
      printf '%s\n' "$body" | grep 'judge:' | sed 's/^/     /' >&2
      continue
    fi

    if zharness_entry_has_full_mode "$body" && zharness_entry_has_same_session "$body"; then
      failed=$((failed + 1))
      echo "" >&2
      echo "❌ H3 FULL-JUDGE GUARD REJECTED: $path" >&2
      echo "   a newly added ## Validation entry declares mode: full and a" >&2
      echo "   same-session judge. An independent judge is required for full." >&2
      echo "   offending entry starts: $header" >&2
      continue
    fi

    verdict=$(zharness_anchored_verdict "$body")
    case "$verdict" in
      APPROVED|APPROVE_WITH_REQUESTS) ;;
      *) continue ;;
    esac

    cmds=$(zharness_entry_proofs "$body")
    if [ -z "$cmds" ]; then
      failed=$((failed + 1))
      echo "" >&2
      echo "❌ R2 PROOF GUARD REJECTED: $path" >&2
      echo "   malformed entry: verdict \`$verdict\` cites no proof commands at all" >&2
      echo "   offending entry starts: $header" >&2
      continue
    fi

    missing=$(zharness_entry_missing_proof "$lane" "$body")
    if [ -n "$missing" ]; then
      failed=$((failed + 1))
      echo "" >&2
      echo "❌ R4 PROOF-CLASS GUARD REJECTED: $path" >&2
      echo "   lane $lane requires proof: $(zharness_lane_required_proof "$lane")" >&2
      echo "   missing from proof_classes: $missing" >&2
      echo "   offending entry starts: $header" >&2
      continue
    fi

    while IFS= read -r cmd; do
      echo "🧪 re-executing proof [$header]: $cmd"
      out=$(zharness_run_proof "$cmd") && rc_cmd=0 || rc_cmd=$?
      if [ "${rc_cmd:-0}" -ne 0 ]; then
        failed=$((failed + 1))
        echo "" >&2
        echo "❌ R2 PROOF GUARD REJECTED: $path" >&2
        echo "   failing command: $cmd" >&2
        echo "   exit: $rc_cmd" >&2
        echo "   output tail:" >&2
        printf '%s\n' "$out" | tail -10 >&2
      fi
    done <<< "$cmds"
  done

  rm -rf "$scratch"
  [ "$failed" -eq 0 ]
}

zharness_guard_at_most_one_active_plan() { # <repo-root> [worktree|staged]
  # R5: at most one non-empty file under .harness/plans/active/. Zero is idle.
  # No associative arrays — bash 3.2 safe (same constraint as the hash file).
  # In staged mode the index is the subject: the commit is what gets published,
  # so an unstaged or untracked worktree file is not yet a claim (ADR 0009).
  local root="$1" source="${2:-worktree}" n=0 names="" f size
  [ -n "$root" ] || return 1
  if [ "$source" = "staged" ]; then
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      size=$(git -C "$root" cat-file -s ":$f" 2>/dev/null) || continue
      [ "${size:-0}" -gt 0 ] || continue
      n=$((n + 1))
      names="$names $f"
    done <<< "$(git -C "$root" ls-files --cached -- '.harness/plans/active/*.md' 2>/dev/null)"
  else
    for f in "$root"/.harness/plans/active/*.md; do
      [ -f "$f" ] || continue
      [ -s "$f" ] || continue
      n=$((n + 1))
      names="$names ${f#$root/}"
    done
  fi
  if [ "$n" -gt 1 ]; then
    echo "❌ R5 ACTIVE-PLAN GUARD REJECTED: more than one non-empty file under .harness/plans/active/" >&2
    echo "   paths:$names" >&2
    echo "   git mv the finished plan to .harness/plans/completed/ and keep at most one active." >&2
    return 1
  fi
  return 0
}

zharness_guard_completed_plan_phases_done() { # <path> <content-file>
  # A plan whose Current State declares lifecycle_status: completed must show
  # every phase status: done in ## Phases and Verification — otherwise the
  # plan contradicts its own closing claim on a bare re-read. No section found
  # is not a violation (lenient like R5's empty-file case); only a demonstrated
  # contradiction rejects.
  local path="$1" file="$2" lifecycle bad_phases
  lifecycle=$(awk '
    /^## Current State and Next Action/ {f=1; next}
    /^## / {f=0}
    f && /lifecycle_status:/ {sub(/.*lifecycle_status:[[:space:]]*/, ""); print; exit}
  ' "$file")
  [ "$lifecycle" = "completed" ] || return 0
  bad_phases=$(awk '
    /^## Phases and Verification/ {f=1; next}
    /^## / {f=0}
    f && /phase_slug:/ {sub(/.*phase_slug:[[:space:]]*/, ""); slug=$0}
    f && /^[[:space:]]*status:/ {sub(/.*status:[[:space:]]*/, ""); if ($0 != "done") print slug ": " $0}
  ' "$file")
  if [ -n "$bad_phases" ]; then
    echo "" >&2
    echo "❌ PHASE-DONE GUARD REJECTED: $path" >&2
    echo "   lifecycle_status: completed but not every phase is done:" >&2
    printf '%s\n' "$bad_phases" | sed 's/^/     /' >&2
    return 1
  fi
  return 0
}

zharness_guard_revspec() {                 # <staged|push|pr> -> "<base>\t<head>"
  # The single source of the revision under test (ADR 0009). No call site
  # computes its own HEAD~1: a two-commit push, a squash-merge or a rebase
  # makes that window skip the very entries the guard exists to re-execute.
  # ":" as the head means the index.
  local event="$1" base="" head="" default_branch="${ZHARNESS_DEFAULT_BRANCH:-origin/master}"
  case "$event" in
    staged)
      printf 'HEAD\t:\n'
      return 0
      ;;
    push)
      head="${ZHARNESS_HEAD_SHA:-HEAD}"
      base="${ZHARNESS_BEFORE_SHA:-}"
      ;;
    pr)
      head="${ZHARNESS_HEAD_SHA:-HEAD}"
      base=$(git merge-base "${ZHARNESS_BASE_REF:-}" "$head" 2>/dev/null) || base=""
      ;;
    *)
      echo "❌ REVSPEC GUARD: unknown event '$event'" >&2
      return 1
      ;;
  esac
  # A branch creation reports the all-zero SHA; a force-push or a shallow
  # clone reports a commit this checkout does not have. Neither is a base.
  case "$base" in 0000000000000000000000000000000000000000) base="" ;; esac
  if [ -n "$base" ] && ! git rev-parse --verify --quiet "${base}^{commit}" >/dev/null 2>&1; then
    base=""
  fi
  if [ -z "$base" ]; then
    base=$(git merge-base "$default_branch" "$head" 2>/dev/null) || base=""
  fi
  if [ -z "$base" ]; then
    echo "❌ REVSPEC GUARD FAILED CLOSED: no base revision resolves for event '$event'." >&2
    echo "   tried: ZHARNESS_BEFORE_SHA/ZHARNESS_BASE_REF, then merge-base with $default_branch." >&2
    echo "   the checkout needs full history (actions/checkout fetch-depth: 0) to validate this range." >&2
    return 1
  fi
  printf '%s\t%s\n' "$base" "$head"
}

zharness_guard_plan_paths() {              # <base> <head>
  # Both namespaces. A plan closing out moves active/ -> completed/, and the
  # entries it lands in that same commit are exactly the ones an active/-only
  # selector never sees (ADR 0009). -M resolves a rename to its destination.
  if [ "$2" = ":" ]; then
    git diff --cached --name-only --diff-filter=ACMR -M -- \
      '.harness/plans/active/*.md' '.harness/plans/completed/*.md'
  else
    git diff --name-only --diff-filter=ACMR -M "$1" "$2" -- \
      '.harness/plans/active/*.md' '.harness/plans/completed/*.md'
  fi
}

zharness_guard_old_blob() {                # <base> <path> <out-file>
  # A plan moved active/ -> completed/ keeps its identity: compare against the
  # predecessor path so a closure re-executes its new entries, not every entry
  # the plan ever recorded. Plans lived under docs/plans/ before v0.31.0, so the
  # layout move resolves to that path too. No predecessor found means an empty
  # old side, which re-executes everything — the conservative direction.
  local base="$1" path="$2" out="$3" alt
  if git show "$base:$path" > "$out" 2>/dev/null; then return 0; fi
  set -- "docs/plans/${path#.harness/plans/}"
  case "$path" in
    .harness/plans/completed/*)
      set -- "$@" ".harness/plans/active/${path##*/}" "docs/plans/active/${path##*/}"
      ;;
  esac
  for alt in "$@"; do
    git show "$base:$alt" > "$out" 2>/dev/null && return 0
  done
  : > "$out"
}

zhuards_guard_plans() {                    # <path-list-space-separated> <base> <head> <dir-for-temp>
  local plans="$1" base="$2" head="$3" tmp="$4" f rc=0
  for f in $plans; do
    zharness_guard_old_blob "$base" "$f" "$tmp/old.md"
    if [ "$head" = ":" ]; then
      git show ":$f" > "$tmp/new.md"
    else
      git show "$head:$f" > "$tmp/new.md" 2>/dev/null || : > "$tmp/new.md"
    fi
    if ! zharness_guard_entries_of_file "$f" "$tmp/old.md" "$tmp/new.md"; then rc=1; fi
  done
  return $rc
}

zharness_guard_staged_secrets() {          # <repo-root>
  # SECRETS: reject staged value-shaped secrets and secret-bearing filenames.
  # Reports file:line and the pattern name only; the matched value is never
  # printed. *.example/*.sample/*.template files are fixtures by convention:
  # exempt from the filename and url-credentials checks only (owner, 2026-09-29).
  local root="$1" f line n ex d hits=""
  # A git error (bad diff.* config, missing orderFile) must not skip the scan.
  git -C "$root" diff --cached --name-only -z --diff-filter=ACMRT >/dev/null 2>&1 || {
    echo "❌ SECRET GUARD REJECTED: git diff failed; staged content not scanned" >&2
    return 1
  }
  local aws='AKIA[0-9A-Z]{16}'
  local pkey='-----BEGIN ([A-Z]+ )*PRIVATE KEY-----'
  local ucred='[a-z][a-z0-9+.-]*://[^/:@[:space:]]+:[^/@[:space:]]+@'
  # -z names: no C-quoting of non-ASCII paths. --text: binary blobs are
  # scanned too (NULs dropped). Headers end at the first @@, so an added line
  # that itself starts with "++" is still content. Raw bytes only: no
  # textconv/external diff, and context lines still advance the counter.
  while IFS= read -r -d '' f; do
    ex=0
    case "$f" in *.example|*.sample|*.template) ex=1 ;; esac
    [ "$ex" = 1 ] || case "${f##*/}" in
      .env|.env.*|*.pem|*.key|*.p12) hits="$hits
   $f  secret-bearing filename" ;;
    esac
    d=$(set -o pipefail; git -C "$root" --literal-pathspecs -c diff.interHunkContext=0 diff --cached -U0 --no-color \
      --no-ext-diff --no-textconv --text -- "$f" | LC_ALL=C tr -d '\000') || { hits="$hits
   $f  diff failed, not scanned"; continue; }
    while IFS="$(printf '\t')" read -r n line; do
      [ -n "$n" ] || continue
      if [[ $line =~ $aws ]]; then hits="$hits
   $f:$n  aws-access-key"
      elif [[ $line =~ $pkey ]]; then hits="$hits
   $f:$n  private-key"
      elif [ "$ex" = 0 ] && [[ $line =~ $ucred ]]; then hits="$hits
   $f:$n  url-credentials"
      fi
    done <<< "$(printf '%s\n' "$d" | awk '
      /^@@/ { h = 1; s = $3; sub(/^\+/, "", s); sub(/,.*/, "", s); n = s + 0; next }
      h && /^\+/ { print n "\t" substr($0, 2); n++; next }
      h && /^ / { n++ }')"
  done < <(git -C "$root" diff --cached --name-only -z --diff-filter=ACMRT 2>/dev/null)
  if [ -n "$hits" ]; then
    echo "❌ SECRET GUARD REJECTED: staged content looks like a secret$hits" >&2
    echo "   Move it to an env var or untracked file, then git restore --staged <file>." >&2
    return 1
  fi
  return 0
}
# ZGUARD-CORE-END

function show_usage() {
  cat << 'USAGE'
Usage: $(basename "$0") [options]

Install git hooks for automated skill validation plus the v0.15
fail-closed guards (proof re-execution + independent-judge rule).

Options:
  -h, --help       Show this help message
  -f, --force      Overwrite existing hooks

Examples:
  ./install-git-hooks.sh
  ./install-git-hooks.sh --force

from therealTINHTUTE with love
USAGE
}

function create_pre_commit_hook() {
  local hook_file="$HOOKS_DIR/pre-commit"
  local force="$1"
  local new="$hook_file.tmp-zharness"

  cat > "$new" << 'HOOK_EOF'
#!/bin/bash
# Pre-commit hook: validate changed skills + v0.15 fail-closed guards (R2/R3)

export ZHARNESS_HOOK_SOURCE
ROOT="$(git rev-parse --show-toplevel)"
export ROOT
ZHARNESS_HOOK_SOURCE="$ROOT/setup/install-git-hooks.sh"
# The guard core is re-extracted on every run, but this wrapper is baked in at
# install time. Compare it with its template so a wrapper edit cannot stay
# inert in an old install (failures.md, 2026-09-16).
if [ -f "$ZHARNESS_HOOK_SOURCE" ] && ! awk '/^function create_pre_commit_hook/{f=1} f&&/<< .HOOK_EOF.$/{on=1;next} on&&$0=="HOOK_EOF"{exit} on' "$ZHARNESS_HOOK_SOURCE" | cmp -s - "$0"; then
  echo "❌ installed pre-commit hook is stale against setup/install-git-hooks.sh"
  echo "Re-install it: bash setup/install-git-hooks.sh --force"
  exit 1
fi
_zhtmp=$(mktemp -d)
# Enforce from the staged installer bytes when the installer itself is part of
# this commit; otherwise fall back to the worktree copy.
GUARD_SRC="$ZHARNESS_HOOK_SOURCE"
if git diff --cached --name-only -- setup/install-git-hooks.sh | grep -q . 2>/dev/null; then
  git show ":setup/install-git-hooks.sh" > "$_zhtmp/src.sh" || {
    echo "❌ cannot resolve staged guard source"; exit 1;
  }
  GUARD_SRC="$_zhtmp/src.sh"
fi
awk '$0=="# ZGUARD-CORE-BEGIN"{on=1;next} $0=="# ZGUARD-CORE-END"{on=0} on' "$GUARD_SRC" > "$_zhtmp/guard.sh" || {
  echo "❌ guard core extraction failed from $GUARD_SRC"; exit 1;
}
grep -q '^zharness_guard_entries_of_file()' "$_zhtmp/guard.sh" || { echo "❌ guard core incomplete"; exit 1; }
# shellcheck disable=SC1090
source "$_zhtmp/guard.sh"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir" "$_zhtmp"' EXIT

echo "🔍 Plan guards on staged plans..."
revspec=$(zharness_guard_revspec staged) || exit 1
gbase=$(printf '%s' "$revspec" | cut -f1)
ghead=$(printf '%s' "$revspec" | cut -f2)
plans=$(zharness_guard_plan_paths "$gbase" "$ghead")
[ -n "$plans" ] && printf 'staged plans:\n%s\n' "$plans"
guard_failed=0
if ! zharness_guard_at_most_one_active_plan "$ROOT" staged; then
  guard_failed=1
fi
# Worktree state is reported, not gated: only the index becomes the commit.
if ! zharness_guard_at_most_one_active_plan "$ROOT" worktree >/dev/null 2>&1; then
  echo "ℹ️  note: more than one non-empty .harness/plans/active/*.md in the worktree (unstaged; not gating)."
fi
if [ -n "$plans" ] && ! zhuards_guard_plans "$plans" "$gbase" "$ghead" "$tmpdir"; then
  guard_failed=1
fi

if [ -n "$plans" ]; then
  while IFS= read -r f; do
    case "$f" in .harness/plans/completed/*) ;; *) continue ;; esac
    git show ":$f" > "$tmpdir/completed.md"
    zharness_guard_completed_plan_phases_done "$f" "$tmpdir/completed.md" || guard_failed=1
  done <<< "$plans"
fi
if ! zharness_guard_staged_secrets "$ROOT"; then
  guard_failed=1
fi

if [ "$guard_failed" -gt 0 ]; then
  echo ""
  echo "❌ Plan guards rejected this commit."
  echo "Fix the failing proof command(s) or provide an independent judge, then commit again."
  exit 1
fi
echo "✅ Plan guards passed"

echo ""
echo "🔍 Validating changed skills..."

# Skills live at skills/<category>/<name>/SKILL.md. This grep used to say
# "kit/skills/.*/SKILL.md" — a path this repo has never had — so the whole block
# below was dead and every commit printed "No skill files changed".
changed_skills=$(git diff --cached --name-only | grep -E '(^|/)skills/[^/]+/[^/]+/SKILL\.md$' || true)

if [ -z "$changed_skills" ]; then
  echo "✅ No skill files changed"
  exit 0
fi

failed=0
while IFS= read -r skill_file; do
  if [ -f "$skill_file" ]; then
    echo "Checking: $skill_file"
    skill_dir=$(dirname "$skill_file")
    if [ -f "scripts/ci/validate-skill.sh" ]; then
      if ! bash scripts/ci/validate-skill.sh "$skill_file"; then
        echo "❌ Validation failed: $skill_file"
        ((failed++))
      fi
    else
      # Fallback when the validator is absent. Frontmatter only — the <role> and
      # <security> tags this used to demand belong to the heavyweight skill
      # format, not to the <=30-line thin triggers.
      if ! grep -q "^---" "$skill_file"; then echo "❌ Missing frontmatter: $skill_file"; ((failed++)); fi
      if ! grep -q "^name:" "$skill_file"; then echo "❌ Missing name: $skill_file"; ((failed++)); fi
      if ! grep -q "^description:" "$skill_file"; then echo "❌ Missing description: $skill_file"; ((failed++)); fi
    fi
  fi
done <<< "$changed_skills"

if [ $failed -gt 0 ]; then
  echo ""
  echo "❌ $failed skill(s) failed validation"
  echo "Fix issues before committing"
  exit 1
fi

echo "✅ All skills validated"
exit 0
HOOK_EOF

  install_hook_file "$new" "$hook_file" "$force"
}

function install_hook_file() {             # <new> <hook-file> <force>
  local new="$1" hook_file="$2" force="$3" name
  name=$(basename "$hook_file")
  # A kept stale hook calls the guard core with an outdated signature and
  # fails open, so an older hook of ours is always replaced. A hook that is
  # not ours is never overwritten without --force.
  if [ -f "$hook_file" ] && [ "$force" != "true" ]; then
    if cmp -s "$new" "$hook_file"; then
      rm -f "$new"
      echo "✅ $name hook up to date"
      return 0
    fi
    if ! grep -q '^ZHARNESS_HOOK_SOURCE=' "$hook_file"; then
      rm -f "$new"
      echo "❌ a foreign $name hook exists at $hook_file"
      echo "Use --force to overwrite"
      return 1
    fi
    echo "🔄 replacing stale zharness $name hook"
  fi

  mv "$new" "$hook_file" || return 1
  chmod +x "$hook_file"
  echo "✅ Created: $hook_file"
}

function create_pre_push_hook() {
  local hook_file="$HOOKS_DIR/pre-push"
  local force="$1"
  local new="$hook_file.tmp-zharness"

  cat > "$new" << 'HOOK_EOF'
#!/bin/bash
# Pre-push hook: re-run the plan guards over the whole branch range, the same
# range CI's hook-guard job validates (ADR 0009). pre-commit sees one commit at
# a time, so a later commit that breaks an earlier entry's proof passes every
# local commit and fails only in CI. The range catches it before the push.

export ZHARNESS_HOOK_SOURCE
ROOT="$(git rev-parse --show-toplevel)"
export ROOT
ZHARNESS_HOOK_SOURCE="$ROOT/setup/install-git-hooks.sh"
refs=$(cat)
zero=0000000000000000000000000000000000000000
head_sha=$(git rev-parse HEAD)
_zhtmp=$(mktemp -d)
trap 'rm -rf "$_zhtmp"' EXIT
# Enforce from the installer bytes being pushed, as CI does from its checkout.
git show "$head_sha:setup/install-git-hooks.sh" > "$_zhtmp/src.sh" 2>/dev/null ||
  cp "$ZHARNESS_HOOK_SOURCE" "$_zhtmp/src.sh" || { echo "❌ cannot resolve guard source"; exit 1; }
awk '$0=="# ZGUARD-CORE-BEGIN"{on=1;next} $0=="# ZGUARD-CORE-END"{on=0} on' "$_zhtmp/src.sh" > "$_zhtmp/guard.sh" || {
  echo "❌ guard core extraction failed"; exit 1;
}
grep -q '^zharness_guard_revspec()' "$_zhtmp/guard.sh" || { echo "❌ guard core incomplete"; exit 1; }
# shellcheck disable=SC1090
source "$_zhtmp/guard.sh"

failed=0
while read -r local_ref local_sha remote_ref _ <&3; do
  [ -n "$local_sha" ] && [ "$local_sha" != "$zero" ] || continue
  case "$remote_ref" in refs/heads/*) ;; *) continue ;; esac
  revspec=$(ZHARNESS_BASE_REF="${ZHARNESS_DEFAULT_BRANCH:-origin/master}" \
    ZHARNESS_HEAD_SHA="$local_sha" zharness_guard_revspec pr) || { failed=1; continue; }
  gbase=$(printf '%s' "$revspec" | cut -f1)
  ghead=$(printf '%s' "$revspec" | cut -f2)
  plans=$(zharness_guard_plan_paths "$gbase" "$ghead")
  [ -n "$plans" ] || continue
  # Proofs execute in this worktree, so the range must end at what is checked out.
  if [ "$local_sha" != "$head_sha" ]; then
    echo "❌ pre-push plan guard: $local_ref carries plan changes but is not the checked-out HEAD."
    echo "   Proofs run in this worktree; check out $local_ref and push again."
    failed=1
    continue
  fi
  if git status --porcelain --untracked-files=no | grep -q .; then
    echo "ℹ️  note: uncommitted changes; proofs run against the worktree, CI runs against the commit."
  fi
  echo "🔍 Plan guards on $gbase..$ghead:"
  printf '%s\n' "$plans"
  zhuards_guard_plans "$plans" "$gbase" "$ghead" "$_zhtmp" || failed=1
  while IFS= read -r f; do
    case "$f" in .harness/plans/completed/*) ;; *) continue ;; esac
    git show "$ghead:$f" > "$_zhtmp/completed.md"
    zharness_guard_completed_plan_phases_done "$f" "$_zhtmp/completed.md" || failed=1
  done <<< "$plans"
done 3<<< "$refs"

if [ "$failed" -gt 0 ]; then
  echo ""
  echo "❌ Plan guards rejected this push (CI's hook-guard would fail the same range)."
  echo "Fix the failing proof, or append a superseding Validation entry, then push again."
  exit 1
fi
exit 0
HOOK_EOF

  install_hook_file "$new" "$hook_file" "$force"
}

function create_commit_msg_hook() {
  local hook_file="$HOOKS_DIR/commit-msg"
  local force="$1"

  if [ -f "$hook_file" ] && [ "$force" != "true" ]; then
    echo "⚠️  commit-msg hook already exists"
    return 0
  fi

  cat > "$hook_file" << 'HOOK_EOF'
#!/bin/bash
# Commit-msg hook: Validate conventional commit format

set -e

commit_msg_file="$1"
commit_msg=$(cat "$commit_msg_file")

if ! echo "$commit_msg" | grep -qE '^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?: .+'; then
  echo "❌ Invalid commit message format"
  echo ""
  echo "Expected: type(scope): description"
  echo "Types: feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert"
  echo ""
  echo "Your message:"
  echo "$commit_msg"
  exit 1
fi

exit 0
HOOK_EOF

  chmod +x "$hook_file"
  echo "✅ Created: $hook_file"
}

function main() {
  local force="false"

  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        show_usage
        exit 0
        ;;
      -f|--force)
        force="true"
        shift
        ;;
      *)
        echo "❌ Unknown option: $1"
        show_usage
        exit 1
        ;;
    esac
  done

  if [ ! -d "$HOOKS_DIR" ]; then
    echo "❌ Not a git repository"
    exit 1
  fi

  echo "🔧 Installing git hooks..."
  echo ""

  create_pre_commit_hook "$force" || exit 1
  create_pre_push_hook "$force" || exit 1
  create_commit_msg_hook "$force"

  echo ""
  echo "🎉 Git hooks installed successfully"
  echo ""
  echo "Hooks installed:"
  echo "  - pre-commit: plan guards (R2/R3) + changed-skill validation"
  echo "  - pre-push: plan guards over the branch range (same range as CI)"
  echo "  - commit-msg: Validates commit message format"
}

main "$@"
