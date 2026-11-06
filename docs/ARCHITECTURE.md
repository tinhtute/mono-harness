# Architecture

<!-- Historical architecture baseline: 2d4bc5a2015113cd85c3134b04bffc18f94887d1; the skill-owned migration below is an uncommitted candidate, not that revision. -->

The Rust three-verb architecture with the ADR 0015 skill-owned migration candidate. Installer and consumer verification status lives in the active plan; this document makes no release claim. Decisions that are expensive to reverse have their own records under `docs/decisions/`; this document describes the running system.

## The one idea

Committed markdown is the truth. The binary is a scaffolding tool, not a runtime.

`zharness` owns exactly three verbs — install, update, uninstall — that manage a doc set inside a consumer git repository. The whole lifecycle (brainstorm → to-plan → work → check → handoff) runs from independently installed skill references, committed repository data, repo scripts, and a pre-commit hook, with the binary absent from PATH. Delete the binary and every derived artifact, and the same lifecycle still executes, provided the host still exposes the six workflow skills and their references.

## The three verbs

![zharness installs the doc set; skills are installed separately and read it](../site/assets/architecture.png)

```
cli/src/main.rs                  one Rust binary (clap), three verbs
        |
        v
install                          scaffolds the managed set, records a base, reports brownfield read-only
update                           refreshes WORKFLOW and the AGENTS block (hash-guarded); safely retires recorded legacy procedures; scaffolds absent PROJECT; --check is read-only
uninstall                        removes proven managed copies, restores proven originals, and retains edited/unknown bytes and unresolved recovery
```

`all_targets` (`cli/src/installer/mod.rs`) is the managed set: `.harness/WORKFLOW.md` and `.harness/PROJECT.md` (scaffolded from the identity template). A separate fixed legacy inventory supports retirement and recovery without embedding the old procedures. `AGENTS.md` is handled separately and surgically — only the marked `ZHARNESS` block inside it is swapped; consumer prose around it is untouched.

State lives in `.zharness/base/`: a `manifest.json` of `{path, sha256}` entries (the bytes zharness last wrote) and the ownership ledger `ownership.tsv`. Update refuses before any write when the on-disk AGENTS block no longer matches its recorded hash, printing the diff; `--force` replaces it (`cli/src/installer/update.rs`, ADR 0011). Uninstall deletes only wholly-created files, restores captured pre-install originals, and keeps anything locally modified with a warning.

The installer is also the onboarding probe: `install` prints a deterministic, read-only brownfield report (active-plan count, present consumer inputs, foreign state files) and exits 0 without writing outside the managed set. `.harness/PROJECT.md` is the identity record; filling it is the single forced write step at brainstorm lock (`skills/stages/brainstorm/references/brainstorm-lock.md` step 6).

## The fail-closed guards

Fail-closed guarantees live in the pre-commit hook (`scripts/install-git-hooks.sh`, shared core between the `# ZGUARD-CORE` markers):

1. **Proof re-execution** — a newly added `## Validation` entry with verdict `APPROVED` (or `APPROVE_WITH_REQUESTS`) has every nested proof command re-executed by the hook; any non-zero exit rejects the commit.
2. **Independent judge (high-risk)** — on a `lane: high-risk` plan, a new Validation entry carrying `judge: same-session` is rejected.
3. **Independent judge (full)** — a newly added Validation entry that declares `mode: full` and `judge: same-session` is rejected, on every lane.
4. **At most one active plan** — more than one non-empty file under `.harness/plans/active/` is rejected; zero is a valid idle state.

`.github/workflows/cli-ci.yml` re-runs these checks on pushed commits, so bypassing local hooks gains nothing. The hook reads staged bytes itself; there is no pass marker an authoring agent could forge.

Handoff absorb is playbook protocol, not a hook: final close writes `absorb: none` or names an existing ADR/guard/memory. An unabsorbed class-of-failure stops before `git mv`.

Tool allow/deny is the host runtime’s job, not zharness: READ files by default, RUN TESTS in a sandbox, WRITE inside the workspace, NETWORK scoped by task, DEPLOY and DELETE DATA behind approval. This binary only installs the doc set and the hook only gates Validation commits.

## Embedded doc set and projection

The binary carries `AGENTS.md`, `WORKFLOW.md` and the PROJECT template from `cli/docs/embedded/`. Only `.harness/WORKFLOW.md` is a byte-identical projection checked by projection parity. The twelve procedures live in the six owning `skills/stages/<stage>/references/` directories and are installed independently; `zharness` neither embeds nor installs them. WORKFLOW resolves the selected skill through host metadata, companions from that installed skill and data from the consumer root. Missing dependencies stop execution rather than invoking retained old procedures.

## Markdown-only lifecycle state

| Path | Nature |
|---|---|
| `.harness/plans/active/*.md` | authoritative — the one active initiative; append-only `## Log` / `## Validation` |
| `.harness/PROJECT.md` | authoritative — identity, answered at the brainstorm lock |
| `docs/memory/*.md` | memory as files; agents grep directly (`docs/memory/{id}.md`) |
| `docs/decisions/`, `docs/research/` | authoritative records |
| `.harness/WORKFLOW.md` | projected; edit `cli/docs/embedded/WORKFLOW.md` instead |
| `skills/stages/<stage>/references/` | authored procedure source; independently installed into the host |
| `.zharness/` | installer bookkeeping (active base manifest, ownership ledger, original payloads and interrupted-restoration intent) and `cache/` per-machine scratch; gitignored |

Task execution status lives only in append-only `## Log`; task definitions carry no status fields. Bookkeeping is hand-appended — the binary writes no plan rows.

## Historical note (pre-v0.15, explicitly historical)

The 0.14.x architecture — a `preflight <stage>` entry point, a SQLite store under `harness.db` serving as a derived index (`managed_docs`, `plan_index`, `memories` tables, `db rebuild`), conflict staging under `.kit/`, and CLI proof verification via `check record` — was deleted in v0.15. Consumers who depend on it can pin the 0.14.x release; its proof-verification contract survives verbatim in the pre-commit hook (see [`cli/docs/CONTRACT.md`](../cli/docs/CONTRACT.md)).
