---
status: completed
lane: high-risk
---
# Playbooks move into skill references

## Goal

- outcome: six workflow skills own their procedures; zharness safely retires legacy playbook distribution. The binary continues install/update/uninstall of WORKFLOW, the AGENTS block and PROJECT scaffold; it neither installs skills nor runs the lifecycle.
- success_signal: the acceptance matrix below passes; an isolated consumer with independently installed skills executes bounded work and resumes durable work without legacy procedures; final source has no playbook projection directories; all four repository gates pass. Migration alone makes no model-quality or token-saving claim.
- actors: owner, contributor agents, consumer repositories and skill-capable hosts. Hosts without skills lose the procedure, as already accepted.
- authority: PR #133 owner decisions on 2026-10-12/13 and the owner's 2026-10-13 request to revise migration and prepare the follow-up plan after review. This request authorizes this pre-execution phase revision despite the usual phase-immutability rule. Original phases were all planned and Log/Validation empty; no execution history is reset. This planning turn does not authorize implementation, commit, push, merge, release or changes to real consumer installations.
- requirements:
  - R1: ADR 0015 records distribution, compatibility, ownership and recovery; amends ADR 0007; preserves ADRs 0008, 0013 and 0014. | acceptance: ADR/index/migration guide agree; doc links pass; independent review checks the acceptance matrix | source: owner and existing ADRs
  - R2: relocate twelve procedures into six skill reference directories with portable routing. | acceptance: mapping below, isolated reference-resolution test, six skill validations and final absence of both legacy projection directories | source: original R2
  - R3: preserve behavioral contracts during relocation. | acceptance: every original required predicate maps to a relocated assertion; only routing/path literals change mechanically with a reviewed mapping; no behavior assertion is removed to make tests green | source: original R3 and migration-only scope
  - R4: retire known legacy paths conservatively using recorded hashes and ownership; preserve edits, unknown files and original consumer payloads; update is retry-safe and uninstall handles both shapes. | acceptance: M01-M11 pass through installer seams, asserting bytes, notices and metadata | source: original R4 and ADR 0008
  - R5: switch WORKFLOW and remove legacy embedding/targets in one coherent p3 transition; preserve AGENTS/PROJECT installation semantics. | acceptance: p2 still ships the old managed set; p3 fresh install writes no playbooks and existing scaffold tests pass | source: corrected phase dependency
  - R6: verify the supported consumer path, including separately installed skills. | acceptance: M12-M14 and consumer smoke have traces, source/runtime identity, snapshots and real acceptance outputs | source: owner request for complete handoff
  - R7: record all required checks and a usable recovery route. | acceptance: four gates, independent high-risk/final review, source-versus-consumer rollback and next-plan instructions | source: repository workflow
- non-goals:
  - NG1: no plan schema, lane, guard grammar, task database, lifecycle CLI, model router or orchestration service change.
  - NG2: no semantic simplification, bounded-threshold change, tier change or new approval policy; preserve ADR 0014.
  - NG3: no fallback for hosts without skills; no implicit skills install or home-directory scan by zharness.
  - NG4: no site overhaul or rewriting historical plans/audits/evidence. Update live execution routes; immutable history gets narrowly reasoned link exceptions only.

### Source context and decisions

- Upstream: [PR #133](https://github.com/therealtinhtute/mono-harness/pull/133), head `156bc96b15715ddd8b43e69bbeaa4bcd0fff8c1a`, base `821c8a46c569b4d6405f6f5ca85229f5b27eb601`. Preserve its separate shallow-clone `ftmp2` fix.
- Earlier research used `c8a8429`; it predates ADR 0014. At this PR head, normal already means Goal + one main phase, no to-plan, and no duplicate gate before independent check full. Do not reintroduce a task list for normal work.
- Minimum sources: AGENTS, WORKFLOW, this plan, ADRs 0007/0008/0013/0014, selected stage, `cli/src/embedded.rs`, `cli/tests/projection_parity.rs`, affected `cli/src/installer/` code/tests.
- Current implementation: all_targets derives playbooks from embedded names; legacy ownership seeding visits supplied targets. Removing names before the retirement logic changes installer behavior and can lose the chance to seed legacy ownership. Uninstall can discard originals for retired targets unless they remain in its recovery inventory.
- The next initiative is `docs/plans/draft-lean-sdlc-workflow.md`, deliberately inactive. It owns semantic simplification and model evals.

### Procedure ownership and reference contract

| Owning skill | Files in its references directory |
|---|---|
| brainstorm | brainstorm.md, brainstorm-grill.md, brainstorm-lock.md |
| to-plan | to-plan.md |
| work | work.md, work-full.md |
| check | check.md, check-durable.md, check-validation.md, check-review.md |
| handoff | handoff.md |
| watzup | watzup.md |

- SKILL.md addresses its own `references/name.md`. Inside a reference file, a companion markdown link is sibling-relative, for example `work-full.md`; do not introduce references/references paths.
- Cross-skill transitions name the destination skill and mode, resolved through host skill metadata. Never assume the source checkout, a shared installation parent or `../../other-skill`. Missing required skill means a missing dependency, never permission to use a stale legacy playbook silently.
- Consumer data paths (AGENTS, PROJECT, plan, code, checks) resolve from the consumer root, not the installed skill directory.
- Document installing the six-stage dependency set with the existing skills distribution mechanism before upgrade. The binary does not detect/install skills; the supported-path prerequisite is verified in M12.
- Keep wrappers selective; do not load all twelve procedures. Bump changed skill versions.

### Retirement policy and acceptance matrix

Seed/load legacy ownership using both current and retired known targets before dropping active targets. Eligibility is an allowlisted old managed playbook path plus its recorded digest; never scan and delete arbitrary markdown. An exact digest match is necessary, not sufficient to discard saved original consumer content.

If the current projection matches the recorded digest and ownership proves a preexisting original, restore the saved original as part of retirement, following existing uninstall restoration semantics. If that payload/provenance is unavailable, keep the current file and recovery records with a notice. If the current file is edited, preserve it and its original backup; later uninstall must not overwrite those edits. Preserve metadata needed for unresolved restoration independently of active upstream targets. An empty directory can be removed; recursive directory deletion is forbidden. Do not reinterpret ADR 0013's directory-symlink policy.

| ID | Setup/action | Required result |
|---|---|---|
| M01 | Created-by-installer legacy file equals recorded digest; update | Remove managed copy, name removal, remove retired active base entry; unrelated bytes unchanged |
| M02 | File differs from recorded digest | Preserve exact edits with reason; remove from active targets; retain needed original/provenance data |
| M03 | Missing recorded digest/base or unknown ownership | Preserve bytes with unknown-provenance notice; do not infer ownership from matching today's upstream |
| M04 | Corrupt/unreadable base manifest | Fail before destructive writes; byte-identical files and metadata; no successful-retirement claim |
| M05 | Fresh install then update | No playbook directory created; existing AGENTS/PROJECT/WORKFLOW semantics retained |
| M06 | Repeat update after M01/M02/M03 | No extra deletion, content rewrite or stale active base entries; retained files stay retained |
| M07 | Uninstall fresh and upgraded shapes | Existing ownership protections hold; edited/unknown leftovers retained; original content not discarded |
| M08 | Unrelated file/subdirectory under legacy directory | Preserve it; remove directory only if empty |
| M09 | Matching projection with saved preexisting original; also missing original or malformed ownership | Restore proven saved original; otherwise keep and notice. Test legacy seeding without ownership.tsv and preservation of backups on edited files |
| M10 | Failure partway through retirement; retry | Nonzero and accurate partial result; metadata supports safe retry; no removal notice before success |
| M11 | Existing supported directory/file symlink fixture shapes | ADR 0013 behavior preserved; external target bytes never deleted/overwritten by new retirement logic; use existing uninstall restore-through-link precautions |
| M12 | Six skills installed/copied outside source tree; source playbooks unavailable | Local companions resolve, cross-stage routing uses host metadata, data paths use consumer root |
| M13 | Edited legacy copy retained; invoke canonical skill | Agent reads installed procedure, not retained old instructions; edited bytes unchanged |
| M14 | Host has no installed skills | Unsupported prerequisite is explicit; no auto-install/fallback or claim of verified skill execution |

Use existing Rust installer fixtures. Assert bytes and metadata, not only message text. Missing ownership and corrupt base are distinct: the existing ownership parser can skip malformed rows; conservative retention must still hold. Do not broadly replace that parser in this migration.

Metadata postconditions (assert update, repeated update and subsequent uninstall for each row):

| Disposition | Active base manifest/upstream blob | Ownership/original recovery records | Later uninstall |
|---|---|---|---|
| Proven installer-created, matching file, no saved original | Remove retired entry/blob after unlink succeeds | Remove that retired ownership row | No remaining managed file to remove |
| Proven preexisting, matching projection, valid saved original | Remove retired entry/blob only after restore and byte verification succeed | Remove that path's ownership row and original backup only after successful restoration | Restored consumer file is unmanaged and stays unchanged |
| Edited file, missing original, unknown/malformed ownership, or contradictory created-origin plus saved original | Retire active entry/blob after classifying and reporting keep | Preserve existing original payload and provenance; missing records remain missing, never manufacture proof | Keep file and recovery records; no blanket removal of originals directory while unresolved retired records remain |
| Operation fails before its disposition succeeds | Keep that path's previous base evidence for retry | Preserve its ownership/original records | No false successful retirement; retry can re-evaluate safely |

Only known retired keys are changed; never clear the whole ownership ledger or originals directory. Unresolved retired files are relinquished as active update targets but remain identifiable through the fixed legacy allowlist plus existing recovery records. Uninstall must not restore through edited content or discard its backup. For missing-base cases, classify known legacy paths without guessing origin. Implement metadata saves so a failure cannot erase the only proof before its file operation succeeds.

## Phases and Verification

- approach: ADR -> skill-owned procedures with frozen compatibility distribution -> atomic installer retirement/routing switch -> detached consumer proof. The temporary p2 copies remain until p3, so pausing after p2 is usable.
- rejected: embed removal before retirement; migration mixed with semantic tuning; a new skill installer in zharness.
- seams: embedded/contract/projection tests, installer fixtures, skill validation, doc links and observable host tool traces. A focused Rust installed-reference test uses the existing stack; no new runtime dependency.
- constraints: preserve behavioral predicates, unknown/edited/original bytes and recovery data; one active plan; independent high-risk judge; all four repository gates.
- recovery: record each pre-phase source SHA. Under this revised sequence, reverting the whole p3 range restores p2's retained compatibility distribution; reverting p2 restores the original layout. Revert dependent ranges in reverse order. Source rollback does not resurrect deleted consumer files: capture the complete consumer tree and `.zharness` metadata before upgrade; restore captured bytes offline. Never run an old fresh-overwriting updater on retained edits as a recovery shortcut.

### Check commands

All commands start at repository root. Labels below are shorthand in task definitions only; Validation must contain real replayable commands. Record unavailable toolchain/runtime as blocked/unverified, not passed.

| Label | Command |
|---|---|
| E | `cd cli && cargo test --lib embedded` |
| I | `cd cli && cargo test --lib installer` |
| P | `cd cli && cargo test --test projection_parity` |
| R | `cd cli && cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test` |
| S | `cd cli && cargo build --release --target x86_64-unknown-linux-musl && test "$(wc -c < target/x86_64-unknown-linux-musl/release/zharness)" -le 1850000` |
| G | `bash scripts/test-guards.sh` |
| D | `bash scripts/verify-doc-links.sh` |
| V | `bash -c 'for stage in brainstorm to-plan work check handoff watzup; do bash scripts/validate-skill.sh "skills/workflow/$stage/SKILL.md" || exit; done'` |

V writes local validation-report JSON; exclude generated reports from the implementation diff. D excludes plans and proves neither plan completeness nor agent behavior. R/S/G/D are the four final gates; S is not implicitly covered by cargo test.

- phase_slug: `p1-adr`
  status: done
  - goal: R1, R7 | depends_on: none
  - surfaces: ADR 0015, ADR 0007 Status, decision index, migration guide | avoided: code, guards, host configuration
  - escalate_when: ownership/symlink policy, plan grammar or accepted unsupported-host scope must change
  - wave 1:
    - T1 write decision and consumer instructions, including compatibility table, original recovery, skills prerequisite and rollback — output: ADR 0015 and linked migration guidance — check: D and M01-M14 review — stop_if: authority or preservation semantics are ambiguous
  - phase check: D; independent requirement-to-case review

- phase_slug: `p2-skills`
  status: done
  - goal: R2, R3, R5, R6 | depends_on: p1-adr
  - surfaces: six stage skills, embedded contract tests, focused `cli/tests/skill_reference_resolution.rs` | avoided: installer behavior, deletion of frozen projections, semantic changes
  - escalate_when: a non-path behavioral contract or installed managed set would change
  - wave 1:
    - T2 redirect contract reads to skill references and add M12 resolution tests — output: expected missing-reference failures, complete old/new predicate map — check: E and `cd cli && cargo test --test skill_reference_resolution` — stop_if: red is an unrelated build/environment failure
  - wave 2:
    - T3 copy procedures to owning skills, change routing/paths only, update wrapper versions; retain old embedded and docs projections byte-identical for compatibility — output: canonical skill procedures and frozen distribution — check: E, V and reference-resolution test — stop_if: a behavioral rule changes
  - wave 3:
    - T4 verify old managed-path inventory and fresh-install/update behavior unchanged — output: bridge compatibility proof — check: I, P, R and D — stop_if: consumer distribution changes before retirement exists
  - phase check: R, V, D; independent predicate-map and compatibility review

- phase_slug: `p3-installer`
  status: done
  - goal: R1, R2, R3, R4, R5, R7 | depends_on: p2-skills
  - surfaces: installer modules/tests, embedded targets, projection tests, both old playbook directories, WORKFLOW source/projection, live AGENTS/README/migration/routing docs | avoided: guard grammar, workflow semantics, site, historical rewrites
  - escalate_when: retirement requires deleting unproven/edited bytes or losing saved originals
  - wave 1:
    - T5 add M01-M11 tests, including restoration and ownership seeding before target removal — output: expected red retirement cases — check: I — stop_if: tests cannot assert real bytes/metadata
  - wave 2:
    - T6 implement one indivisible distribution transition: retirement before base replacement, removal of shipping targets/embedding/both old directories, switch both WORKFLOW copies and live routes to skills, preserve recovery inventory, and remove only obsolete playbook projection/count assertions — output: coherent new distribution; no intermediate commit or handoff routes to deleted files — check: I, P, E, R, D and V — stop_if: unrelated managed files/recovery payloads change or any active route breaks
  - wave 3:
    - T7 audit live routes and repository identity wording, preserving PROJECT installer semantics; classify every remaining old-path reference by live/history/example — output: one procedure authority and a reviewed residual-reference inventory — check: D, V and `rg -n 'docs/playbooks|embedded/playbooks' AGENTS.md README.md docs cli skills rules setup` with each remaining hit classified — stop_if: broad ignores hide live broken routes
  - phase check: R, S, G, D, V; independent M01-M11 and rollback review

- phase_slug: `p4-dry-run`
  status: done
  - goal: R2, R4, R6, R7 | depends_on: p3-installer
  - surfaces: disposable consumer, isolated host configuration, redacted evidence and stage-owned plan sections | avoided: real consumers, global skills/config, remote publication
  - escalate_when: edited/original bytes disappear, source checkout is required at runtime, or necessary runtime evidence is unavailable
  - wave 1:
    - T8 prepare two consumers using a pinned previous released binary: first a fresh installation with a later edited playbook and unrelated content; second with a consumer-owned playbook present before install so its original is captured. Record binary version/hash/source, full before-state including originals/ownership, then independently install the six candidate skills — output: repeatable fixtures and installed-path inventory — check: snapshots/hashes, proven saved original and M12 — stop_if: old release identity, original capture or runtime isolation is unknown
  - wave 2:
    - T9 update twice, then uninstall in a separate restored fixture — output: M01/M02/M06/M07/M08/M09/M13 observations — check: compare snapshots to matrix and rerun I — stop_if: retained bytes or restoration data are lost
    - T10 in a separate fixture run bounded behavior work with an existing test; run a normal durable task interrupted after one verified requirement, resume in a fresh session through watzup/work/check/handoff — output: trace proves installed-skill reads, acceptance and no duplicate work — check: M12-M14 observations and actual task commands — stop_if: unavailable runtime, missing trace or unsupported completion claim
  - wave 3:
    - T11 run R/S/G/D and independent final check full; retain source/artifact hashes; close through handoff — output: verified migration with no performance claim — check: all four exits and independent R1-R7 review — stop_if: any required proof is unavailable or failing
  - phase check: R, S, G, D plus consumer observations; attach runtime artifact paths/hashes rather than pretending host-dependent commands are portable replay proofs

### Agent handoff

Check HEAD/diff, this plan's Log/Current State and active-plan count. Reconcile source drift before editing. Resolve stage instructions using the checkout's current authority: playbooks before p3, skills after p3. Execute one phase at a time using the high-risk judge boundary. No automatic commit/push/PR/merge/release is authorized by this plan.

After final approval and closing handoff archive this plan, the authorized follow-up can move `docs/plans/draft-lean-sdlc-workflow.md` to `docs/plans/active/lean-sdlc-workflow.md`, update frontmatter to active and record actual migration completion SHA as its B baseline. Do not maintain two live copies. No future eval is claimed complete by migration checks.

## Log

- 2026-10-13T07:23:53Z — start phase `p1-adr`, T1. Owner execution request authorizes implementation; the Goal authority sentence about the planning turn remains historical. Pre-phase source: `156bc96b15715ddd8b43e69bbeaa4bcd0fff8c1a`; both supplied plan changes retained, no other source drift. Baseline `bash scripts/verify-doc-links.sh`: exit 0, 0 findings (4 known-removed claims).

- 2026-10-13T07:29:09Z — done phase `p1-adr`, T1: ADR/index/consumer guide authored; D exit 0; independent p1 gate APPROVED. No installer/runtime behavior claimed.

- 2026-10-13T07:30:25Z — start phase `p2-skills`, T2. Pre-phase ancestor is `156bc96b15715ddd8b43e69bbeaa4bcd0fff8c1a`, NOT a commit representing p1 changes. Exact dirty-source snapshot: `/tmp/mono-harness-migration-kya1gqcc/p2-prephase-source.tar.gz`, SHA256 `7aefa442cb430b416d20ad590f9680135baabb6d2dbbeb7007ff30729b304ea4`, with manifest and binary diff alongside. Commit-based rollback identity remains pending owner approval; no commit is made.

- 2026-10-13T07:31:26Z — done phase `p2-skills`, T2: `cd cli && cargo test --lib embedded` exit 101 (6 pass, only relocated-contract read fails on missing brainstorm reference); `cd cli && cargo test --test skill_reference_resolution` exit 101 (both fail on missing copied reference). Expected missing-reference red, no environment/build failure.

- 2026-10-13T07:32:30Z — done phase `p2-skills`, T3: 12 references copied with only same-skill path→sibling-link replacements; six wrapper versions bumped, host-metadata/consumer-root routing and explicit missing-dependency handling implement the accepted routing contract. E: 7/7; installed-resolution tests: 2/2; V: six pass with 8 advisory thin-wrapper warnings each. Full original/new predicate map: `/tmp/mono-harness-migration-kya1gqcc/p2-predicate-map.json` (125 required, 54 local forbidden, 44 global forbidden fragments unchanged; no predicates removed). An initial mapping-generator assertion failed because its regex stopped at markdown brackets; corrected parser verifies all 179 per-contract predicates and exact transformed bytes for all 12 references; this was an evidence-script issue, not a product/test change.
- 2026-10-13T07:32:30Z — done phase `p2-skills`, T4: I 41/41, P 2/2, R exit 0 (fmt, clippy, 49 unit + 4 integration tests), D exit 0. Old embedded/docs playbooks, installer source and projection tests remain byte-identical to HEAD (`git diff --exit-code HEAD -- cli/docs/embedded/playbooks docs/playbooks cli/src/installer cli/tests/projection_parity.rs`, exit 0). Reference-resolution proof is packaging only; real host execution remains p4. Independent gate next.

- 2026-10-13T07:41:06Z — blocked phase `p2-skills` closure: independent packaging verdict APPROVE_WITH_REQUESTS requires owner checkpoint-commit approval or explicit snapshot-based recovery exception before p3. Concrete complete diff prepared at `/tmp/mono-harness-migration-kya1gqcc/p1-p2-review.patch`; no commit/push/PR change.
- 2026-10-13T07:41:06Z — decision: musl preflight originally failed exit 101 (E0463 missing target). Copied Rust 1.99.0 into `/tmp/mono-harness-migration-kya1gqcc/isolated-rustup`, installed target there only. `cd cli && env RUSTUP_HOME=/tmp/mono-harness-migration-kya1gqcc/isolated-rustup cargo build --release --target x86_64-unknown-linux-musl && test "$(wc -c < target/x86_64-unknown-linux-musl/release/zharness)" -le 1850000` exit 0: 811728 bytes, SHA256 c95e065963e333cca593fa8a5ffbcab8b4430d030c70ad16a3a6968b27334b92. Global target inventory still only GNU. `bash scripts/test-guards.sh` exit 0: 68 passed, 0 failed, legacy bash 3.x fixture skipped as unavailable. These are p2-source preflights, not final p3/p4 proof. Codex CLI 0.162.1 login status reports ChatGPT authentication; isolated skill loading and runtime behavior have not been tested.

- 2026-10-13T07:49:28Z — p2-skills — decision — owner directs "handoff p2 → work full phase p3-installer" after checkpoint request. Proceed without commit using temporary snapshot recovery; this does not grant commit/push or replace required future baseline B with HEAD. Exact compatibility-bridge source captured at `/tmp/mono-harness-migration-kya1gqcc/p3-prephase-source.tar.gz`, SHA256 `736718d5e4c5ce72408241f7630e6277a079004b04798e8985c3ee6f62700fad`, with `p3-prephase-manifest.json`; extraction verified all 667 file hashes. Commit-range rollback remains unavailable; restore this source snapshot offline instead. Independent reviewer to confirm closure request satisfied under owner-directed progression.

- 2026-10-13T07:51:36Z — p2-skills — decision — independent reviewer p1_judge addendum APPROVED: archive hash and all 667 manifest entries verified; live source differs only by appended owner decision; frozen compatibility surfaces still match HEAD. Prior p2 recovery request is resolved under owner-directed temporary snapshot exception. No commit authority; R7 remains partial and future B must be a real approved completion commit.

- 2026-10-13T07:51:37Z — p3-installer — start — p2 closed by handoff after independent addendum; temporary snapshot source identity is 736718d5e4c5ce72408241f7630e6277a079004b04798e8985c3ee6f62700fad (not a commit); HEAD remains ancestor 156bc96b15715ddd8b43e69bbeaa4bcd0fff8c1a. Baseline installer suite follows before T5 changes.

- 2026-10-13T07:56:41Z — p3-installer/T5 — done — baseline `cd cli && cargo test --lib installer`: exit 0, 41/41 before edits. Added 14 M01–M11 fixtures at `cli/src/installer/retirement_tests.rs`; planned seam I now exit 101, 42 pass and 13 expected retirement failures. M04 already passes. Red shows old fresh-overwrite/no-retirement and blanket recovery cleanup, not a build/environment failure. M06 repeat-update checks are integrated into disposition cases; source identity and legacy seed use recorded hashes, not current upstream equality.

- 2026-10-13T08:29:06Z — p3-installer/T6 — decision — pre-integration review found cleanup failure could lose ownership and already-original retry could bypass missing-base keep. Fixed with rollback of prior base/ledger/removed backups on returned cleanup failures, explicit secondary-recovery errors, and required recorded base for already-original cleanup. Independent preliminary review also found failed active WORKFLOW restoration treated as success; typed uninstall disposition now propagates read/restore/delete errors before recovery cleanup. Added real failure/retry fixtures and test-only backup fault seams; no acceptance relaxed, no persisted runtime/state system added.

- 2026-10-13T08:29:06Z — p3-installer/T6 — done — installer writer transferred ownership before root integrated embedding/routing. Fixed legacy inventory is independent of active targets; both twelve-file projection directories removed; binary embeds only AGENTS/WORKFLOW/template; WORKFLOW copies route installed skills and preserve stage tiers/semantics. I exit 0: 67/67 (26 retirement fixtures; original T5 predicates retained); P exit 0: 3/3 including drift and missing-projection failures; E exit 0: 7/7, original procedure contract predicates unchanged. R exit 0: fmt/clippy/full tests (75 unit + 3 projection + 2 installed-reference); V exit 0: all six skills, 8 advisory warnings each. Runtime proof remains p4.

- 2026-10-13T08:29:06Z — p3-installer/T7 — done — live source/routing docs and CLI CI skill path filters updated; PROJECT installer semantics unchanged, only its live procedure citation retargeted. First D exit 1: deleted historical citations plus installed-relative WORKFLOW filenames misread as repo links. Corrected router table to explicitly name filenames inside the installed references directory; added six exact historical .claimignore entries, no directory-wide exception. D now exit 0, 0 findings and 4 known-removed claims. Required rg inventory classified all 1022 hits across 187 files: 999 historical/plan records, 21 recovery fixtures/inventory/absence assertions, one compatibility table and one historical git cleanup example. Inventory: /tmp/mono-harness-migration-kya1gqcc/p3-residual-route-classification.json, SHA256 651908933c24a3b9a3e83d21a49e3beb03b1c9aac5113916ec48b5c65d71f727. No active execution route uses retired files; incident rows and old evidence remain unchanged.

- 2026-10-13T08:29:06Z — p3-installer — decision — temporary snapshot recovery rehearsed on disposable source: mutate installer, delete projection, add candidate-only file; quarantine candidate tree, extract clean offline snapshot and verify exact inventory/all 667 hashes. Artifact /tmp/mono-harness-migration-kya1gqcc/p3-source-recovery-rehearsal.json. This proves snapshot source recovery only, not consumer rollback or commit-range recovery. G exit 0: 68 pass/0 fail; legacy Bash 3 fixture unavailable/skipped. S and independent p3 gate follow. No commit/push/global changes.

- 2026-10-13T08:36:32Z — p3-installer — blocked — independent gate REQUEST_CHANGES: initial edited file equal to .orig is mistaken for interrupted restore, causing M02 recovery metadata loss; failure_class: BAD_OUTPUT. Gates are green but R4 is not met. Keep phase in-progress and add red regression; durable path/digest-bound installer restoration intent is an implementation detail under R4/M10/ADR 0008, not workflow state. CLI help retarget also requested.

- 2026-10-13T08:36:32Z — p3-installer — decision — failure-ledger incident publication deferred until an approved source commit identifies this new untracked retirement implementation. docs/evals/failures.md requires immutable commit+path citations and forbids an active-plan-only source; ancestor HEAD does not contain retirement.rs. Preserve finding/repro/source hash in this append-only Validation rather than inventing a commit or silently rewriting ledger admissibility. No commit authority granted.

- 2026-10-13T08:55:05Z — p3-installer/T6 — done — independent M02 finding reproduced red at actual installer seam (exit 101, initial original equality wrongly deleted backup). Added narrow exclusive-create restoration intent bound to version/path/recorded projection digest/original digest/preexisting origin, persisted before restore. Retry requires valid intent and still-present recorded base; invalid/stale/linked intent or later edits stay retained. Intent unlinks last; returned cleanup faults roll back base/ledger/originals and keep intent. New tests cover initial equality through update twice/uninstall, seven stale-field cases, invalid/extra fields, intent write/restore/cleanup faults, parent/leaf links, missing base and later edits. All prior 67 installer tests retained; I now 72/72. On Unix intent file and directories are synced; existing managed writer is not a complete power-loss transaction, so no such guarantee is claimed.

- 2026-10-13T08:55:05Z — p3-installer/T7 — done — generated CLI help now describes WORKFLOW/AGENTS refresh and recorded legacy retirement (observed via cargo run --quiet --manifest-path cli/Cargo.toml -- --help). Consumer guide/architecture/ADR explain intent separately from active base, origin and original payload. R exit 0: fmt/clippy, 80 unit + 3 projection + 2 resolution; S exit 0: 815824 bytes, SHA256 41c055d9ce594dcc59aee0ccf8da3ccce286fd063beb3dcfd0ba5af487a5d572; G exit 0: 68 pass/0 fail with unavailable Bash3 skip; D exit 0; V exit 0 all six/8 advisories each. Revised residual inventory still 1022 hits, same classifications; /tmp/mono-harness-migration-kya1gqcc/p3-revised-residual-route-classification.json SHA256 17ddf5af86aae5ca4775fd7f7e6666aeeda74977073611ff60fd50523a354dfc. Independent recheck follows; earlier REQUEST_CHANGES remains history.

- 2026-10-13T08:59:28Z — p3-installer — done — closing handoff after independent APPROVED recheck; all prior phases done and no blocking p3 request. Snapshot recovery exception remains disclosed. No commit/push/PR/global change.

- 2026-10-13T08:59:28Z — p4-dry-run/T8 — start — execute detached consumers and isolated native host; pre-phase code is the accepted dirty p3 candidate, not ancestor HEAD. Candidate musl binary SHA256 41c055d9ce594dcc59aee0ccf8da3ccce286fd063beb3dcfd0ba5af487a5d572. Exact pre-phase snapshot/hash follows. Released predecessor identified read-only: cli/v0.27.0 annotated tag a0b4e756f9649afee21c281813c88149da9e0ef4 resolves commit c5795b5e8d54fa890446c8745c39545ecf83e96f; release assets still require checksum/binary verification. Host preflight: Codex CLI 0.162.1 authenticated status previously observed; bwrap read-only namespace probe exit0. This is not installed-skill/runtime acceptance.

- 2026-10-13T09:05:57Z — p4-dry-run/T8 — done — p4 pre-phase source snapshot has 645 files, SHA256 e184ca2bd5c29f1711c059f50e715ea8b4a358b8b50d0557825b9c20281a6ea6 (accepted dirty source, not commit). Downloaded pinned cli/v0.27.0 release archive and verified publisher checksum: 167171bc262abcd8d323cc21a452839554fe62b3f07c9773c18a9104036a53e1; extracted binary version 0.27.0, SHA256 6249bde36ad42136b521da5af6b0ca214c66020175ad48691afe9fb1564ce785, release source c5795b5e8d54fa890446c8745c39545ecf83e96f. Two detached consumers include full before-install/after-install/before-upgrade snapshots and proven preexisting original capture. Six skills copied into six distinct installed parents outside source with native discovery links. Isolated Codex 0.162.1 login status reports ChatGPT auth; native skills/list exposes exactly these six custom workflow skills at their separate installed paths (plus host builtins). bwrap hides source checkout, global Codex/agents roots and other /tmp artifacts; writable persistent scope is p4 fixture only. Private auth copy excluded from artifacts and scheduled for removal. Native loader proof is not yet agent procedure-use proof; M12–14 execution belongs to T10. Artifacts: /tmp/mono-harness-migration-kya1gqcc/p4/identities.json, installed-skills.json, native-loader-result.json, host-isolation-command.json and snapshots/.

- 2026-10-13T09:05:57Z — p4-dry-run/T9 — done — python3 /tmp/mono-harness-migration-kya1gqcc/p4/exercise-consumers.py exit0: both release-created consumers update twice, then candidate uninstall in separate restored upgraded and old-shape fixtures. Edited bytes/unrelated nested content survive; proven original is restored with ownership/backup relinquished; all retired active base entries removed; PROJECT bytes unchanged. Each offline consumer rollback restores exact full before-upgrade inventory/hashes. Observations /tmp/mono-harness-migration-kya1gqcc/p4/consumer-observations.json and per-command logs; source seam cargo test --manifest-path cli/Cargo.toml --lib installer exit0, 72/72. No real consumer/global/source commit changed.

- 2026-10-13T09:10:19Z — p4-dry-run/T10 — blocked — first actual bounded native-host trial ended before tools: copied Codex binary could not locate its bundled codex-code-mode-host sibling. Host exit0 is NOT acceptance; trace explicitly reports unavailable execution host, no reference read/edit/test. failure_class: WRONG_TOOL. Preserve trial /tmp/mono-harness-migration-kya1gqcc/p4/logs/bounded.jsonl and bounded-result.json (actual usage recorded, monetary cost unavailable). Resolve by copying the existing installed native bundle helper into the isolated fixture, with hashes; no global runtime/control-plane installation, no simulated evidence.

- 2026-10-13T09:15:53Z — p4-dry-run/T10 — blocked — second retained trial bounded-runtime-ready resolved missing bundle helper but both actual unified-exec attempts fail Permission denied (os error 13), exit -1. Host exit0 is not acceptance; no procedure read/edit/test succeeded. Existing helper copied and hashed in native-bundle-hashes.json; no global change. Preserve logs/bounded-runtime-ready.jsonl, .stderr and -result.json under /tmp/mono-harness-migration-kya1gqcc/p4. Diagnose native tool spawning offline before further model calls; T10 and final migration approval remain blocked.

- 2026-10-13T09:17:47Z — p4-dry-run/T10 — recovery — offline native command/exec reproduced spawn Permission denied; strace identifies open(/dev/null) EACCES before exec. Minimal device probe red exit1 under original namespace, green exit0 with bwrap --dev /dev. Updated disposable host-isolation-command.json only to private minimal /dev; same native command/exec now exit0 stdout native-exec-ok. Evidence logs/exec-offline-red-detail.*, exec-offline-green.* and preserved host-isolation-command-before-dev.json. Missing temporary-home aliases were not the cause. Both failed model trials retained; real bounded/durable acceptance still pending.

- 2026-10-13T09:22:06Z — p4-dry-run/T10 — decision — bounded-exec-fixed actual native session exit0: installed work/SKILL.md and references/work.md read via native metadata, existing two tests pass, full before/after hashes differ only at labels.py; retained legacy hash remains 63b521f104884c5376fa6096ad3e25c5302779063114d1d4e02ba1cb81d9c6d5. Initial python alias unavailable was corrected to python3 by the agent, retained in trace. Durable session was actually interrupted by SIGINT (exit -2) after observed R1 test pass plus exactly one structured R1 done Log entry; snapshot confirms R2 still original and phase/Current State in-progress. Fresh-session watzup/work resume underway. Host turn_context records gpt-6.1-sol, effort unspecified/null; monetary cost unavailable. Earlier recovery-labelled Log entry is a fixture setup observation, not a task-status transition; task completion remains unclaimed until full T10 evidence.

- 2026-10-13T09:28:26Z — p4-dry-run/T10 — blocked — runtime artifact audit found two classifier assumptions requiring correction, before any further edit. Initial verifier rejected independent reviewer cat of retained legacy consumer bytes, although canonical check references were loaded first and legacy content was reviewed for scope, not routed as procedure. Revised verifier then found missing-skills fixture .git/index byte change after read-only git status; all other byte hashes unchanged. failure_class: BAD_OUTPUT (artifact verifier assumptions). Preserve verify-runtime-initial.py. Verify exact index entries/flags against restored pre-task fixture before classifying stat-cache refresh; do not claim byte-identical .git/index or missing M14 acceptance. Runtime traces retained, no source behavior edited.

- 2026-10-13T09:29:22Z — p4-dry-run/T10 — done — all runtime acceptance artifacts present; python3 /tmp/mono-harness-migration-kya1gqcc/p4/verify-runtime.py exit0. Six distinct fresh native sessions prove bounded work, actual durable interruption after verified R1, watzup/work resume completing R2 without repeated R1 implementation/Log, separate independent full approval, and uncommitted filesystem closing handoff preserving history. Installed canonical primary/companion reads captured, consumer-root data used, source/global workflow dirs masked. Missing-skills session explicitly stops dependency, no auto-install/fallback/source changes; only git-index cache bytes changed, exact staged entries/modes/OIDs/flags and empty staged diff unchanged (missing-skills-index-observation.json). Reviewer inspected retained legacy bytes for scope after canonical check loading, not as instructions; edited legacy content unchanged in all tasks. Full snapshots and all two blocked trials retained. Bounded red replay against exact pre-task snapshot exit1 and final green exit0 recorded as post-trial reconstruction, never historical agent red; durable actual red/green exists in raw trace. runtime-observations.json SHA256 0f39d7b0a9d7f8896b3726a68cb6bd219c22fad8d1e74c449c46c8bfea0d82cd; Codex0.162.1 model gpt-6.1-sol, effort unspecified, cost unavailable. No migration-efficiency claim.

- 2026-10-13T09:29:22Z — p4-dry-run/T11 — start — run final R/S/G/D on integrated source, then independent full review; source unchanged from accepted p3 except append-only plan state. Actual completion commit remains owner-approval gate before future B.

- 2026-10-13T09:38:10Z — p4-dry-run/T11 — done — root final R/S/G/D and diff all exit0; independent final full APPROVED at 2026-10-13T09:35:42Z, R1–R7 and success_signal met. Exact 645-file source bridge differs from approved p3-revised manifest only in this plan's progression. All snapshots/hash inventories, source offline667 and consumer offline38+38 recovery independently reverified. Redacted evidence bundle /tmp/mono-harness-migration-kya1gqcc/p4-redacted-evidence.tar.gz SHA256 1f11b0d0e71547b285040fb0a10bab7d1bf9cbddcf40b352c2f706c6cdb286c9; whitelist manifest SHA256 488b0b8396403cbc288459c1c7f910d62e2bcae84bab29d40dbc84d82a3579fb. No performance claim.

- 2026-10-13T09:38:10Z — p4-dry-run — decision — independent review encountered transient model capacity after green gate reruns, then resumed from verified evidence and delivered final approval; not replaced with self-review. Reviewer initial V call used directories and failed, corrected to actual SKILL.md paths and all six passed. Historical failures remain visible. No source edit or product-test weakening.

- 2026-10-13T09:39:40Z — p4-dry-run — decision — absorb: adr docs/decisions/0015-skill-owned-procedures-and-safe-retirement.md; independent full APPROVED closes migration with all phases done. Preserve all Log/Validation under owner append-only override. Filesystem move only, no staging/commit. Retarget ADR plan citation and refresh its implementation-verification status; rerun affected doc links/diff. Native redacted evidence and source/consumer recovery remain recorded above. Deferred incident publication awaits an approved immutable source identity. Future draft remains unmoved/inactive until actual completion commit B is approved; no fabricated baseline.

- 2026-10-13T09:58:59Z — p4-dry-run — decision — owner authorized commit/push/PR delivery. Actual accepted migration completion source is da9fed6a09e34d20f1e586577cf936d74905b7bb; this is the real future baseline B, not an inferred dirty HEAD. Deferred retirement incident now has its immutable citation. Initial pre-commit replay exposed inherited Git-local environment in guard fixtures, rejected commit and changed caller metadata; all 645 source hashes remained intact, recorded branch/master refs and metadata were recovered. Invocation-scoped forwarding of existing real hooks with Git-local variables cleared passed every proof and committed migration; no guard was disabled and no global/permanent hook setting changed. Fixture-runner isolation remains an explicit uncovered follow-up in failures.md. Future plan remains inactive during this delivery.

## Validation

- 2026-10-13T07:29:09Z — phase `p1-adr` — verdict: APPROVED — mode: gate
  - `bash scripts/verify-doc-links.sh` — exit 0; 0 findings, 4 known-removed claims; independently rerun.
  - `git diff --check` — exit 0, no output; independently rerun.
  - scope: on target — ADR 0015, ADR 0007 Status, index and consumer migration guide; M01–M14 independently aligned.
  - requirements: R1 met (decision/guide/matrix agree) | R7 partial (→ p3-installer/p4-dry-run: installer, four gates and runtime proof)
  - rollback_point: 156bc96b15715ddd8b43e69bbeaa4bcd0fff8c1a (pre-p1 source; supplied plan edits must be retained)
  - requests: none blocking; retarget ADR 0015 active-plan citation at archive.
  - not_independently_verified: installer/runtime and remaining gates, deferred to later phases
  - judge: independent
  - judge_model: GPT-6/Codex; exact deployment identifier unavailable
  - enforcement: local-only
  - proof_gaps: independent identity is testimony; deferred installer/runtime proof is not p1 completion evidence

- 2026-10-13T07:38:06Z — phase `p2-skills` — verdict: APPROVE_WITH_REQUESTS — mode: gate
  - `cd cli && cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test` — exit 0; 49 unit, 2 projection and 2 installed-resolution tests; independently rerun.
  - `cd cli && cargo test --test skill_reference_resolution` — exit 0; 2/2; independently rerun.
  - `bash -c 'for stage in brainstorm to-plan work check handoff watzup; do bash scripts/validate-skill.sh "skills/workflow/$stage/SKILL.md" || exit; done'` — exit 0; all six pass with 8 advisory warnings each; independently rerun.
  - `bash scripts/verify-doc-links.sh` — exit 0; 0 findings, 4 known-removed claims; independently rerun.
  - `git diff --check` — exit 0; independently rerun.
  - scope: on target — all predicates preserved, copies mechanically equal, frozen compatibility distribution independently confirmed.
  - requirements: R2 partial (→ p3-installer/p4-dry-run) | R3 met (179 local predicates mapped; global fragments unchanged) | R5 partial (→ p3-installer: bridge verified, final transition pending) | R6 partial (→ p4-dry-run: packaging only)
  - rollback_point: unavailable as pre-p2 commit; ancestor 156bc96b15715ddd8b43e69bbeaa4bcd0fff8c1a excludes p1; exact snapshot/hash recorded in Log, not substituted for a commit
  - requests: obtain owner-approved checkpoint commit or explicit snapshot-recovery exception before p3
  - not_independently_verified: host execution and commit-based recovery remain unverified
  - judge: independent
  - judge_model: GPT-6/Codex; exact deployment identifier unavailable
  - enforcement: local-only
  - proof_gaps: commit-based rollback identity pending owner decision; actual host execution deferred to p4

- 2026-10-13T08:36:32Z — phase `p3-installer` — verdict: REQUEST_CHANGES — mode: gate
  - `cd cli && cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test` — exit 0; 75 unit + 3 projection + 2 resolution; independently rerun.
  - `cd cli && env RUSTUP_HOME=/tmp/mono-harness-migration-kya1gqcc/isolated-rustup cargo build --release --target x86_64-unknown-linux-musl && test "$(wc -c < target/x86_64-unknown-linux-musl/release/zharness)" -le 1850000` — exit 0; 803536 bytes; SHA256 2e811bd5021f4f22b0ed9b7631a4fa585a7d70cd9e0884a1551009f54e17d61c; independently rerun.
  - `bash scripts/test-guards.sh` — exit 0; 68 pass, 0 fail; Bash 3 unavailable/skipped; independently rerun.
  - `bash scripts/verify-doc-links.sh` — exit 0; 0 findings, 4 known-removed claims; independently rerun.
  - `bash -c 'for stage in brainstorm to-plan work check handoff watzup; do bash scripts/validate-skill.sh "skills/workflow/$stage/SKILL.md" || exit; done'` — exit 0; six pass, eight advisories each; independently rerun.
  - `git diff --check` — exit 0; independently rerun.
  - scope: on target; 179 local + 44 global predicates independently preserved; snapshot rehearsal/all 667 files and residual classification/all 1022 hits independently verified.
  - requirements: R1 met for p3 | R2 partial (→ p4-dry-run: installed-agent execution) | R3 met | R4 not met | R5 met | R7 partial (→ p4-dry-run)
  - rollback_point: owner-directed exact source snapshot 736718d5e4c5ce72408241f7630e6277a079004b04798e8985c3ee6f62700fad; no commit represents dirty implementation; source-only offline restore rehearsed, consumer rollback unverified
  - requests: distinguish genuine interrupted restore from initial edited local==original; preserve M02 recovery without valid durable restore intent; retain existing retry acceptance. Minor: retarget CLI update help that still claims playbook refresh.
  - evidence: independent real-binary repro /tmp/mono-p3-judge-equality-tsrrj58w; update exit 0 wrongly removes original/ownership when local differs from base but equals original, without path disposition notice.
  - not_independently_verified: installed-agent behavior, consumer rollback and final full check deferred p4
  - judge: independent
  - judge_model: GPT-6/Codex; exact deployment identifier unavailable
  - enforcement: local-only
  - proof_gaps: R4 fixture coverage missed initial equality vs proven interrupted restoration; four green gates alone did not establish matrix acceptance

- 2026-10-13T08:59:01Z — phase `p3-installer` — verdict: APPROVED — mode: gate
  - `cd cli && cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test` — exit 0; 80 unit + 3 projection + 2 resolution; independently rerun.
  - `cd cli && env RUSTUP_HOME=/tmp/mono-harness-migration-kya1gqcc/isolated-rustup cargo build --release --target x86_64-unknown-linux-musl && test "$(wc -c < target/x86_64-unknown-linux-musl/release/zharness)" -le 1850000` — exit 0; 815824 bytes; SHA256 41c055d9ce594dcc59aee0ccf8da3ccce286fd063beb3dcfd0ba5af487a5d572; independently rerun.
  - `bash scripts/test-guards.sh` — exit 0; 68 pass/0 fail, unavailable Bash3 skip; independently rerun.
  - `bash scripts/verify-doc-links.sh` — exit 0; zero findings/four known-removed claims; independently rerun.
  - `bash -c 'for stage in brainstorm to-plan work check handoff watzup; do bash scripts/validate-skill.sh "skills/workflow/$stage/SKILL.md" || exit; done'` — exit 0; six pass/eight advisories each; independently rerun.
  - `git diff --check` — exit 0; independently rerun.
  - scope: on target; previous requests resolved. Real candidate-binary repro /tmp/mono-p3-judge-equality-fixed-fp63ywd6 preserves initial original-equality bytes, backup and ownership through two updates/uninstall with KEPT notices. Intent binding/order/invalid preservation/cleanup-last independently reviewed; original retry assertions retained. All 179 local + 44 global predicates, 1022-hit residual inventory, unchanged future draft and 667-file disposable snapshot recovery reverified.
  - requirements: R1 met for p3 | R2 partial (→ p4-dry-run: installed-agent behavior) | R3 met | R4 met | R5 met | R7 partial (→ p4-dry-run: consumer/final full evidence)
  - rollback_point: owner-authorized source snapshot 736718d5e4c5ce72408241f7630e6277a079004b04798e8985c3ee6f62700fad; source-only recovery rehearsed; no commit identifies dirty changes
  - requests: none blocking p3; publish deferred incident after approved source commit and retarget ADR plan citation at archive
  - not_independently_verified: consumer rollback, installed-agent execution, commit-range rollback and final full approval
  - judge: independent
  - judge_model: GPT-6/Codex; exact deployment identifier unavailable
  - enforcement: local-only
  - proof_gaps: final/runtime evidence belongs to p4; actual completion commit needed before future B

- 2026-10-13T09:35:42Z — phase `p4-dry-run` — verdict: APPROVED — mode: full
  - `cd cli && cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test` — exit 0; 80 unit + 3 projection + 2 installed-reference tests; root final run and independent rerun green.
  - `cd cli && env RUSTUP_HOME=/tmp/mono-harness-migration-kya1gqcc/isolated-rustup cargo build --release --target x86_64-unknown-linux-musl && test "$(wc -c < target/x86_64-unknown-linux-musl/release/zharness)" -le 1850000` — root exit 0; independent build/size verification green, 815824 bytes; SHA256 41c055d9ce594dcc59aee0ccf8da3ccce286fd063beb3dcfd0ba5af487a5d572. Isolated local target prerequisite, not a portable global toolchain claim.
  - `bash scripts/test-guards.sh` — exit 0; 68 passed/0 failed; independent rerun. Bash3 unavailable/skipped.
  - `bash scripts/verify-doc-links.sh` — exit 0; zero findings/four known-removed claims; independent rerun.
  - `bash -c 'for stage in brainstorm to-plan work check handoff watzup; do bash scripts/validate-skill.sh "skills/workflow/$stage/SKILL.md" || exit; done'` — all six individual file validations exit 0, eight advisories each; independent corrected invocation succeeds.
  - `git diff --check` — exit 0; independently rerun; staged diff empty.
  - scope: on target — distribution, conservative retirement, installed references and actual consumer/runtime proof; no semantic tuning or global changes.
  - requirements: R1 met (ADR/index/guide agree, prior ADRs preserved) | R2 met (six separate installed parents, canonical reads, old directories absent) | R3 met (179 local +44 global predicates; approved revised p3 to final p4 only plan progression) | R4 met (M01–11 unchanged verified source, real old-release consumer repeats/uninstall/byte recovery) | R5 met (atomic transition and managed semantics preserved) | R6 met (actual bounded work, SIGINT after R1, fresh watzup/work R2 resume, independent check and handoff, missing dependency stop) | R7 met for migration (four gates, independent full, source and consumer recovery, identified artifacts and future boundary).
  - success_signal: met — source playbook directories absent; isolated installed skills drive bounded and durable resumed work; original/edited/unrelated bytes protected; final four gates pass. No efficiency/model-quality conclusion.
  - rollback_point: owner-authorized source snapshot SHA256 736718d5e4c5ce72408241f7630e6277a079004b04798e8985c3ee6f62700fad; exact offline667-file recovery verified. Consumer rollback independently exact38+38 files. No commit identifies dirty implementation; commit-range rollback not claimed.
  - requests: none blocking migration; archive citation/doc recheck, owner-approved completion commit and deferred immutable incident citation are explicit follow-ups; future baseline B remains gated.
  - not_independently_verified: commit-range rollback, Bash3 compatibility, monetary cost, and hosts/models beyond observed Codex0.162.1/gpt-6.1-sol settings.
  - judge: independent
  - judge_model: GPT-6/Codex family; exact reviewer deployment identifier unavailable. Native trial identity separately observed as gpt-6.1-sol, effort unspecified/null.
  - enforcement: local-only; no commit-hook/CI enforcement claimed.
  - proof_gaps: independence/mapping are testimony; observed runtime is not universal-host proof; commit-range identity and cost unavailable. Owner snapshot exception satisfies migration recovery. No missing migration acceptance class.
  - repeated_failure_classes: no unresolved BAD_OUTPUT recurrence; returned installer failures retain recovery evidence, adversarial guard tests pass; new incident row requires actual approved source commit for truthful citation.
  - observable_evidence: p4/runtime-observations.json, consumer-observations.json, native-model-settings.json, raw native traces and exact snapshots independently inspected; source/consumer rollback distinct. All two blocked native trials retained; later bounded red replay explicitly reconstruction. Canonical check loaded before legacy bytes inspected for scope; no fallback. Missing-skills only git-index cache byte delta, with entries/modes/OIDs/flags/staged diff unchanged. Auth copies absent and excluded from independently verified bundle 1f11b0d0e71547b285040fb0a10bab7d1bf9cbddcf40b352c2f706c6cdb286c9.

## Current State and Next Action

- active_phase: none
- lifecycle_status: completed
- blockers: none for accepted migration
- open_items: tracked guard-fixture environment isolation follow-up; lean SDLC implementation not started
- exact_next_action: activate the future draft by moving it to docs/plans/active/lean-sdlc-workflow.md, record actual baseline B da9fed6a09e34d20f1e586577cf936d74905b7bb, and start work full phase f1-contract
