#!/usr/bin/env bash
# Print the mechanical facts behind check-risk.md § Checks as one JSON object.
#
# Usage: risk-facts.sh <base> <sha>     (run inside the repository)
#
# Diffs "<base>...<sha>" (merge base to <sha>) and prints:
#   {"counted_lines": N, "excluded_lines": N, "excluded_paths": [...],
#    "always_review_hits": [...],
#    "test_changes": {"removed_files": [...], "skip_markers_added": [...]},
#    "ci_config_touched": bool, "manifest_or_lockfile_touched": bool}
#
# Lines are added plus deleted from --numstat; a binary file counts 0. Renames
# are split into delete plus add, so a moved file counts in full.
# Excluded from counted_lines:
#   docs        *.md, docs/** at any depth
#   tests       tests/**, test/**, spec/**, __tests__/** at any depth; basename
#               *_test.*, test_*.*, *.test.*, *_spec.*, *.spec.*, *Test.java
#   generated   linguist-generated in <base>'s .gitattributes (never the PR's
#               own copy); basename *.generated.*
#   lockfiles   *.lock, package-lock.json, pnpm-lock.yaml, go.sum
# always_review_hits: changed paths matching AGENTS.md itself or a glob on the
#   "- Always-review paths:" line of <base>:AGENTS.md; every such line counts
#   (missing file or line: none).
# removed_files: test-pattern paths deleted outright (a rename is not a removal).
# skip_markers_added: "path:line: text" for each added line outside docs that
#   matches #[ignore, @skip, .skip(, pytest.mark.skip, t.Skip(, xit(, xdescribe(.
# ci_config_touched: .github/**, .gitlab-ci.yml, .circleci/**.
# manifest_or_lockfile_touched: a lockfile above or a manifest basename
#   (Cargo.toml, package.json, go.mod, pyproject.toml, setup.py, setup.cfg,
#   requirements*.txt, Pipfile, Gemfile, *.gemspec, pom.xml, build.gradle*,
#   composer.json).
#
# These are facts, not a verdict. Exit codes: 0 facts printed; 2 usage error,
# unknown ref, or no merge base.
set -euo pipefail

usage() {
  echo "usage: risk-facts.sh <base> <sha>" >&2
  exit 2
}

case ${1:-} in
  -h | --help)
    sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'
    exit 0
    ;;
esac
[ "$#" -eq 2 ] || usage
base=$1
sha=$2

git rev-parse --git-dir >/dev/null 2>&1 || { echo "risk-facts.sh: not a git repository" >&2; exit 2; }
for ref in "$base" "$sha"; do
  git rev-parse --verify --quiet "$ref^{commit}" >/dev/null || { echo "risk-facts.sh: unknown commit: $ref" >&2; exit 2; }
done
git merge-base "$base" "$sha" >/dev/null 2>&1 || { echo "risk-facts.sh: no merge base for $base and $sha" >&2; exit 2; }

gitq() { git -c core.quotepath=off "$@"; }

json_str() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\t'/\\t}
  s=${s//$'\r'/\\r}
  s=${s//$'\n'/\\n}
  s=$(printf '%s' "$s" | tr -d '\000-\010\013\014\016-\037')
  printf '"%s"' "$s"
}

json_arr() {
  local out="" item
  for item in "$@"; do
    out+="${out:+, }$(json_str "$item")"
  done
  printf '[%s]' "$out"
}

is_doc() {
  case $1 in
    *.md | docs/* | */docs/*) return 0 ;;
  esac
  return 1
}

is_test() {
  case $1 in
    tests/* | */tests/* | test/* | */test/* | spec/* | */spec/* | __tests__/* | */__tests__/*) return 0 ;;
  esac
  case ${1##*/} in
    *_test.* | test_*.* | *.test.* | *_spec.* | *.spec.* | *Test.java) return 0 ;;
  esac
  return 1
}

is_lockfile() {
  case ${1##*/} in
    *.lock | package-lock.json | pnpm-lock.yaml | go.sum) return 0 ;;
  esac
  return 1
}

is_manifest() {
  case ${1##*/} in
    Cargo.toml | package.json | go.mod | pyproject.toml | setup.py | setup.cfg | requirements*.txt | \
      Pipfile | Gemfile | *.gemspec | pom.xml | build.gradle* | composer.json) return 0 ;;
  esac
  return 1
}

is_generated() {
  local g
  case ${1##*/} in *.generated.*) return 0 ;; esac
  for g in ${generated[@]+"${generated[@]}"}; do
    [ "$g" = "$1" ] && return 0
  done
  return 1
}

is_ci() {
  case $1 in
    .github/* | .gitlab-ci.yml | .circleci/*) return 0 ;;
  esac
  return 1
}

# Always-review globs from the base branch's AGENTS.md, plus AGENTS.md itself.
globs=("AGENTS.md")
while IFS= read -r agents_line; do
  IFS=, read -ra raw <<<"${agents_line#- Always-review paths:}"
  for g in "${raw[@]}"; do
    g=${g//$'\r'/}
    g=${g//\`/}
    g="${g#"${g%%[![:space:]]*}"}"
    g="${g%"${g##*[![:space:]]}"}"
    [ -n "$g" ] && globs+=("$g")
  done
done < <(git show "$base:AGENTS.md" 2>/dev/null | grep '^- Always-review paths:' || true)

# Changed paths with line counts. -z keeps unusual names intact.
paths=()
counts=()
while IFS=$'\t' read -r -d '' add del path; do
  [ "$add" = "-" ] && add=0
  [ "$del" = "-" ] && del=0
  paths+=("$path")
  counts+=($((add + del)))
done < <(gitq diff --numstat -z --no-renames "$base...$sha")

# Generated per <base>'s .gitattributes, so a PR cannot exempt its own code
# (git check-attr --source needs git 2.40+).
generated=()
if [ "${#paths[@]}" -gt 0 ]; then
  while IFS= read -r -d '' p && IFS= read -r -d '' _attr && IFS= read -r -d '' val; do
    if [ "$val" = "set" ] || [ "$val" = "true" ]; then generated+=("$p"); fi
  done < <(printf '%s\0' "${paths[@]}" | gitq check-attr -z --stdin --source="$base" linguist-generated 2>/dev/null || true)
fi

counted=0
excluded=0
excluded_paths=()
review_hits=()
ci=false
manifest=false
for i in "${!paths[@]}"; do
  p=${paths[$i]}
  n=${counts[$i]}
  if is_doc "$p" || is_test "$p" || is_lockfile "$p" || is_generated "$p"; then
    excluded=$((excluded + n))
    excluded_paths+=("$p")
  else
    counted=$((counted + n))
  fi
  for g in "${globs[@]}"; do
    # shellcheck disable=SC2053 # $g is a glob on purpose
    if [[ $p == $g ]]; then
      review_hits+=("$p")
      break
    fi
  done
  is_ci "$p" && ci=true
  { is_lockfile "$p" || is_manifest "$p"; } && manifest=true
done

# Test files deleted outright; renames stay R, not D.
removed=()
while IFS= read -r -d '' status && IFS= read -r -d '' p; do
  [ "$status" = "D" ] && is_test "$p" && removed+=("$p")
done < <(gitq diff --name-status -z --diff-filter=D "$base...$sha")

# Skip or ignore markers on added lines, outside docs.
markers=()
marker_re='#\[ignore|@skip|\.skip\(|pytest\.mark\.skip|t\.Skip\(|(^|[^A-Za-z0-9_])xit\(|(^|[^A-Za-z0-9_])xdescribe\('
# One diff per path: the path comes from --numstat -z, never from a header that
# git may C-quote or tab-suffix.
for file in ${paths[@]+"${paths[@]}"}; do
  is_doc "$file" && continue
  line=0
  hunk=false
  while IFS= read -r l; do
    case $l in
      '@@ '*)
        hunk=true
        line=${l#*+}
        line=${line%%[, ]*}
        ;;
      '+'*)
        $hunk || continue
        text=${l#+}
        [[ $text =~ $marker_re ]] && markers+=("$file:$line: $text")
        line=$((line + 1))
        ;;
    esac
  done < <(gitq diff -U0 --no-renames --no-color --no-ext-diff "$base...$sha" -- ":(literal)$file")
done

printf '{\n'
printf '  "counted_lines": %d,\n' "$counted"
printf '  "excluded_lines": %d,\n' "$excluded"
printf '  "excluded_paths": %s,\n' "$(json_arr ${excluded_paths[@]+"${excluded_paths[@]}"})"
printf '  "always_review_hits": %s,\n' "$(json_arr ${review_hits[@]+"${review_hits[@]}"})"
printf '  "test_changes": {"removed_files": %s, "skip_markers_added": %s},\n' \
  "$(json_arr ${removed[@]+"${removed[@]}"})" "$(json_arr ${markers[@]+"${markers[@]}"})"
printf '  "ci_config_touched": %s,\n' "$ci"
printf '  "manifest_or_lockfile_touched": %s\n' "$manifest"
printf '}\n'
