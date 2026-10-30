# Verification Audit

Read-only audit of the agent setup against two principles: verification closes the loop, and repeatable mechanics move out of judgment. Prompt: [2026-10-30-verification-audit-prompt.md](2026-10-30-verification-audit-prompt.md). Line numbers refer to commit `a3e1ff1`.

**Verdict:** the plan/proof spine closes the loop well. The pre-commit guard re-runs every cited proof, and that is real enforcement. Runtime observation is the weak half. "Exercise the change", the risk verdict, perf and CI triage are prose recipes with no shared driver, and the only thing to hill-climb against is the binary size gate.

**Scope:** read the playbooks, all stage skills and their references, the reason and tool SKILL.md files, the workflow scripts, the CI workflows, settings, the ninja-kit hook head, and parts of the guard/test sources. Not read: `site/`, `cli/src/`, `docs/`, `.harness/plans/completed/`, most reference files under `create-skill`, `write` and `turbo-mono-platform`, and past session transcripts. See E.

## A. Scorecard

| Skill / workflow | Goal explicit | Agent can observe | Compare step | Mechanics scripted | Top issue |
|---|---|---|---|---|---|
| `check` gate (check.md) | Y (lane matrix :9-13) | Y (commands) | Y (verdict :37) | partial | `record-check.sh` is optional (:33) and not shipped to consumer repos (no ref in `cli/src`) |
| `check` exercise (check-exercise.md) | N ("check one thing" :15) | partial | partial (:23-25) | N | Start/ready/drive/stop is all prose (:14-17) |
| `check` risk (check-risk.md) | Y (rubric :9-15) | Y (git, gh) | Y | N | 400-line count with exclusions done by hand (:11) |
| `work full` | Y (task `check:`) | Y | Y (:21 one fix, then block) | partial | Stop gates are prompt-only (work-full.md:19) |
| `work bounded` | Y (:7 one command) | Y | Y (:10) | N/A | fine |
| `brainstorm` lock | Y (skeleton requires `acceptance:`) | N/A | Y self-review (lock :61) | N | Lane is pure judgment (brainstorm.md:25) |
| `to-plan` | Y (:35 every task gets a command) | N/A | Y (:37 verify) | N | No plan linter; the hook only parses at commit time |
| `handoff` | Y (:16, :20) | Y | Y | N | Compaction (:23) is a manual, byte-exact edit |
| `watzup` | N/A | Y | N/A | N | Base-resolution shell pasted in prose (:14-21) |
| `hunt` | Y (:15, :43-48) | Y/partial | Y (:69) | partial | Human loop via `hitl-loop.template.sh` |
| `think` | Y (:15) | N/A | Y (lenses :40) | N/A | fine |
| bug-fix | Y | Y | Y (red first, :4) | partial | inherits `hunt` |
| perf | Y (:13 delta+unit) | partial | Y (:10) | N | No benchmark runner; variance and run count left to the agent (:5) |
| prototype | partial | Y (`run`/chrome, :9) | N ("recommend" :10) | N | No rubric for comparing variants |
| refactoring | Y (pin, :6) | Y | Y (:10 keep/revert) | N | "reader load dropped" isn't measured |
| ship / land | Y | Y (gh) | Y | partial | Land steps 1–5 are a gh command sequence in prose (ship.md:37-42) |
| babysit | Y (:11) | partial | Y | N | "read the logs" (:9) with no log-fetch tool named |
| fanout / arena | Y (done predicate) | Y | Y (aggregate, :4) | N | Rubric scoring is manual (work-fanout.md:59) |
| `retro` | Y (:3) | Y (session-digest.py) | Y (rerun gate, harness-improvement.md:28-33) | Y | good example |
| `ambition` | Y (`lint-prompt.sh` exit 0) | Y | Y | Y | lint only checks that slots are filled (:34) |
| `git` | Y (exit condition :105) | Y | partial | Y (scan/group scripts) | :64 "Never include AI attribution" conflicts with host attribution |
| `librarian` | Y | Y | partial | Y (`gh-search.sh`) | fine |
| `read` / `learn` | partial | Y | N | Y (`fetch.sh`) | `learn` self-review needs the human (learn.md:33) |
| `write` | N | N | N | N | 8 eval dirs, no runner in repo |
| `create-skill` | Y (:15-16) | Y | Y | Y | fine |
| `create-cli` (141 lines) | N | N/A | N | N | Plan file frontmatter `status: draft`, no `lane:` (:120-127), unlike the lock skeleton |
| `prompt-leverage` | N | N | partial (rubric :67) | partial | vague goal |

## B. Top 5 gaps

### 1. The proof runner is optional and missing in consumer repos

Highest-traffic path: every gate.

- **Evidence:** `skills/stages/check/references/check.md:33`: "IF `scripts/workflow/record-check.sh` exists → … else keep each exit code (never let a pipe hide it)". `grep record-check cli/src` returns nothing, so `zharness install` doesn't ship it. `work-full.md:15` has the same pattern with an `awk` fallback.
- **Why it matters:** in any repo other than this one, every agent hand-rolls proof capture. The hook's re-execution then rejects the entry late, at commit time, instead of the agent seeing the failure while it writes.
- **Fix:** ship it through zharness and make it the only path, with JSON output:
  `zharness proof run [-t S] -- cmd... -> {"ok":bool,"proofs":[{"cmd","exit","tail"}]}`.
  Rewrite check.md:33 to: "Run `zharness proof run -- …`; cite only commands it reports `ok`."

### 2. "Exercise the change" is a prose recipe with no driver

Runs on every runtime PR (feature.md:6); when it is wrong, the risk verdict is wrong too.

- **Evidence:** `check-exercise.md:14-17`: "Start what the recipe names, in the background, and wait for readiness in one bounded shell loop … Drive the changed path once … Stop everything you started." Line 9 says "Never guess how to start the app", but `AGENTS.md` has no run/exercise command for `zharness`.
- **Why it matters:** each agent writes its own start/poll/kill loop. "One thing the tests can't show" (:15) has no pass criterion. `check-risk.md:14` reads `## Exercised` from the PR body, which is self-reported. The hook has no `Exercised` check (grep of `install-git-hooks.sh` is empty).
- **Fix:** add an `AGENTS.md` § Exercise recipe, e.g. `cd cli && cargo run -- install --dry-run <tmpdir>`. Add `scripts/workflow/exercise.sh --start CMD --ready CMD --drive CMD --expect REGEX [--fail-case CMD --expect-fail REGEX] -> JSON {started, ready_ms, drive:{exit,matched}, fail_case:{...}, stopped}`. It emits the `## Exercised` block, so the check verdict comes from parsed output, not prose.

### 3. The risk verdict does arithmetic by hand

It gates unattended merge, so a miscount can auto-merge a PR that needs review.

- **Evidence:** `check-risk.md:7-12`: "more than 400 changed lines … not counting docs, tests, generated files and lockfiles", plus the always-review path match. `ship.md:37-42` gives the gh precondition and merge sequence as prose.
- **Why it matters:** the size and path rules are deterministic. Two judges will classify "generated" or "docs" differently. Judgment should go only to the Judgment Test (:19).
- **Fix:** `scripts/workflow/risk-facts.sh <base> <sha> -> JSON {counted_lines, excluded_lines, excluded_paths[], always_review_hits[], test_changes:{removed_files[], skip_markers_added[]}, ci_config_touched}`. It reads `Always-review paths` from `git show origin/$BASE:AGENTS.md`. Rewrite check-risk.md § Checks as "run `risk-facts.sh`; any non-empty hit → needs-review".

### 4. Nothing to hill-climb against, apart from binary size

Matters for perf, `write`, and skill quality.

- **Evidence:** `perf.md:5`: "name … its unit, run count and variance", with no tool. `check-review.md:7`: "A reported number … carries its run count, spread and limiter, or it is a claim." `evals/*` holds prompts and graders (e.g. `evals/01-en-ai-tone-status/graders/skill-fired.md`: `type: tool_used`, `min: 1`), but nothing in the repo runs them. The only automated threshold is `cli-ci.yml:80-84` (≤1,850,000 bytes).
- **Why it matters:** the agent can't iterate against a score on its own. Every perf run re-derives its own stats.
- **Fix:** `scripts/workflow/bench.sh -n N -- CMD -> JSON {n, median_ms, p90_ms, stdev_ms, min_ms}`, plus `scripts/evals/run.sh [eval-dir...] -> JSON {eval, graders:[{name,pass,evidence}], score}`. Point perf.md step 1 and `write` at them.

### 5. Green-by-default checks and untested skill scripts

- **`scripts/ci/validate-skill.sh:246`:** `pytest … | grep -q "passed"` succeeds on "1 failed, 2 passed".
- **`cli/tests/skill_reference_resolution.rs:106-109`:** asserts that wrapper text `contains("host's skill metadata")`. It pins wording, so it can't catch a behavior regression.
- **`setup/settings.json:46`:** the Stop hook greps `$CLAUDE_LAST_MESSAGE`. If that variable is unset it is silently green (see E).
- **Untested scripts:** a grep of `scripts/ci` and `.github` finds CI tests only for `panel-merge.py`. Nothing tests `scan-staged.sh`, `group-staged.sh`, `gh-search.sh`, `lint-prompt.sh`, `session-digest.py` or `fetch.sh`, yet `git` SKILL.md:41-47 tells agents to trust their output as final.
- **Fix:** change :246 to `pytest "$TEST_DIR" -q --tb=no` and check its exit code. Add `scripts/ci/test-skill-scripts.sh` with one positive and one negative fixture per script, starting with `scan-staged.sh` (a staged fake secret must give exit 1). Wire it into `skills-ci.yml`.

## C. Proposed shared verification tool

`zverify`: a repo script, or a `zharness` subcommand only if `zharness` is allowed to grow past install/update/uninstall (AGENTS.md § Harness). Every command prints one JSON object and exits 0 for pass, 1 for fail, 2 for usage error.

```text
zverify proof   [-t S] -- CMD...                      # gap 1
zverify exercise --start CMD --ready CMD --drive CMD --expect RE [--fail CMD --expect-fail RE]
zverify bench   -n N [--warmup W] -- CMD              # gap 4
zverify risk    --base REF --head SHA                  # gap 3
zverify ci      --pr N                                 # babysit.md:9: failed jobs + log tails
zverify plan    <plan.md>                              # pre-lint the Validation/phase grammar the hook parses
```

```json
{"tool":"zverify","cmd":"exercise","ok":false,
 "source":{"head":"<sha>","dirty_hash":"<h>"},
 "checks":[{"name":"drive","cmd":"...","exit":0,"expect":"RE","matched":false,"tail":"..."}],
 "metrics":{"median_ms":null},
 "markdown":"## Exercised\n- `...` → ..."}
```

`source` lets the brief rule (work-fanout.md:45) and the patch-id check (ship.md:26) work from parsed fields. `markdown` removes hand formatting of `## Exercised` and the Validation entries.

## D. Quick wins vs. structural changes

**Quick wins (under 1 hour each):**

- Fix the `grep passed` check (validate-skill.sh:246).
- Add an Exercise command to `AGENTS.md`.
- Resolve the `git` SKILL.md:64 vs. host attribution conflict.
- Give `create-cli` output a `lane:` and `status: active` frontmatter, or have it write outside `.harness/plans/active/` (:115-127).
- Name `gh run view <id> --log-failed` in babysit.md:9.
- Replace the inline base-resolution shell in watzup.md:14-21 with a script that `git` reuses.
- Add a fixture test for `scan-staged.sh`.

**Structural changes:**

- Ship `record-check`/`plan-slice` (or `zverify`) to consumer repos.
- `risk-facts.sh` plus test fixtures.
- The exercise driver.
- An eval runner for `evals/`.
- Bench harness wired into perf.
- A mechanical stop-gate check (work-full.md:19 says it's prompt-level only).

**Codemods:** none found. Checked the playbooks, work-full.md:18 (which already says "a non-trivial run of similar edits … gets a rerunnable script") and the scripts directories. No repeated AST-shaped migrations are visible.

## E. Unknowns

- **Past transcripts:** about 30 session `.jsonl` files exist and were not digested, so there is no reinvention evidence from them (P2.2). Running `session-digest.py` on them would settle it.
- **`$CLAUDE_LAST_MESSAGE`:** not confirmed that Claude Code sets this variable for Stop hooks. `setup/settings.json:2` mentions `setup/hooks/` files that don't exist in the repo, while AGENTS.md still lists `setup/hooks/**` as an always-review path.
- **`evals/`:** unknown whether an external tool (e.g. `claude plugin eval`) runs these.
- **Unread areas:** `cli/src/*` and most of the hook body (lines 93–543) were only grepped. The claims about guards R1–R6 come from the hook's comment headers and `test-guards.sh`.
- **Unread reference sets:** the `create-skill`, `write`, `turbo-mono-platform` and `site/` references, so it is unknown whether those skills hide more prose mechanics.
