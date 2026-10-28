#!/usr/bin/env bash
# Fixture tests for the ZGUARD-CORE guard (guard-v3 plan R1/R2; keeps the v2
# hardening semantics honest). Extracts the core exactly like CI does, then
# asserts observable guard behavior. Run: bash scripts/ci/test-guards.sh
set -u
cd "$(dirname "$0")/../.."
# Run from inside a Git hook, the caller's GIT_DIR/GIT_INDEX_FILE/... would
# steer every fixture's git command into the calling repository.
# shellcheck disable=SC2046
unset $(git rev-parse --local-env-vars)

GUARD=$(mktemp)
awk '$0=="# ZGUARD-CORE-BEGIN"{on=1;next} $0=="# ZGUARD-CORE-END"{on=0} on' \
	setup/install-git-hooks.sh > "$GUARD"
grep -q '^zharness_guard_entries_of_file()' "$GUARD" || {
	echo "FAIL - guard core extraction failed"; exit 1; }
grep -q '^zharness_guard_at_most_one_active_plan()' "$GUARD" || {
	echo "FAIL - R5 one-plan guard missing from core"; exit 1; }
grep -q '^zharness_guard_completed_plan_phases_done()' "$GUARD" || {
	echo "FAIL - PHASE-DONE guard missing from core"; exit 1; }
grep -q '^zharness_guard_revspec()' "$GUARD" || {
	echo "FAIL - revision selector missing from core"; exit 1; }
grep -q '^zharness_guard_plan_paths()' "$GUARD" || {
	echo "FAIL - plan path selector missing from core"; exit 1; }
# shellcheck disable=SC1090
source "$GUARD"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  ok  - $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL - $1"; }

# S1 / R1: a verdict token quoted in a sub-bullet cannot shadow the
# entry's own first-line verdict (the guard-v3 first-line rule).
v=$(zharness_anchored_verdict '- `2026-08-28T00:00:00Z` — gate verdict `APPROVED` (mode: gate)
  - quoted prior review: verdict: REQUEST_CHANGES
  - `true`')
[ "$v" = "APPROVED" ] &&
	ok "S1 sub-bullet prose does not shadow first-line APPROVED" ||
	bad "S1 expected APPROVED, got '$v'"

# R1 converse: a genuine first-line REQUEST_CHANGES still wins.
v=$(zharness_anchored_verdict '- `2026-08-28T00:00:00Z` — review verdict: REQUEST_CHANGES
  - quoted earlier: verdict: APPROVED
  - `false`')
[ "$v" = "REQUEST_CHANGES" ] &&
	ok "S1 genuine first-line REQUEST_CHANGES respected" ||
	bad "S1 converse expected REQUEST_CHANGES, got '$v'"

# R1 grammar: both verdict token forms are recognized.
v=$(zharness_anchored_verdict '- `2026-08-28T00:00:00Z` — gate verdict: `APPROVE_WITH_REQUESTS`')
[ "$v" = "APPROVE_WITH_REQUESTS" ] &&
	ok "R1 colon form recognized" ||
	bad "R1 colon form expected APPROVE_WITH_REQUESTS, got '$v'"

v=$(zharness_anchored_verdict '- `2026-08-28T00:00:00Z` — gate verdict `APPROVED` (no colon)')
[ "$v" = "APPROVED" ] &&
	ok "R1 backtick form recognized" ||
	bad "R1 backtick form expected APPROVED, got '$v'"

# R1: no verdict token on the first line -> empty (entry ignored), even
# when the body prose mentions one.
v=$(zharness_anchored_verdict '- `2026-08-28T00:00:00Z` — narrative entry
  - sub-bullet mentions verdict: APPROVED')
[ -z "$v" ] &&
	ok "R1 verdictless first line yields no verdict despite body prose" ||
	bad "R1 expected empty verdict, got '$v'"

# S2 / R2: an entry without a leading timestamp is still split out as its
# own entry; indented lines continue the current entry.
tmp=$(mktemp -d)
mkdir -p "$tmp/out"
cat > "$tmp/plan.md" <<'EOF'
---
lane: high-risk
---

## Validation

- undated APPROVED entry for the fixture, verdict `APPROVED`
  - proof_classes: output, unit, integration
  - `true`

- `2026-08-28T00:00:00Z` — dated sibling entry
  - `true`

## Current State and Next Action

- after validation
EOF
zharness_dump_entries "$tmp/plan.md" "$tmp/out"
count=$(ls "$tmp/out" | wc -l | tr -d '[:space:]')
[ "$count" -eq 2 ] &&
	ok "S2 undated entry split as its own entry (2 entries)" ||
	bad "S2 expected 2 entries, got $count"

if [ -f "$tmp/out/e0001.txt" ] && head -1 "$tmp/out/e0001.txt" | grep -q "^- undated"; then
	ok "S2 undated entry is first, full text preserved"
else
	bad "S2 undated entry content wrong"
fi

# S3 / R6 parity: fail-case rejects, pass-case accepts, same-session on a
# high-risk lane rejects. Fixtures mirror the repository's real entry
# grammar (verdict `APPROVED`, no colon) and carry frontmatter.
cat > "$tmp/old.md" <<'EOF'
---
lane: high-risk
---

## Validation

- `2026-08-27T00:00:00Z` — older entry, already on record
  - `true`
EOF
cat > "$tmp/new-fail.md" <<'EOF'
---
lane: high-risk
---

## Validation

- `2026-08-27T00:00:00Z` — older entry, already on record
  - `true`

- `2026-08-28T00:00:00Z` — new gate verdict `APPROVED` with a sabotaged proof
  - proof_classes: output, unit, integration
  - `echo sabotaged-proof && false`
EOF
if zharness_guard_entries_of_file p.md "$tmp/old.md" "$tmp/new-fail.md" 2>/dev/null; then
	bad "S3 fail-case must reject"
else
	ok "S3 fail-case (sabotaged proof) rejects"
fi

cat > "$tmp/new-pass.md" <<'EOF'
---
lane: high-risk
---

## Validation

- `2026-08-27T00:00:00Z` — older entry, already on record
  - `true`

- `2026-08-28T00:00:00Z` — new gate verdict `APPROVED` with a clean proof
  - proof_classes: output, unit, integration
  - `true`
EOF
if zharness_guard_entries_of_file p.md "$tmp/old.md" "$tmp/new-pass.md" 2>/dev/null; then
	ok "S3 pass-case accepts"
else
	bad "S3 pass-case must accept"
fi

cat > "$tmp/new-judge.md" <<'EOF'
---
lane: high-risk
---

## Validation

- `2026-08-27T00:00:00Z` — older entry, already on record
  - `true`

- `2026-08-28T00:00:00Z` — gate verdict `APPROVED` judged same-session
  - proof_classes: output, unit, integration
  - judge: `same-session`
  - `true`
EOF
if zharness_guard_entries_of_file p.md "$tmp/old.md" "$tmp/new-judge.md" 2>/dev/null; then
	bad "S3 same-session on high-risk lane must reject"
else
	ok "S3 same-session judge on high-risk lane rejects"
fi

cat > "$tmp/new-full-ss.md" <<'EOF'
---
lane: normal
---

## Validation

- `2026-08-27T00:00:00Z` — older entry, already on record
  - `true`

- [2026-08-30 (initiative close)] mode `full` verdict `APPROVED` — judge: `same-session`
  - proof_classes: output, unit, integration
  - `true`
EOF
if zharness_guard_entries_of_file p.md "$tmp/old.md" "$tmp/new-full-ss.md" 2>/dev/null; then
	bad "H3 mode full + same-session must reject"
else
	ok "H3 mode full + same-session rejects"
fi

cat > "$tmp/new-gate-ss.md" <<'EOF'
---
lane: normal
---

## Validation

- `2026-08-27T00:00:00Z` — older entry, already on record
  - `true`

- [2026-08-30 (gate)] mode `gate` verdict `APPROVED` — judge: `same-session`
  - proof_classes: output, unit, integration
  - `true`
EOF
if zharness_guard_entries_of_file p.md "$tmp/old.md" "$tmp/new-gate-ss.md" 2>/dev/null; then
	ok "H3 mode gate + same-session on normal lane accepts"
else
	bad "H3 mode gate + same-session must accept"
fi

cat > "$tmp/new-gate-quote-full.md" <<'EOF'
---
lane: normal
---

## Validation

- `2026-08-27T00:00:00Z` — older entry, already on record
  - `true`

- [2026-08-30 (gate)] mode `gate` verdict `APPROVED` — judge: `same-session`
  - proof_classes: output, unit, integration
  - prior close quoted: mode: full
  - `true`
EOF
if zharness_guard_entries_of_file p.md "$tmp/old.md" "$tmp/new-gate-quote-full.md" 2>/dev/null; then
	ok "H3 quoted mode-full in a gate sub-bullet still accepts"
else
	bad "H3 quoted mode-full in body must not reject a gate entry"
fi

# S2/R2 end-to-end: a newly added UNDATED APPROVED entry is visible to the
# whole guard flow and its proofs are re-executed (fail-case rejects).
cat > "$tmp/new-undated-fail.md" <<'EOF'
---
lane: high-risk
---

## Validation

- `2026-08-27T00:00:00Z` — older entry, already on record
  - `true`

- undated entry, verdict `APPROVED`, invisible to the v2 guard
  - proof_classes: output, unit, integration
  - `echo undated-sabotage && false`
EOF
if zharness_guard_entries_of_file p.md "$tmp/old.md" "$tmp/new-undated-fail.md" 2>/dev/null; then
	bad "S2 undated APPROVED entry must be re-executed (fail-case must reject)"
else
	ok "S2 undated APPROVED entry is now guarded (fail-case rejects)"
fi

# LANE: check.md § Lane Matrix is the single source of truth. Its "Required
# proof" and "Judge" columns must agree with the guard, and each lane has a
# positive and a missing-proof case. Changing one side alone fails here.
matrix=$(awk '/^## Lane Matrix/{on=1} on && /^\| `/{print}' skills/stages/check/references/check.md)
[ "$(printf '%s\n' "$matrix" | grep -c .)" = 3 ] &&
	ok "LANE matrix has exactly three lane rows" ||
	bad "LANE matrix rows not found in check.md"
for lane in tiny normal high-risk; do
	row=$(printf '%s\n' "$matrix" | awk -F'|' -v l="\`$lane\`" '{g=$2; gsub(/ /,"",g)} g==l')
	doc=$(printf '%s\n' "$row" | awk -F'|' '{print $3}' | tr -d '`,' | xargs)
	judge=$(printf '%s\n' "$row" | awk -F'|' '{print $6}' | tr -d '`' | xargs)
	[ "$doc" = "$(zharness_lane_required_proof "$lane")" ] &&
		ok "LANE $lane required proof matches guard ($doc)" ||
		bad "LANE $lane doc proof '$doc' != guard '$(zharness_lane_required_proof "$lane")'"
	req=$(zharness_lane_required_proof "$lane" | sed 's/ /, /g')
	for kind in pos miss ss; do
		classes="$req"; j=independent
		[ "$kind" = miss ] && classes=$(printf '%s' "$req" | sed -E 's/(, )?[a-z]+$//')
		[ "$kind" = ss ] && j=same-session
		printf -- '---\nlane: %s\n---\n\n## Validation\n\n- `2026-08-27T00:00:00Z` — older entry, already on record\n  - `true`\n\n- `2026-09-03T00:00:00Z` — phase `main` — verdict: APPROVED — mode: gate\n  - `true`\n  - proof_classes: %s\n  - judge: %s\n' \
			"$lane" "$classes" "$j" > "$tmp/lane-$kind.md"
	done
	zharness_guard_entries_of_file p.md "$tmp/old.md" "$tmp/lane-pos.md" >/dev/null 2>&1 &&
		ok "LANE $lane positive case accepts" || bad "LANE $lane positive case must accept"
	if err=$(zharness_guard_entries_of_file p.md "$tmp/old.md" "$tmp/lane-miss.md" 2>&1 >/dev/null); then
		bad "LANE $lane missing-proof case must reject"
	else
		want=$(zharness_lane_required_proof "$lane" | awk '{print $NF}')
		printf '%s' "$err" | grep -q "missing from proof_classes: $want" &&
			ok "LANE $lane missing proof rejects naming '$want'" ||
			bad "LANE $lane rejection does not name '$want': $err"
	fi
	if zharness_guard_entries_of_file p.md "$tmp/old.md" "$tmp/lane-ss.md" >/dev/null 2>&1; then
		got="same-session allowed"
	else
		got=independent
	fi
	[ "$got" = "$judge" ] &&
		ok "LANE $lane judge rule matches guard ($judge)" ||
		bad "LANE $lane doc judge '$judge' but guard behaves as '$got'"
done

# PATH: final-mode rule. A normal single-phase plan closes on a same-session
# gate; high-risk and explicit full both demand an independent judge.
mk_final() {
	printf -- '---\nlane: %s\n---\n\n## Validation\n\n- `2026-08-27T00:00:00Z` — older entry, already on record\n  - `true`\n\n- `2026-09-03T00:00:00Z` — phase `main` — verdict: APPROVED — mode: %s\n  - `true`\n  - proof_classes: output, unit, integration\n  - judge: same-session\n' "$1" "$2" > "$3"
}
mk_final normal gate "$tmp/path-normal.md"
mk_final high-risk full "$tmp/path-hr.md"
mk_final normal full "$tmp/path-explicit.md"
zharness_guard_entries_of_file p.md "$tmp/old.md" "$tmp/path-normal.md" >/dev/null 2>&1 &&
	ok "PATH normal single-phase final gate (same-session) accepts" || bad "PATH normal final gate must accept"
zharness_guard_entries_of_file p.md "$tmp/old.md" "$tmp/path-hr.md" >/dev/null 2>&1 &&
	bad "PATH high-risk final full must require independent judge" || ok "PATH high-risk final full requires independent judge"
zharness_guard_entries_of_file p.md "$tmp/old.md" "$tmp/path-explicit.md" >/dev/null 2>&1 &&
	bad "PATH explicit full must require independent judge" || ok "PATH explicit full requires independent judge"

# S4 portability: the pre-commit hook's shebang is `#!/bin/bash`, which on
# macOS is bash 3.2 — no associative arrays, and a hex array subscript there is
# evaluated as arithmetic and kills the shell. Re-run the two decisive cases
# under a legacy bash if one is present, so the guard core can never regress
# into a bash-4-only construct. Old side carries an entry in both cases: that
# is what populates the hash set and what used to blow up.
LEGACY_BASH=""
for cand in /bin/bash /usr/local/bin/bash-3.2; do
	if [ -x "$cand" ] && case "$("$cand" -c 'echo ${BASH_VERSINFO[0]}')" in 3) true ;; *) false ;; esac; then
		LEGACY_BASH="$cand"
		break
	fi
done

if [ -n "$LEGACY_BASH" ]; then
	cat > "$tmp/legacy-old.md" <<'EOF'
---
lane: high-risk
---

## Validation

- `2026-08-27T00:00:00Z` — an entry already on record
  - `true`
EOF
	cat > "$tmp/legacy-pass.md" <<'EOF'
---
lane: high-risk
---

## Validation

- `2026-08-27T00:00:00Z` — an entry already on record
  - `true`

- `2026-08-28T00:00:00Z` — honest work, verdict `APPROVED`
  - proof_classes: output, unit, integration
  - `true`
EOF
	cat > "$tmp/legacy-fail.md" <<'EOF'
---
lane: high-risk
---

## Validation

- `2026-08-27T00:00:00Z` — an entry already on record
  - `true`

- `2026-08-28T00:00:00Z` — verdict `APPROVED` with a sabotaged proof
  - proof_classes: output, unit, integration
  - `echo legacy-sabotage && false`
EOF
	legacy_run() {                            # <new-file>; echoes the guard exit code
		"$LEGACY_BASH" -c '
			source "$1" || exit 90
			zharness_guard_entries_of_file p.md "$2" "$3" >/dev/null 2>&1
		' _ "$GUARD" "$tmp/legacy-old.md" "$1"
		echo $?
	}

	rc=$(legacy_run "$tmp/legacy-pass.md")
	[ "$rc" = 0 ] &&
		ok "S4 legacy bash ($("$LEGACY_BASH" -c 'echo $BASH_VERSION')): honest entry accepted" ||
		bad "S4 legacy bash: honest entry must be accepted, guard exited $rc"

	rc=$(legacy_run "$tmp/legacy-fail.md")
	[ "$rc" != 0 ] &&
		ok "S4 legacy bash: sabotaged entry rejected" ||
		bad "S4 legacy bash: sabotaged entry must be rejected"
else
	echo "  skip - S4 legacy bash 3.x not found on this machine"
fi

# S5 / #85: entry hashes must not depend on trailing blank lines. When
# `## Validation` is the final section, the last entry ends at EOF; appending a
# new entry below gives it a trailing blank line. Before the fix that changed
# its hash and R2 re-executed an entry nobody had touched. The old-side proof
# carries an observable side effect so a re-run is visible in the output.
cat > "$tmp/tail-old.md" <<'EOF'
---
lane: normal
---

## Validation

- `2026-08-27T00:00:00Z` — entry already on record, verdict `APPROVED`
  - proof_classes: output, unit, integration
  - `echo MARKER-OLD-ENTRY-RERUN`
EOF
cat > "$tmp/tail-new.md" <<'EOF'
---
lane: normal
---

## Validation

- `2026-08-27T00:00:00Z` — entry already on record, verdict `APPROVED`
  - proof_classes: output, unit, integration
  - `echo MARKER-OLD-ENTRY-RERUN`

- `2026-08-28T00:00:00Z` — newly appended entry, verdict `APPROVED`
  - proof_classes: output, unit, integration
  - `true`
EOF
s5out=$(zharness_guard_entries_of_file p.md "$tmp/tail-old.md" "$tmp/tail-new.md" 2>&1)
s5rc=$?
[ "$s5rc" -eq 0 ] &&
	ok "S5 appending to a trailing Validation section is accepted" ||
	bad "S5 append must be accepted, guard exited $s5rc"

if printf '%s' "$s5out" | grep -q MARKER-OLD-ENTRY-RERUN; then
	bad "S5 untouched entry was re-executed (#85: trailing blank line changed its hash)"
else
	ok "S5 untouched entry is not re-executed when a sibling is appended"
fi

# R5: at most one non-empty .harness/plans/active/*.md. Zero is idle. Empty files
# do not count. No `local -A`.
r5=$(mktemp -d)
mkdir -p "$r5/.harness/plans/active"
if zharness_guard_at_most_one_active_plan "$r5" 2>/dev/null; then
	ok "R5 zero active plans accepted"
else
	bad "R5 zero must accept"
fi
printf 'one\n' > "$r5/.harness/plans/active/one.md"
if zharness_guard_at_most_one_active_plan "$r5" 2>/dev/null; then
	ok "R5 one active plan accepted"
else
	bad "R5 one must accept"
fi
printf 'two\n' > "$r5/.harness/plans/active/two.md"
if zharness_guard_at_most_one_active_plan "$r5" 2>/dev/null; then
	bad "R5 two active plans must reject"
else
	ok "R5 two active plans rejected"
fi
: > "$r5/.harness/plans/active/two.md"
if zharness_guard_at_most_one_active_plan "$r5" 2>/dev/null; then
	ok "R5 empty second file does not count"
else
	bad "R5 empty second file must not reject"
fi
rm -rf "$r5"

# ---------------------------------------------------------------------------
# ADR 0009: revision selection is centralized. These fixtures need real git
# history, so each builds a throwaway repo and runs the guard inside it.
# ---------------------------------------------------------------------------
gfix() { # <dir> — a repo with identity configured and nothing else
	git -C "$1" init -q
	git -C "$1" config user.email guard@test
	git -C "$1" config user.name guard
	git -C "$1" config commit.gpgsign false
}
gplan() { # <file> <marker-for-old-entry>
	mkdir -p "$(dirname "$1")"
	cat > "$1" <<EOF
---
lane: normal
---

## Validation

- \`2026-09-01T00:00:00Z\` — first gate, verdict \`APPROVED\`
  - proof_classes: output, unit, integration
  - \`echo $2\`
EOF
}

# S6: a plan closing out moves active/ -> completed/. The entries it lands in
# that same commit must be guarded (the old active/-only selector saw nothing),
# and the entries it already carried must not be re-executed.
s6=$(mktemp -d)
gfix "$s6"
gplan "$s6/.harness/plans/active/p.md" MARKER-S6-OLD
git -C "$s6" add -A >/dev/null && git -C "$s6" commit -qm base
mkdir -p "$s6/.harness/plans/completed"
git -C "$s6" mv .harness/plans/active/p.md .harness/plans/completed/p.md
cat >> "$s6/.harness/plans/completed/p.md" <<'EOF'

- `2026-09-02T00:00:00Z` — closing gate, verdict `APPROVED`
  - proof_classes: output, unit, integration
  - `false`
EOF
git -C "$s6" add -A >/dev/null
s6rev=$( cd "$s6" && zharness_guard_revspec staged )
s6base=$(printf '%s' "$s6rev" | cut -f1)
s6head=$(printf '%s' "$s6rev" | cut -f2)
s6paths=$( cd "$s6" && zharness_guard_plan_paths "$s6base" "$s6head" )
[ "$s6paths" = ".harness/plans/completed/p.md" ] &&
	ok "S6 selector sees a plan renamed into completed/" ||
	bad "S6 selector returned '$s6paths', want .harness/plans/completed/p.md"

s6tmp=$(mktemp -d)
s6out=$( cd "$s6" && zhuards_guard_plans "$s6paths" "$s6base" "$s6head" "$s6tmp" 2>&1 )
s6rc=$?
[ "$s6rc" -ne 0 ] &&
	ok "S6 a failing proof landed with the closure is rejected" ||
	bad "S6 closure entry must be guarded, guard exited $s6rc"
if printf '%s' "$s6out" | grep -q MARKER-S6-OLD; then
	bad "S6 the renamed plan's pre-existing entry was re-executed"
else
	ok "S6 rename resolves to the predecessor; old entries are not re-run"
fi
rm -rf "$s6" "$s6tmp"

# S6b: v0.31.0 moves docs/plans/ to .harness/plans/. Entries the moved plans
# already carried must not be re-executed; one added in the move still is.
s6b=$(mktemp -d)
gfix "$s6b"
gplan "$s6b/docs/plans/completed/q.md" MARKER-S6B-DONE
gplan "$s6b/docs/plans/active/p.md" MARKER-S6B-ACTIVE
git -C "$s6b" add -A >/dev/null && git -C "$s6b" commit -qm base
mkdir -p "$s6b/.harness"
git -C "$s6b" mv docs/plans .harness/plans
cat >> "$s6b/.harness/plans/active/p.md" <<'EOF'

- `2026-09-02T00:00:00Z` — move gate, verdict `APPROVED`
  - proof_classes: output, unit, integration
  - `false`
EOF
git -C "$s6b" add -A >/dev/null
s6brev=$( cd "$s6b" && zharness_guard_revspec staged )
s6bpaths=$( cd "$s6b" && zharness_guard_plan_paths "$(printf '%s' "$s6brev" | cut -f1)" "$(printf '%s' "$s6brev" | cut -f2)" )
s6btmp=$(mktemp -d)
s6bout=$( cd "$s6b" && zhuards_guard_plans "$s6bpaths" "$(printf '%s' "$s6brev" | cut -f1)" "$(printf '%s' "$s6brev" | cut -f2)" "$s6btmp" 2>&1 )
s6brc=$?
[ "$s6brc" -ne 0 ] &&
	ok "S6b an entry added in the layout move is guarded" ||
	bad "S6b the move's new entry must be guarded, guard exited $s6brc"
if printf '%s' "$s6bout" | grep -q 'MARKER-S6B'; then
	bad "S6b moved plans' pre-existing entries were re-executed"
else
	ok "S6b docs/plans -> .harness/plans resolves to the predecessor"
fi
rm -rf "$s6b" "$s6btmp"

# S7: a push carrying two commits. The entry lands in the first of them, so a
# HEAD~1..HEAD window never sees it; the range base does.
s7=$(mktemp -d)
gfix "$s7"
printf 'seed\n' > "$s7/seed.txt"
git -C "$s7" add -A >/dev/null && git -C "$s7" commit -qm seed
s7base=$(git -C "$s7" rev-parse HEAD)
gplan "$s7/.harness/plans/active/p.md" MARKER-S7
cat >> "$s7/.harness/plans/active/p.md" <<'EOF'

- `2026-09-02T00:00:00Z` — second gate, verdict `APPROVED`
  - proof_classes: output, unit, integration
  - `false`
EOF
git -C "$s7" add -A >/dev/null && git -C "$s7" commit -qm "plan lands here"
printf 'unrelated\n' > "$s7/other.txt"
git -C "$s7" add -A >/dev/null && git -C "$s7" commit -qm "unrelated follow-up"
s7head=$(git -C "$s7" rev-parse HEAD)

s7prev=$( cd "$s7" && zharness_guard_plan_paths "$s7head~1" "$s7head" )
[ -z "$s7prev" ] &&
	ok "S7 the single-commit window is blind to the earlier commit's plan" ||
	bad "S7 fixture is not exercising the gap: HEAD~1 window saw '$s7prev'"

s7paths=$( cd "$s7" && zharness_guard_plan_paths "$s7base" "$s7head" )
[ "$s7paths" = ".harness/plans/active/p.md" ] &&
	ok "S7 the range selector sees the plan across both commits" ||
	bad "S7 range selector returned '$s7paths'"

s7tmp=$(mktemp -d)
( cd "$s7" && zhuards_guard_plans "$s7paths" "$s7base" "$s7head" "$s7tmp" ) >/dev/null 2>&1
s7rc=$?
[ "$s7rc" -ne 0 ] &&
	ok "S7 the failing proof pushed two commits back is rejected" ||
	bad "S7 range guard must reject, exited $s7rc"

# revspec resolves that same range from the push event's before-SHA.
s7rev=$( cd "$s7" && ZHARNESS_BEFORE_SHA="$s7base" ZHARNESS_HEAD_SHA="$s7head" \
	zharness_guard_revspec push )
[ "$s7rev" = "$(printf '%s\t%s' "$s7base" "$s7head")" ] &&
	ok "revspec push resolves the event's before-SHA as the base" ||
	bad "revspec push returned '$s7rev'"

# Fail closed: no before-SHA, no default branch to fall back to.
s7fc=$( cd "$s7" && ZHARNESS_BEFORE_SHA="" ZHARNESS_HEAD_SHA="$s7head" \
	ZHARNESS_DEFAULT_BRANCH=origin/does-not-exist zharness_guard_revspec push 2>&1 )
s7fcrc=$?
[ "$s7fcrc" -ne 0 ] && printf '%s' "$s7fc" | grep -q "FAILED CLOSED" &&
	ok "revspec with no resolvable base fails closed instead of guessing" ||
	bad "revspec must fail closed, exited $s7fcrc (out: $s7fc)"

if ( cd "$s7" && zharness_guard_revspec bogus ) >/dev/null 2>&1; then
	bad "revspec must reject an unknown event"
else
	ok "revspec rejects an unknown event"
fi
rm -rf "$s7" "$s7tmp"

# S8: the index is what becomes the commit, so the one-active-plan gate reads
# staged blobs. An unstaged second plan is worktree noise, not a claim.
s8=$(mktemp -d)
gfix "$s8"
mkdir -p "$s8/.harness/plans/active"
printf 'one\n' > "$s8/.harness/plans/active/one.md"
git -C "$s8" add -A >/dev/null && git -C "$s8" commit -qm one
printf 'two\n' > "$s8/.harness/plans/active/two.md"
if zharness_guard_at_most_one_active_plan "$s8" staged 2>/dev/null; then
	ok "S8 an unstaged second plan does not gate the commit"
else
	bad "S8 staged mode must ignore an unstaged worktree file"
fi
if zharness_guard_at_most_one_active_plan "$s8" 2>/dev/null; then
	bad "S8 worktree mode must still see the second file (advisory)"
else
	ok "S8 worktree mode still reports the second file"
fi
git -C "$s8" add -A >/dev/null
if zharness_guard_at_most_one_active_plan "$s8" staged 2>/dev/null; then
	bad "S8 two staged plans must reject"
else
	ok "S8 two staged plans rejected"
fi
: > "$s8/.harness/plans/active/two.md"
git -C "$s8" add -A >/dev/null
if zharness_guard_at_most_one_active_plan "$s8" staged 2>/dev/null; then
	ok "S8 an empty staged second file does not count"
else
	bad "S8 empty staged second file must not reject"
fi
rm -rf "$s8"

# PHASE-DONE: a completed plan whose lifecycle_status: completed must show
# every phase status: done.
pd=$(mktemp -d)
cat > "$pd/all-done.md" <<'EOF'
## Phases and Verification

- phase_slug: alpha
  story_id: X1
  status: done

- phase_slug: beta
  story_id: X2
  status: done

## Current State and Next Action

- lifecycle_status: completed
EOF
if zharness_guard_completed_plan_phases_done p.md "$pd/all-done.md" 2>/dev/null; then
	ok "PHASE-DONE all phases done + completed accepts"
else
	bad "PHASE-DONE all phases done + completed must accept"
fi

cat > "$pd/mixed.md" <<'EOF'
## Phases and Verification

- phase_slug: alpha
  story_id: X1
  status: checked

- phase_slug: beta
  story_id: X2
  status: done

## Current State and Next Action

- lifecycle_status: completed
EOF
pd_out=$(zharness_guard_completed_plan_phases_done p.md "$pd/mixed.md" 2>&1)
pd_rc=$?
if [ "$pd_rc" -ne 0 ]; then
	ok "PHASE-DONE mixed statuses under completed rejects"
else
	bad "PHASE-DONE mixed statuses under completed must reject"
fi
printf '%s' "$pd_out" | grep -q "alpha: checked" &&
	ok "PHASE-DONE names the offending phase and its status" ||
	bad "PHASE-DONE must name the offending phase, got: $pd_out"

cat > "$pd/in-progress.md" <<'EOF'
## Phases and Verification

- phase_slug: alpha
  story_id: X1
  status: checked

## Current State and Next Action

- lifecycle_status: in-progress
EOF
if zharness_guard_completed_plan_phases_done p.md "$pd/in-progress.md" 2>/dev/null; then
	ok "PHASE-DONE non-completed lifecycle is a no-op regardless of phase status"
else
	bad "PHASE-DONE non-completed lifecycle must not reject"
fi
rm -rf "$pd"

# record-check.sh: convenience runner, not the guarantee. Pass/fail keep the
# proof's exit code; timeout → gtimeout → unbounded (stock macOS has neither).
rc_out=$(bash scripts/workflow/record-check.sh -- true 2>&1)
rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$rc_out" | grep -q "PASS" &&
	ok "record-check true exits 0" ||
	bad "record-check true expected 0, got $rc"
rc_out=$(bash scripts/workflow/record-check.sh -- false 2>&1)
rc=$?
[ "$rc" -eq 1 ] &&
	ok "record-check false exits 1" ||
	bad "record-check false expected 1, got $rc"
rc_bin=$(mktemp -d)
ln -s "$(command -v sh)" "$rc_bin/sh"
ln -s "$(command -v tail)" "$rc_bin/tail"
ln -s "$(command -v sed)" "$rc_bin/sed"
rc_out=$(PATH="$rc_bin" /bin/bash scripts/workflow/record-check.sh -- true 2>&1)
rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$rc_out" | grep -q "no timeout/gtimeout" &&
	ok "record-check isolated PATH warns and exits 0" ||
	bad "record-check isolated PATH expected warning+0, got $rc (out: $rc_out)"
rm -rf "$rc_bin"

# R16: install-git-hooks.sh replaces a stale hook of its own, refuses a
# foreign one, and never swallows that refusal.
hk=$(mktemp -d)
gfix "$hk"
hk_install() { ( cd "$hk" && bash "$OLDPWD/setup/install-git-hooks.sh" "$@" ) >/dev/null 2>&1; }
hk_install && [ -x "$hk/.git/hooks/pre-commit" ] &&
	ok "R16 fresh install creates the pre-commit hook" ||
	bad "R16 fresh install did not create the hook"
hk_want=$(shasum "$hk/.git/hooks/pre-commit" | cut -d' ' -f1)
hk_install && [ "$(shasum "$hk/.git/hooks/pre-commit" | cut -d' ' -f1)" = "$hk_want" ] &&
	ok "R16 re-install over a current hook exits 0 and keeps it" ||
	bad "R16 re-install over a current hook failed"
sed -i.bak 's/zhuards_guard_plans "$plans" "$gbase" "$ghead" "$tmpdir"/zhuards_guard_plans "$plans" staged "$tmpdir"/' "$hk/.git/hooks/pre-commit"
hk_install && [ "$(shasum "$hk/.git/hooks/pre-commit" | cut -d' ' -f1)" = "$hk_want" ] &&
	ok "R16 stale zharness hook is replaced without --force" ||
	bad "R16 stale zharness hook was kept"
printf '#!/bin/sh\necho foreign\n' > "$hk/.git/hooks/pre-commit"
if hk_install; then
	bad "R16 foreign hook must make the installer exit non-zero"
else
	grep -q '^echo foreign$' "$hk/.git/hooks/pre-commit" &&
		ok "R16 foreign hook is refused and left in place" ||
		bad "R16 foreign hook was modified"
fi
rm -rf "$hk"

# PP: the pre-push hook guards the branch range, as CI does. Commit A lands an
# entry whose proof passes; commit B breaks that proof without touching the
# plan, so each pre-commit accepts. The push must be rejected until it holds.
pp=$(mktemp -d)
git init -q --bare "$pp/remote.git"
mkdir -p "$pp/w/setup"
gfix "$pp/w"
git -C "$pp/w" symbolic-ref HEAD refs/heads/master
git -C "$pp/w" config core.hooksPath "$pp/w/.git/hooks"
git -C "$pp/w" remote add origin "$pp/remote.git"
cp setup/install-git-hooks.sh "$pp/w/setup/"
git -C "$pp/w" add -A >/dev/null && git -C "$pp/w" commit -qm "chore: seed"
git -C "$pp/w" push -q origin master 2>/dev/null
( cd "$pp/w" && bash setup/install-git-hooks.sh ) >/dev/null 2>&1
[ -x "$pp/w/.git/hooks/pre-push" ] &&
	ok "PP install creates the pre-push hook" ||
	bad "PP install did not create the pre-push hook"
pp_git() { ( cd "$pp/w" && git "$@" ) >/dev/null 2>&1; }
pp_git checkout -qb feat
printf 'x\n' > "$pp/w/flag.txt"
mkdir -p "$pp/w/.harness/plans/active"
cat > "$pp/w/.harness/plans/active/p.md" <<'EOF'
---
lane: normal
---

## Validation

- `2026-09-01T00:00:00Z` — gate, verdict `APPROVED`
  - proof_classes: output, unit, integration
  - `test -f flag.txt`
EOF
pp_git add -A && pp_git commit -qm "feat: land plan"
pp_git rm -q flag.txt && pp_git commit -qm "fix: drop flag"
[ "$(git -C "$pp/w" rev-list --count master..feat)" = 2 ] &&
	ok "PP pre-commit accepts both commits (the single-commit gap)" ||
	bad "PP fixture expected two accepted commits on feat"
if pp_git push -q origin feat; then
	bad "PP push of a range with a broken proof must be rejected"
else
	git -C "$pp/remote.git" rev-parse -q --verify refs/heads/feat >/dev/null &&
		bad "PP rejected push still updated the remote" ||
		ok "PP push of a range with a broken earlier proof is rejected"
fi
pp_git branch stale HEAD
printf 'x\n' > "$pp/w/flag.txt"
pp_git add -A && pp_git commit -qm "fix: restore flag"
if pp_git push -q origin feat &&
	[ "$(git -C "$pp/remote.git" rev-parse refs/heads/feat)" = "$(git -C "$pp/w" rev-parse HEAD)" ]; then
	ok "PP push passes once the range's proofs hold"
else
	bad "PP push with passing proofs was rejected"
fi
pp_out=$( cd "$pp/w" && git push -q origin stale 2>&1 )
pp_rc=$?
[ "$pp_rc" -ne 0 ] && printf '%s' "$pp_out" | grep -q "not the checked-out HEAD" &&
	ok "PP a plan-carrying ref other than HEAD is rejected, not guessed" ||
	bad "PP a plan-carrying ref other than HEAD must be rejected (rc $pp_rc)"
pp_git branch side master
pp_git push -q origin side &&
	ok "PP a ref with no plan changes pushes from any checkout" ||
	bad "PP a ref with no plan changes was rejected"
rm -rf "$pp"

# FLOOR: entries already committed at the historical floor are exempt, so the
# pre-cutover range whose proofs cannot run at this HEAD is accepted; an
# unresolvable floor appends nothing and changes no behavior.
ftmp=$(mktemp -d)
mkdir -p "$ftmp/repo/.harness/plans/active"
(
	cd "$ftmp/repo" || exit 1
	git init -q .
	git config user.email t@example.com
	git config user.name t
	cat > .harness/plans/active/p.md <<'EOF'
---
status: active
lane: normal
---
## Validation
- `2026-01-01T00:00:00Z` — phase `p1` — verdict: APPROVED — mode: gate
  - proof_classes: output, unit, integration
  - `false`
EOF
	git add -A && git commit -qm floor
	git rev-parse HEAD > "$ftmp/floor"
	cat >> .harness/plans/active/p.md <<'EOF'
- `2026-01-02T00:00:00Z` — phase `p2` — verdict: APPROVED — mode: gate
  - proof_classes: output, unit, integration
  - `false`
EOF
	git add -A && git commit -qm after
)
: > "$ftmp/hashes"
zharness_guard_historical_floor_hashes "$ftmp/repo" .harness/plans/active/p.md "$ftmp/hashes" "$(cat "$ftmp/floor")"
[ "$(wc -l < "$ftmp/hashes" | tr -d " ")" = 1 ] &&
	ok "FLOOR emits the floor commit's entry hashes" ||
	bad "FLOOR expected 1 hash, got $(wc -l < "$ftmp/hashes")"

: > "$ftmp/hashes2"
zharness_guard_historical_floor_hashes "$ftmp/repo" .harness/plans/active/p.md "$ftmp/hashes2" deadbeef
[ ! -s "$ftmp/hashes2" ] &&
	ok "FLOOR unresolvable floor appends nothing" ||
	bad "FLOOR unresolvable floor appended $(wc -l < "$ftmp/hashes2") hash(es)"

ftmp2=''   # set only when the range exists; the cleanup below must not trip set -u
if git rev-parse --verify --quiet fe814b4a^{commit} >/dev/null 2>&1 &&
	git rev-parse --verify --quiet 4cd86cf^{commit} >/dev/null 2>&1; then
	ftmp2=$(mktemp -d)
	if zhuards_guard_plans "docs/plans/active/cli-rust-rewrite.md" fe814b4a 4cd86cf "$ftmp2" >/dev/null 2>&1; then
		ok "FLOOR the pre-cutover range is exempt"
	else
		bad "FLOOR the pre-cutover range is still rejected"
	fi
else
	echo "  skip - FLOOR range fe814b4a..4cd86cf not in this checkout"
fi
rm -rf "$ftmp" "$ftmp2"

# SECRETS: staged value-shaped secrets and secret-bearing filenames are
# rejected by file:line and pattern name; the value itself is never printed.
# The key is assembled at runtime so this file never holds a matching literal.
stmp=$(mktemp -d)
git -C "$stmp" init -q
key="AKIA""IOSFODNN7EXAMPLE"
printf 'aws_key = %s\n' "$key" > "$stmp/app.cfg"
printf 'Pass the token in a header.\n' > "$stmp/doc.md"
cred="u:pw"
printf 'DB=postgres://%s@localhost/db\n' "$cred" > "$stmp/.env.example"
git -C "$stmp" add app.cfg doc.md .env.example
out=$(zharness_guard_staged_secrets "$stmp" 2>&1); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'app.cfg:1' &&
	ok "SECRETS staged AWS key rejected by file:line" ||
	bad "SECRETS expected rejection naming app.cfg:1, got rc=$rc: $out"
printf '%s' "$out" | grep -q "$key" &&
	bad "SECRETS output leaked the key value" ||
	ok "SECRETS output does not contain the key value"
printf '%s' "$out" | grep -qE 'doc\.md|\.env\.example' &&
	bad "SECRETS false positive on doc prose or an .example file" ||
	ok "SECRETS prose mentioning token and .example files pass"
git -C "$stmp" rm -q --cached app.cfg
zharness_guard_staged_secrets "$stmp" >/dev/null 2>&1 &&
	ok "SECRETS clean index accepted" ||
	bad "SECRETS clean index rejected"
printf 'X=1\n' > "$stmp/.env"
git -C "$stmp" add .env
zharness_guard_staged_secrets "$stmp" 2>&1 | grep -q '\.env' &&
	ok "SECRETS staged .env filename rejected" ||
	bad "SECRETS staged .env not rejected"
git -C "$stmp" rm -q --cached .env
printf '++x\n+++ %s\n' "$key" > "$stmp/plus.txt"
printf 'k=%s\n' "$key" > "$stmp/é.txt"
printf 'bin\000k=%s\n' "$key" > "$stmp/blob.bin"
git -C "$stmp" add plus.txt é.txt blob.bin
out=$(zharness_guard_staged_secrets "$stmp" 2>&1)
printf '%s' "$out" | grep -q 'plus.txt:2' &&
	ok "SECRETS added line starting ++ scanned with correct line number" ||
	bad "SECRETS ++ line missed or misnumbered: $out"
printf '%s' "$out" | grep -q 'é.txt:1' &&
	ok "SECRETS non-ASCII path scanned" ||
	bad "SECRETS non-ASCII path missed: $out"
printf '%s' "$out" | grep -q 'blob.bin:1' &&
	ok "SECRETS binary blob scanned" ||
	bad "SECRETS binary blob missed: $out"
git -C "$stmp" rm -q --cached plus.txt é.txt blob.bin
printf 'k=%s\n' "$key" > "$stmp/cfg.example"
git -C "$stmp" add cfg.example
zharness_guard_staged_secrets "$stmp" 2>&1 | grep -q 'cfg.example:1' &&
	ok "SECRETS .example still rejects an AWS key" ||
	bad "SECRETS .example exemption let an AWS key through"
git -C "$stmp" rm -q --cached cfg.example
printf 'k=%s\n' "$key" > "$stmp/err.cfg"
git -C "$stmp" add err.cfg
git -C "$stmp" config diff.algorithm nosuch
zharness_guard_staged_secrets "$stmp" >/dev/null 2>&1 &&
	bad "SECRETS invalid diff.algorithm made the guard fail open" ||
	ok "SECRETS git error (invalid diff.algorithm) fails closed"
git -C "$stmp" config --unset diff.algorithm
git -C "$stmp" config diff.orderFile "$stmp/nosuch-order"
zharness_guard_staged_secrets "$stmp" >/dev/null 2>&1 &&
	bad "SECRETS missing diff.orderFile made the guard fail open" ||
	ok "SECRETS git error (missing diff.orderFile) fails closed"
git -C "$stmp" config --unset diff.orderFile
git -C "$stmp" rm -q --cached err.cfg
printf '1\n2\n3\n4\n5\n6\n7\n' > "$stmp/ctx.txt"
git -C "$stmp" add ctx.txt
git -C "$stmp" -c user.name=t -c user.email=t@t commit -qm ctx
printf '1\nX\n3\n4\n5\n6\nk=%s\n' "$key" > "$stmp/ctx.txt"
git -C "$stmp" add ctx.txt
printf '*.txt diff=hide\n' > "$stmp/.git/info/attributes"
git -C "$stmp" config diff.interHunkContext 10
git -C "$stmp" config diff.hide.textconv 'sed s/AKIA/XXXX/'
zharness_guard_staged_secrets "$stmp" 2>&1 | grep -q 'ctx.txt:7' &&
	ok "SECRETS ignores textconv and interHunkContext; line number exact" ||
	bad "SECRETS textconv/interHunkContext hid or misnumbered the key"
git -C "$stmp" reset -q ctx.txt; rm -f "$stmp/.git/info/attributes"
ln -s ctx.txt "$stmp/link"
git -C "$stmp" add link
git -C "$stmp" -c user.name=t -c user.email=t@t commit -qm link
rm "$stmp/link"; printf 'k=%s\n' "$key" > "$stmp/link"
git -C "$stmp" add link
zharness_guard_staged_secrets "$stmp" 2>&1 | grep -q 'link:1' &&
	ok "SECRETS symlink replaced by a file (type change) scanned" ||
	bad "SECRETS type change bypassed the scan"
git -C "$stmp" reset -q link
printf 'k=%s\n' "$key" > "$stmp/:(literal)magic.cfg"
git -C "$stmp" add -- ":(literal):(literal)magic.cfg"
zharness_guard_staged_secrets "$stmp" 2>&1 | grep -q 'magic.cfg:1' &&
	ok "SECRETS filename with pathspec magic scanned literally" ||
	bad "SECRETS pathspec-magic filename bypassed the scan"
printf 'a\n' > "$stmp/old.txt"
git -C "$stmp" add old.txt
git -C "$stmp" -c user.name=t -c user.email=t@t commit -qm base
git -C "$stmp" mv old.txt new.txt
printf 'k=%s\n' "$key" >> "$stmp/new.txt"
git -C "$stmp" add new.txt
zharness_guard_staged_secrets "$stmp" 2>&1 | grep -q 'new.txt:2' &&
	ok "SECRETS renamed file scanned at its new path" ||
	bad "SECRETS renamed file missed"
rm -rf "$stmp"

# STALE: the installed pre-commit wrapper compares itself with its template
# (failures.md, 2026-09-16). An edited install must block with a re-install hint.
st=$(mktemp -d)
mkdir -p "$st/setup"
gfix "$st"
git -C "$st" config core.hooksPath "$st/.git/hooks"
cp setup/install-git-hooks.sh "$st/setup/"
( cd "$st" && bash setup/install-git-hooks.sh ) >/dev/null 2>&1
printf 'x\n' > "$st/a.txt"
( cd "$st" && git add -A && git commit -qm "chore: seed" ) >/dev/null 2>&1 &&
	ok "STALE a current wrapper commits" ||
	bad "STALE a current wrapper was rejected"
printf '# local edit\n' >> "$st/.git/hooks/pre-commit"
printf 'y\n' > "$st/a.txt"
st_out=$( cd "$st" && git commit -qam "chore: edit" 2>&1 )
st_rc=$?
[ "$st_rc" -ne 0 ] && printf '%s' "$st_out" | grep -q "install-git-hooks.sh --force" &&
	ok "STALE an edited wrapper is rejected with the re-install command" ||
	bad "STALE an edited wrapper must be rejected (rc $st_rc)"
rm -rf "$st"

# R6 LANE-RAISE: a diff touching an always-review path raises the declared
# lane to high-risk, so R3/R4 judge it as high-risk (check-risk.md).
lr=$(mktemp -d)
printf '# x\n\n## Unattended Shipping\n\n- Always-review paths: setup/hooks/**, scripts/ci/**\n' > "$lr/AGENTS.md"
l=$(printf '%s\n' docs/a.md .github/workflows/ci.yml | zharness_effective_lane normal "$lr/AGENTS.md")
[ "$l" = "high-risk" ] && ok "R6 CI workflow raises normal to high-risk" ||
	bad "R6 CI workflow expected high-risk, got '$l'"
l=$(printf '%s\n' scripts/ci/test-guards.sh | zharness_effective_lane tiny "$lr/AGENTS.md")
[ "$l" = "high-risk" ] && ok "R6 AGENTS.md always-review glob raises tiny" ||
	bad "R6 AGENTS.md glob expected high-risk, got '$l'"
l=$(printf '%s\n' cli/Cargo.lock | zharness_effective_lane normal "$lr/none.md")
[ "$l" = "high-risk" ] && ok "R6 lockfile raises without AGENTS.md" ||
	bad "R6 lockfile expected high-risk, got '$l'"
l=$(printf '%s\n' docs/a.md skills/x/SKILL.md | zharness_effective_lane normal "$lr/AGENTS.md")
[ "$l" = "normal" ] && ok "R6 docs-only diff keeps declared lane" ||
	bad "R6 docs-only expected normal, got '$l'"
l=$(printf '' | zharness_effective_lane "" "$lr/AGENTS.md")
[ -z "$l" ] && ok "R6 no lane stays no lane" ||
	bad "R6 no lane expected empty, got '$l'"

# TRIP: each validator has a committed bad fixture that must make it fail.
tl=$(mktemp -d)
mkdir -p "$tl/scripts/ci" "$tl/docs" "$tl/cli" "$tl/skills" "$tl/setup"
gfix "$tl"
cp scripts/ci/verify-doc-links.sh "$tl/scripts/ci/"
( cd "$tl" && bash scripts/ci/verify-doc-links.sh ) >/dev/null 2>&1 &&
	ok "TRIP verify-doc-links control tree is clean" ||
	bad "TRIP verify-doc-links control tree must pass"
cp scripts/ci/fixtures/doc-links-bad.md "$tl/docs/"
tl_out=$( cd "$tl" && bash scripts/ci/verify-doc-links.sh 2>&1 )
tl_rc=$?
[ "$tl_rc" -eq 1 ] && printf '%s' "$tl_out" | grep -q "broken doc cross-reference" &&
	ok "TRIP verify-doc-links fails on a broken link" ||
	bad "TRIP verify-doc-links must fail on its bad fixture (rc $tl_rc)"
rm -rf "$tl"
vs_out=$(bash scripts/ci/validate-skill.sh scripts/ci/fixtures/bad-skill/SKILL.md 2>&1)
vs_rc=$?
[ "$vs_rc" -ne 0 ] && printf '%s' "$vs_out" | grep -q "they must match" &&
	ok "TRIP validate-skill fails on a name/directory mismatch" ||
	bad "TRIP validate-skill must fail on its bad fixture (rc $vs_rc)"

# NEST: the suite run from a real pre-commit hook (as proof replay does) must
# leave the calling repository's HEAD, index and config untouched. `commit -a`
# hands the hook an absolute GIT_INDEX_FILE (a plain commit's is relative and
# harmless). The nested run skips this block so it does not recurse.
if [ -z "${ZHARNESS_GUARDS_NESTED:-}" ]; then
	nest=$(mktemp -d)
	gfix "$nest"
	git -C "$nest" config user.email outer@test
	git -C "$nest" config core.hooksPath "$nest/.git/hooks"
	printf '#!/bin/sh\nZHARNESS_GUARDS_NESTED=1 bash "%s/scripts/ci/test-guards.sh" > "%s/log" 2>&1\n' \
		"$PWD" "$nest" > "$nest/.git/hooks/pre-commit"
	chmod +x "$nest/.git/hooks/pre-commit"
	nest_cfg=$(git -C "$nest" config --local --list)
	printf 'x\n' > "$nest/a.txt"
	git -C "$nest" add a.txt
	if git -C "$nest" commit -qam outer >/dev/null 2>&1; then
		[ "$(git -C "$nest" rev-list --count HEAD)" = 1 ] &&
			[ "$(git -C "$nest" ls-files)" = a.txt ] &&
			[ -z "$(git -C "$nest" status --porcelain -- . ':!log')" ] &&
			[ "$(git -C "$nest" config --local --list)" = "$nest_cfg" ] &&
			ok "NEST suite inside a pre-commit hook leaves the caller's repo untouched" ||
			bad "NEST suite inside a pre-commit hook changed the caller's HEAD/index/config"
	else
		bad "NEST suite inside a pre-commit hook failed (log: $(tail -3 "$nest/log" 2>/dev/null))"
	fi
	rm -rf "$nest"
fi

rm -rf "$tmp" "$GUARD"
echo
echo "guards: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
