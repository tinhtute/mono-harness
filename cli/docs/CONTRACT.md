# zharness contract — Rust CLI and skill-owned migration candidate

## What the binary is

`zharness` is an installer/updater binary. v0.15 deleted the lifecycle
command surface and the derived-database layer from source. v0.24 rewrites
the implementation from Go to Rust without changing that surface. The binary
registers exactly three verbs — `install`, `update`, and `uninstall` — as
listed below and in `cli/src/cli.rs`.

The command list in this contract therefore mirrors exactly what
`cli/src/cli.rs` registers, and vice versa.

## How it is built

The crate lives in `cli/` (`Cargo.toml`, `src/`, `tests/`). The managed doc
set is embedded at compile time from `cli/docs/embedded/`: `AGENTS.md` and
`WORKFLOW.md` through `include_bytes!`, and `templates/` through
`include_dir!`. `cli/tests/projection_parity.rs` keeps the WORKFLOW router
byte-identical to its projection under `docs/`. Procedures belong to the six
independently installed workflow skills; the binary does not install skills.

The version string is compile-time: `cli/src/cli.rs` reads `ZHARNESS_VERSION`
through `option_env!` and falls back to `CARGO_PKG_VERSION`. The release
workflow sets it from the `cli/v...` tag — the same guarantee the Go build
got from `-X main.version` at link time, by a different mechanism.

## Command surface (unchanged since v0.15)

| Verb | Behavior |
|---|---|
| `install` | Projects the managed doc set (WORKFLOW, AGENTS block, PROJECT identity scaffold, ignore entries), records upstream hashes under `.zharness/base/`, and prints a deterministic read-only brownfield report. Idempotent; exits 0. |
| `update` | Overwrites `WORKFLOW.md`; conservatively retires allowlisted legacy procedures using recorded hashes, ownership and saved originals (ADR 0015); writes `.harness/PROJECT.md` only when absent; replaces the marked `AGENTS.md` block unless its sha256 differs from the one recorded in `.zharness/base/manifest.json`, in which case it prints the diff, writes nothing, and exits non-zero (`--force` replaces it). `--check [--all]` reports drift read-only and exits 1 on drift. Other consumer files are untouched; retained retired files stop being active targets (ADRs 0011/0015). |
| `uninstall` | Removes managed files only. A file locally modified beyond both its base and upstream is left in place with a warning; consumer-owned bytes are never deleted (R12). |

Shared flags: `--root <dir>` overrides the target repository (default: git toplevel of the working directory). The root command also registers `-v, --version`, which prints `zharness version <v>` and exits 0.

## Where the guarantees live now

Fail-closed guarantees live in the repository's **pre-commit hook**, which
reads staged bytes and trusts no marker an agent writes:

1. **Proof re-execution** — a newly added `## Validation` entry whose verdict
   is `APPROVED` or `APPROVE_WITH_REQUESTS` must have every nested proof
   command re-executed by the hook (`sh -c`, 5-minute timeout each, exit 0);
   any failure rejects the commit naming the command and its output tail.
   Proof of a `REQUEST_CHANGES` entry is never re-executed.
2. **Independent judge (high-risk)** — a newly added entry carrying a
   same-session judge declaration into a plan whose frontmatter sets
   `lane: high-risk` is rejected; lane is read from plan frontmatter directly.
3. **Independent judge (full)** — a newly added Validation entry whose first
   line declares `mode: full` and which also carries a same-session judge is
   rejected, on every lane.
4. **At most one active plan** — more than one non-empty file under
   `.harness/plans/active/` is rejected; zero is a valid idle state.

Handoff absorb is playbook protocol, not a hook: close cannot `git mv`
without an `absorb:` line. Missing absorb is not a commit rejection.

These guards are implemented once in `scripts/install-git-hooks.sh` between
the `# ZGUARD-CORE-BEGIN` / `# ZGUARD-CORE-END` markers; the local hook and
the CI job both extract that block verbatim, so neither can drift from the
other. `.github/workflows/cli-ci.yml` re-runs them against pushed commits,
covering anyone who bypasses local hooks.

Tool allow/deny is the **host** agent runtime (Claude/Pi/Codex), not this
binary. Default shape the host should own: READ files allowed; RUN TESTS
inside a sandbox; WRITE inside the workspace; NETWORK scoped by task;
DEPLOY and DELETE DATA require approval. zharness authorizes only
managed-doc `install`/`update`/`uninstall` and, via the hook, commits of
clean Validation entries.

Repository scripts:

- `scripts/install-git-hooks.sh` — installs the hooks (also embeds the guard core)
- `scripts/workflow/record-check.sh` — optional convenience runner for proof commands;
  it holds no guarantee
- `scripts/workflow/plan-slice.sh` — optional plan-section reader; holds no guarantee

## What carries the state

Git-committed markdown alone: plans under `.harness/plans/{active,completed}/*.md`
with Goal, Phases and Verification, append-only Log and Validation, and
Current State and Next Action sections; ADRs under
`docs/decisions/`; session memory as plain files under `docs/memory/`
(convention). The twelve canonical procedures live under
`skills/stages/<stage>/references/` and are independently installed into
the host. Consumer data stays in the consumer repository. Retained legacy
files are not a fallback for missing skills.

The previous derived database was an index whose only consumer — the CLI
lifecycle surface deleted above — is gone. What it was, why it was removed,
and where consumers should pin: see the v0.15 section of the root
`CHANGELOG.md`, the archive of record for this removal.

## Migration candidate (not a release claim)

ADR 0015 removes playbook distribution from the binary. Install the six workflow
skills independently before upgrade. Matching installer-created legacy copies
are removed; proven saved originals are restored. Edited, unknown or conflicting
files retain their recovery records. Failure returns nonzero with retry evidence;
missing base means keep, and corrupt base refuses before writes. The active base
manifest, ownership ledger and original payloads have distinct roles.
See the [migration guide](../../docs/guides/workflow-harness/skill-procedure-migration.md)
for snapshots, supported hosts and required consumer verification.

## Historical breaking changes

v0.24 is a breaking release for the CLI's implementation and release
mechanics: help, usage and error text differs from cobra's, releases publish
under the `cli/v...` tag instead of the bare version, and darwin/amd64 is no
longer built (Apple discontinued x86_64 macOS and GitHub is retiring its
Intel runners; Intel Macs run the arm64 binary under Rosetta 2). The three
verbs, their flags, their exit codes, the bytes they write and the
`.zharness/base/manifest.json` schema are unchanged — a manifest written by
Go v0.23.1 is read, updated and uninstalled by the Rust binary without a
forced reinstall. See the v0.24 section of the root `CHANGELOG.md`.

v0.15 is a breaking release. Consumers should pin the last 0.14.x release to
keep the previous lifecycle binary working; see the v0.15 section of the root
`CHANGELOG.md`.
