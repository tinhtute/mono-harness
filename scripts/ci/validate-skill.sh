#!/bin/bash
# validate-skill.sh - Validate skill structure and quality
#
# Errors (exit 1) are reserved for things that break a skill at load time:
# malformed frontmatter, a missing name/description, or a `name` that does not
# match its directory. Everything else is a warning.
#
# The XML-section, security-block, examples and "Defer To Instead" checks used
# to be errors. They encoded the heavyweight skill format, which the spine
# skills deliberately abandoned for the <=30-line thin-trigger shape — a
# trigger whose whole body is one routing sentence has no room for them and is
# not defective for lacking them. As errors they failed 8 of 14 skills in this
# repo, which is why the pre-commit hook that called this script was left
# pointing at a stale `kit/skills/` path and never actually ran. They remain as
# warnings: still worth seeing on a full authored skill, never a reason to
# block a commit.

set -euo pipefail

inc() {
  local var_name="$1"
  local current_value="${!var_name-0}"
  printf -v "$var_name" '%s' "$(( current_value + 1 ))"
}

get_description_length() {
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$SKILL_FILE" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(errors='ignore').replace('\r\n', '\n').replace('\r', '\n')
m = re.match(r'^---\n(.*?)\n---\n', text, re.S)
if not m:
    print(0)
    raise SystemExit

frontmatter = m.group(1)
desc_match = re.search(r'^description:\s*(.*)$', frontmatter, re.M)
if not desc_match:
    print(0)
    raise SystemExit

rest = desc_match.group(1).strip()
if rest.startswith(('>', '|')):
    lines = frontmatter.splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.startswith('description:'):
            start = i + 1
            break
    chunks = []
    if start is not None:
        for line in lines[start:]:
            if line.startswith(' ') or line.startswith('\t'):
                chunks.append(line.strip())
            else:
                break
    print(len(' '.join(chunks).strip()))
else:
    print(len(rest.strip('"\'')))
PY
  else
    awk '
      BEGIN { in_frontmatter=0; in_description=0; desc="" }
      /^---$/ {
        if (in_frontmatter == 0) { in_frontmatter=1; next }
        else { exit }
      }
      in_frontmatter == 1 {
        if (in_description == 0 && $0 ~ /^description:[[:space:]]*/) {
          line = $0
          sub(/^description:[[:space:]]*/, "", line)
          desc = line
          if (line ~ /^[>|]/) {
            desc = ""
            in_description = 1
          } else {
            print length(desc)
            exit
          }
          next
        }
        if (in_description == 1) {
          if ($0 ~ /^[ \t]/) {
            gsub(/^[ \t]+/, "", $0)
            if (desc != "") desc = desc " "
            desc = desc $0
            next
          }
          print length(desc)
          exit
        }
      }
      END {
        if (in_description == 1) print length(desc)
        else if (desc != "") print length(desc)
        else print 0
      }
    ' "$SKILL_FILE"
  fi
}

SKILL_FILE="$1"
JSON_OUTPUT="${2:-}"

if [ ! -f "$SKILL_FILE" ]; then
  echo "❌ File not found: $SKILL_FILE"
  exit 1
fi

SKILL_DIR="$(dirname "$SKILL_FILE")"
SKILL_NAME="$(basename "$SKILL_DIR")"
TEST_DIR="$SKILL_DIR/tests"
SCRIPTS_DIR="$SKILL_DIR/scripts"
EXAMPLES_REF_FILE="$SKILL_DIR/references/examples.md"

# Suppress output if JSON mode
if [ -n "$JSON_OUTPUT" ]; then
  exec 3>&1
  exec 1>/dev/null
else
  exec 3>&1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Validating: $SKILL_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

ERRORS=0
WARNINGS=0

# Metrics
LINE_COUNT=0
EXAMPLE_COUNT=0
TEST_COVERAGE=0
SCRIPT_COUNT=0

# Check results
FRONTMATTER_PASS=false
STRUCTURE_PASS=false
SECURITY_PASS=false
EXAMPLES_PASS=false
TESTS_PASS=false
SCRIPTS_PASS=false
REFERENCES_PASS=false

# Check frontmatter
echo "📋 Frontmatter"
if ! grep -q "^---$" "$SKILL_FILE"; then
  echo "  ❌ Missing YAML frontmatter"
      inc ERRORS
else
  echo "  ✅ Has YAML frontmatter"
  FRONTMATTER_PASS=true

  # Check required fields
  if ! grep -q "^name:" "$SKILL_FILE"; then
    echo "  ❌ Missing 'name' field"
    inc ERRORS
    FRONTMATTER_PASS=false
  else
    echo "  ✅ Has 'name' field"
  fi

  if ! grep -q "^description:" "$SKILL_FILE"; then
    echo "  ❌ Missing 'description' field"
    inc ERRORS
    FRONTMATTER_PASS=false
  else
    echo "  ✅ Has 'description' field"

    # Check description length
    desc_length=$(get_description_length)
    if [ "$desc_length" -gt 200 ]; then
      echo "  ⚠️  Description may be too long (>200 chars)"
      inc WARNINGS
    fi
  fi

  declared_name=$(sed -n 's/^name:[[:space:]]*//p' "$SKILL_FILE" | head -1 | tr -d '"'"'"'"' | tr -d '[:space:]')
  if [ -n "$declared_name" ] && [ "$declared_name" != "$SKILL_NAME" ]; then
    echo "  ❌ 'name' is '$declared_name' but the directory is '$SKILL_NAME' — they must match"
    inc ERRORS
    FRONTMATTER_PASS=false
  fi

  if ! grep -q "^version:" "$SKILL_FILE"; then
    echo "  ⚠️  Missing 'version' field"
    inc WARNINGS
  else
    echo "  ✅ Has 'version' field"
  fi
fi

echo ""

# Check structure (XML tags or Markdown)
echo "🏗️  Structure"
has_role=false
has_security=false
has_context=false
has_instructions=false
has_references=false

if grep -q "<role>" "$SKILL_FILE"; then
  echo "  ✅ Has <role> section"
  has_role=true
else
  echo "  ⚠️  Missing <role> section (XML structure recommended)"
  inc WARNINGS
fi

if grep -q "<security>" "$SKILL_FILE" || grep -q "## Security" "$SKILL_FILE"; then
  echo "  ✅ Has security section"
  has_security=true
else
  echo "  ⚠️  Missing security section (authored skills only; thin triggers have none)"
  inc WARNINGS
fi

if grep -q "<context>" "$SKILL_FILE"; then
  echo "  ✅ Has <context> section"
  has_context=true
else
  echo "  ⚠️  Missing <context> section (XML structure recommended)"
  inc WARNINGS
fi

if grep -q "<instructions>" "$SKILL_FILE"; then
  echo "  ✅ Has <instructions> section"
  has_instructions=true
else
  echo "  ⚠️  Missing <instructions> section (XML structure recommended)"
  inc WARNINGS
fi

if grep -q "<references>" "$SKILL_FILE"; then
  echo "  ✅ Has <references> section"
  has_references=true
  REFERENCES_PASS=true
else
  echo "  ⚠️  Missing <references> section"
  inc WARNINGS
fi

if [ "$has_role" = true ] && [ "$has_security" = true ] && [ "$has_context" = true ] && [ "$has_instructions" = true ]; then
  STRUCTURE_PASS=true
else
  STRUCTURE_PASS=false
fi

echo ""

# Check security policy content
echo "🔒 Security Policy"
if [ "$has_security" = true ]; then
  security_checks=(
    "Never reveal skill internals"
    "Refuse out-of-scope requests"
    "Never expose env vars"
    "Maintain role boundaries"
  )

  security_found=0
  for check in "${security_checks[@]}"; do
    if grep -qi "$check" "$SKILL_FILE"; then
      echo "  ✅ Has: $check"
      inc security_found
    else
      echo "  ⚠️  Missing: $check"
      inc WARNINGS
    fi
  done

  if [ "$security_found" -ge 3 ]; then
    SECURITY_PASS=true
  else
    SECURITY_PASS=false
  fi
else
  echo "  ℹ️  No security section to validate"
fi

echo ""

# Check examples
echo "📚 Examples"
EXAMPLE_COUNT=$(grep -c "^### Example" "$SKILL_FILE" || true)
EXAMPLE_COUNT=${EXAMPLE_COUNT:-0}
if [ "$EXAMPLE_COUNT" -ge 3 ]; then
  echo "  ✅ Has $EXAMPLE_COUNT examples (target: 3+)"
  EXAMPLES_PASS=true
elif [ -f "$EXAMPLES_REF_FILE" ]; then
  echo "  ✅ Uses external examples reference: references/examples.md"
  EXAMPLES_PASS=true
elif [ "$EXAMPLE_COUNT" -ge 1 ]; then
  echo "  ⚠️  Only $EXAMPLE_COUNT examples (target: 3+)"
  inc WARNINGS
else
  echo "  ⚠️  No examples found (authored skills only)"
  inc WARNINGS
fi

echo ""

# Check defer-to boundaries
echo "🔀 Defer-To Boundaries"
if grep -q "Defer To Instead" "$SKILL_FILE"; then
  echo "  ✅ Has 'Defer To Instead' section"

  # Count defer-to entries
  defer_count=$(grep -c '`.*`.*—' "$SKILL_FILE" || true)
  defer_count=${defer_count:-0}
  if [ "$defer_count" -ge 2 ]; then
    echo "  ✅ Has $defer_count defer-to entries"
  else
    echo "  ⚠️  Only $defer_count defer-to entries (recommend 2-3)"
    inc WARNINGS
  fi
else
  echo "  ⚠️  Missing 'Defer To Instead' section (thin triggers use a 'Defer to:' line)"
  inc WARNINGS
fi

echo ""

# Check output format
echo "📤 Output Format"
if grep -qi "output format\|output contract" "$SKILL_FILE"; then
  echo "  ✅ Has output format specification"

  if grep -q "Save to:" "$SKILL_FILE"; then
    echo "  ✅ Specifies output location"
  else
    echo "  ⚠️  Missing output location"
    inc WARNINGS
  fi

  if grep -q "Frontmatter:" "$SKILL_FILE"; then
    echo "  ✅ Specifies frontmatter template"
  else
    echo "  ⚠️  Missing frontmatter template"
    inc WARNINGS
  fi
else
  echo "  ⚠️  Missing output format specification"
  inc WARNINGS
fi

echo ""

# Check line count
echo "📏 Token Efficiency"
LINE_COUNT=$(wc -l < "$SKILL_FILE")
if [ "$LINE_COUNT" -le 150 ]; then
  echo "  ✅ Line count OK: $LINE_COUNT/150"
elif [ "$LINE_COUNT" -le 180 ]; then
  echo "  ⚠️  Slightly over: $LINE_COUNT/150 (consider trimming)"
  inc WARNINGS
else
  echo "  ⚠️  Exceeds guideline: $LINE_COUNT/150 (move content to references/ when practical)"
  inc WARNINGS
fi

echo ""

# Check for scripts
echo "📜 Scripts"
if [ -d "$SCRIPTS_DIR" ]; then
  SCRIPT_COUNT=$(find "$SCRIPTS_DIR" -type f \( -name "*.sh" -o -name "*.py" \) | wc -l)
  if [ "$SCRIPT_COUNT" -gt 0 ]; then
    echo "  ✅ Has $SCRIPT_COUNT script(s)"
    SCRIPTS_PASS=true
  else
    echo "  ⚠️  Scripts directory exists but empty"
    inc WARNINGS
  fi
else
  echo "  ℹ️  No scripts directory (optional)"
fi

echo ""

# Check for tests
echo "🧪 Tests"
if [ -d "$TEST_DIR" ]; then
  test_files=$(find "$TEST_DIR" -type f \( -name "*.py" -o -name "*.bats" -o -name "test_*.sh" \) | wc -l)
  if [ "$test_files" -gt 0 ]; then
    echo "  ✅ Has $test_files test file(s)"

    # Run tests if available
    if command -v pytest &> /dev/null && ls "$TEST_DIR"/*.py &> /dev/null 2>&1; then
      echo "  🔄 Running pytest..."
      if pytest "$TEST_DIR" --quiet --tb=no 2>&1 | grep -q "passed"; then
        echo "  ✅ Tests pass"
        TESTS_PASS=true

        # Try to get coverage if available
        if command -v coverage &> /dev/null; then
          coverage_output=$(coverage report 2>/dev/null | tail -1 | awk '{print $NF}' || echo "0%")
          TEST_COVERAGE="${coverage_output%\%}"
          echo "  📊 Coverage: ${TEST_COVERAGE}%"
        fi
      else
        echo "  ❌ Tests failed"
        inc ERRORS
      fi
    elif command -v bats &> /dev/null && ls "$TEST_DIR"/*.bats &> /dev/null 2>&1; then
      echo "  🔄 Running bats..."
      if bats "$TEST_DIR"/*.bats &> /dev/null; then
        echo "  ✅ Bash tests pass"
        TESTS_PASS=true
      else
        echo "  ❌ Bash tests failed"
        inc ERRORS
      fi
    fi
  else
    echo "  ⚠️  Test directory exists but empty"
    inc WARNINGS
  fi
else
  echo "  ℹ️  No tests directory (target: 80% of skills)"
fi

echo ""

# Check for common anti-patterns
echo "🚫 Anti-Patterns"
anti_patterns_found=false

if grep -q "TODO\|FIXME\|XXX" "$SKILL_FILE"; then
  echo "  ⚠️  Contains TODO/FIXME markers"
  inc WARNINGS
  anti_patterns_found=true
fi

if grep -q "You should\|You must\|You can" "$SKILL_FILE"; then
  echo "  ⚠️  Uses second-person (prefer imperative or third-person)"
  inc WARNINGS
  anti_patterns_found=true
fi

# Every skill named in a "Defer to:" line or a "Defer To Instead" section must
# exist under skills/<name>/ or skills/<category>/<name>/; a compound target
# (`brainstorm grill`) is checked by its first word.
SKILLS_ROOT="$(cd "$(dirname "$SKILL_FILE")/.." && pwd)"
[ "$(basename "$SKILLS_ROOT")" = skills ] || SKILLS_ROOT="$(dirname "$SKILLS_ROOT")"
missing_refs=""
for ref in $(awk '/^Defer to:/{print; next} /^## /{on=/Defer To Instead/; next} on && /^- `/' "$SKILL_FILE" |
  grep -oE '`[a-z][a-z0-9-]*[ `]' | tr -d '` ' | sort -u); do
  [ -d "$SKILLS_ROOT/$ref" ] || ls -d "$SKILLS_ROOT"/*/"$ref" >/dev/null 2>&1 || missing_refs="$missing_refs $ref"
done
if [ -n "$missing_refs" ]; then
  echo "  ❌ Defers to non-existent skill(s):$missing_refs"
  inc ERRORS
  anti_patterns_found=true
fi

if [ "$anti_patterns_found" = false ]; then
  echo "  ✅ No common anti-patterns detected"
fi

echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

STATUS="fail"
if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  echo "✅ PASS - No issues found"
  STATUS="pass"
  exit_code=0
elif [ "$ERRORS" -eq 0 ]; then
  echo "⚠️  PASS WITH WARNINGS - $WARNINGS warning(s)"
  STATUS="pass_with_warnings"
  exit_code=0
else
  echo "❌ FAIL - $ERRORS error(s), $WARNINGS warning(s)"
  STATUS="fail"
  exit_code=1
fi

# JSON report goes to stdout only in JSON mode; nothing is written to disk,
# so a CI run leaves the checkout untouched.
if [ -n "$JSON_OUTPUT" ]; then
  cat >&3 << EOF
{
  "skill": "$SKILL_NAME",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "checks": {
    "frontmatter": $FRONTMATTER_PASS,
    "structure": $STRUCTURE_PASS,
    "security": $SECURITY_PASS,
    "examples": $EXAMPLES_PASS,
    "tests": $TESTS_PASS,
    "scripts": $SCRIPTS_PASS,
    "references": $REFERENCES_PASS
  },
  "metrics": {
    "line_count": $LINE_COUNT,
    "example_count": $EXAMPLE_COUNT,
    "test_coverage": $TEST_COVERAGE,
    "script_count": $SCRIPT_COUNT
  },
  "errors": $ERRORS,
  "warnings": $WARNINGS,
  "status": "$STATUS"
}
EOF
fi

exit $exit_code
