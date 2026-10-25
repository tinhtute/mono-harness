//! The canonical doc set bundled into the binary at compile time.
//!
//! Only the AGENTS entrypoint, WORKFLOW router and project template ship in
//! the binary. Workflow procedures belong to independently installed skills.

use include_dir::{include_dir, Dir};

static TEMPLATES: Dir<'static> = include_dir!("$CARGO_MANIFEST_DIR/docs/embedded/templates");

const AGENTS_MD: &[u8] = include_bytes!(concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/docs/embedded/AGENTS.md"
));
const WORKFLOW_MD: &[u8] = include_bytes!(concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/docs/embedded/WORKFLOW.md"
));

/// The write-once project identity template, written to `.harness/PROJECT.md` only
/// when that file is absent.
pub const PROJECT_TEMPLATE: &str = "templates/project.identity.md";

/// Every embedded doc path plus the docs version stamp identifying the build.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Manifest {
    pub paths: Vec<String>,
    pub docs_version: String,
}

/// Read one embedded file by its path inside the doc set. The `templates/`
/// prefix is kept, mirroring Go's `Templates.ReadFile(t.Src)`.
pub fn read_file(path: &str) -> Option<&'static [u8]> {
    match path {
        "AGENTS.md" => Some(AGENTS_MD),
        "WORKFLOW.md" => Some(WORKFLOW_MD),
        _ => {
            if let Some(rest) = path.strip_prefix("templates/") {
                TEMPLATES.get_file(rest).map(|f| f.contents())
            } else {
                None
            }
        }
    }
}

/// Managed entrypoint and router paths, sorted. Templates are scaffold-only.
pub fn managed_paths() -> Vec<String> {
    let mut paths = vec!["AGENTS.md".to_string(), "WORKFLOW.md".to_string()];
    paths.sort();
    paths
}

/// Every embedded path across both embeds, sorted.
pub fn all_embedded_paths() -> Vec<String> {
    let mut paths = managed_paths();
    for f in TEMPLATES.files() {
        paths.push(format!("templates/{}", file_name(f.path())));
    }
    paths.sort();
    paths
}

/// Walk the doc set and return every managed path, sorted, plus the supplied
/// docs version (the CLI's own version string).
pub fn build_manifest(docs_version: &str) -> Manifest {
    Manifest {
        paths: managed_paths(),
        docs_version: docs_version.to_string(),
    }
}

fn file_name(p: &std::path::Path) -> String {
    p.file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use std::fs;
    use std::path::{Path, PathBuf};

    use super::*;

    /// Folded at compile time so a tree scan cannot match its own guard list.
    const LEGACY_DB_NAME: &str = concat!("harness", ".db");

    #[test]
    fn build_manifest_paths_present_and_non_empty() {
        let m = build_manifest("dev");
        assert!(!m.paths.is_empty(), "manifest has no paths");
        for p in &m.paths {
            let data = read_file(p).unwrap_or_else(|| panic!("read_file({p}): not embedded"));
            assert!(!data.is_empty(), "{p} is empty");
        }
    }

    #[test]
    fn procedures_are_not_distributed_by_the_binary() {
        assert_eq!(managed_paths(), ["AGENTS.md", "WORKFLOW.md"]);
        assert!(read_file("playbooks/work.md").is_none());
        assert!(!Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("docs/embedded/playbooks")
            .exists());
        assert!(!Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../docs/playbooks")
            .exists());
    }

    #[test]
    fn build_manifest_entrypoint_and_workflow_present() {
        let m = build_manifest("dev");
        for w in ["AGENTS.md", "WORKFLOW.md"] {
            assert!(m.paths.iter().any(|p| p == w), "manifest missing {w}");
        }
    }

    #[test]
    fn build_manifest_docs_version_exposed() {
        assert_eq!(build_manifest("0.2.0").docs_version, "0.2.0");
    }

    /// Every file on disk under `docs/embedded` must be embedded through
    /// either embed — the managed set walked into the manifest or the
    /// separately embedded `templates/` — and vice versa. A doc added on disk
    /// but not to an embed (or the reverse) is invisible to the binary.
    #[test]
    fn build_manifest_matches_disk_tree() {
        let manifest_paths = all_embedded_paths();

        let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("docs/embedded");
        let mut disk_paths = Vec::new();
        collect(&root, &root, &mut disk_paths);
        // embed.go carries the directive; it is not itself embedded.
        disk_paths.retain(|p| !p.ends_with(".go"));
        disk_paths.sort();

        assert_eq!(
            manifest_paths, disk_paths,
            "manifest and disk tree disagree\nmanifest: {manifest_paths:?}\ndisk: {disk_paths:?}"
        );
    }

    fn collect(root: &Path, dir: &Path, out: &mut Vec<String>) {
        let entries = fs::read_dir(dir).unwrap_or_else(|e| panic!("walk {}: {e}", dir.display()));
        for e in entries.flatten() {
            let p = e.path();
            if p.is_dir() {
                collect(root, &p, out);
            } else {
                out.push(
                    p.strip_prefix(root)
                        .unwrap_or(&p)
                        .to_string_lossy()
                        .replace('\\', "/"),
                );
            }
        }
    }

    struct PlaybookContract {
        name: &'static str,
        path: &'static str,
        required: &'static [&'static str],
        forbidden: &'static [&'static str],
    }

    /// Strings that must never reappear in any skill-owned procedure: the retired
    /// lifecycle verbs and the pre-v0.15 state-mirroring vocabulary.
    const RETIRED: &[&str] = &[
        ".kit/planning",
        "SPEC.md",
        "ROADMAP.md",
        "-CONTEXT.md",
        "-PLAN.md",
        ".kit/runs",
        ".kit/reports",
        ".kit/HANDOFF.md",
        "implementation-notes",
        "--artifact-path",
        "zharness scaffold run",
        "zharness scaffold check",
        "zharness scaffold handoff",
        "RUN artifact",
        "CHECK report",
        // v0.15 slim (R1/R6): every lifecycle verb is deleted from source, and
        // the playbooks are markdown-first with no index-sync block. These
        // strings must never reappear in any skill-owned procedure.
        "zharness preflight",
        "zharness run create",
        "zharness trace add",
        "zharness decision add",
        "zharness story",
        "zharness intake",
        "zharness id",
        "zharness scaffold plan",
        "zharness query",
        "zharness audit",
        "zharness validate",
        "zharness resume",
        "zharness init",
        "zharness migrate",
        "zharness import",
        "zharness db ",
        "zharness memory",
        "zharness plan complete",
        "zharness handoff record",
        "check record",
        "--close-phase",
        "Optional index-sync",
        LEGACY_DB_NAME,
        "lifecycle ledger",
        "DB-mirroring",
        "mirrored check row",
        "check_id: ULID",
        "latest_run_id",
        "lifecycle rows",
    ];

    #[test]
    fn one_plan_playbook_contract() {
        let contracts = [
            PlaybookContract {
                name: "brainstorm locks honest bootstrap state",
                path: "brainstorm/references/brainstorm.md",
                required: &[
                    "read [brainstorm-grill.md](brainstorm-grill.md) now",
                    "read [brainstorm-lock.md](brainstorm-lock.md) and [brainstorm-grill.md](brainstorm-grill.md) now",
                    "## Goal",
                    "explore creates no plans, reports, changesets, or markdown artifacts",
                    "`tiny` → stop and route to `work bounded`",
                    "`normal`: Goal + one phase `main`, no `to-plan`",
                ],
                forbidden: &[
                    "story_id",
                    "intake_id",
                    "## Progress",
                    "## Decisions",
                    "new-spec",
                ],
            },
            PlaybookContract {
                name: "brainstorm-lock writes the plan skeleton",
                path: "brainstorm/references/brainstorm-lock.md",
                required: &[
                    "Loaded by [brainstorm.md](brainstorm.md) for `lock` and `refine`",
                    "## Phases and Verification",
                    "## Log",
                    "## Validation",
                    "## Current State and Next Action",
                    "The canonical active path is `.harness/plans/active/{slug}.md`",
                    "confirm no non-empty plan exists under `.harness/plans/active/`",
                    "approach: not-planned",
                    "exact_next_action: to-plan",
                    "- success_signal:",
                    "- actors:",
                    "| acceptance: <how it is verified> |",
                    "those definitions are immutable",
                    "phase_slug: `main`",
                    "exact_next_action: work full phase main",
                    "`## Log` is the sole task execution-status source",
                ],
                forbidden: &[
                    "story_id",
                    "intake_id",
                    "## Progress",
                    "## Decisions",
                    "new-spec",
                ],
            },
            PlaybookContract {
                name: "brainstorm-grill grills in rounds",
                path: "brainstorm/references/brainstorm-grill.md",
                required: &[
                    "Loaded by [brainstorm.md](brainstorm.md) for `grill` and `raw`",
                    "Grill until the **Done** condition below holds",
                    "**Frontier**",
                    "**`raw`** — at most 2 rounds",
                    "4. **Clarify the boundary**",
                ],
                forbidden: &[
                    "story_id",
                    "intake_id",
                    "## Progress",
                    "## Decisions",
                    "new-spec",
                ],
            },
            PlaybookContract {
                name: "to-plan defines phases as markdown truth",
                path: "to-plan/references/to-plan.md",
                required: &[
                    "## Phases and Verification",
                    "- approach:",
                    "indented two spaces with no bullet",
                    "— output: <expected result> — check: `<command>` — stop_if: <condition>",
                    "- escalate_when:",
                    "every requirement appears in some phase `goal:`",
                    "validation expectations",
                    ".harness/plans/active/{slug}.md",
                    "After a phase/task definition is written, it is immutable",
                    "work/check/handoff may change only that phase's lifecycle status in this file",
                    "`to-plan` runs only for `high-risk`",
                    "a `normal` plan → stop and route to `work full phase main`",
                    "Do not add task status fields",
                    "never write parallel task/phase state anywhere else",
                    "`## Log` is the sole task execution-status source",
                ],
                forbidden: &["story_id", "## Approach and Risks", "## Progress"],
            },
            PlaybookContract {
                name: "work routes each mode to its companion",
                path: "work/references/work.md",
                required: &[
                    "read [work-bounded.md](work-bounded.md) now",
                    "read [work-full.md](work-full.md) now",
                    "print the resolved mode as your first output line",
                ],
                forbidden: &["Zero-write rule"],
            },
            PlaybookContract {
                name: "work bounded writes no durable artifacts",
                path: "work/references/work-bounded.md",
                required: &[
                    "bounded/simple mode creates no plans, reports, changesets, or markdown artifacts",
                    "**red → green**",
                ],
                forbidden: &[],
            },
            PlaybookContract {
                name: "work appends durable markdown log entries",
                path: "work/references/work-full.md",
                required: &[
                    "## Log",
                    "## Current State and Next Action",
                    "slice `.harness/plans/active/{slug}.md` by section",
                    "set that phase's plan status to `in-progress`",
                    "`start|done|blocked|decision`",
                    "A `blocked` entry is written immediately",
                    "A phase with no task list: work each requirement in turn",
                    "Do not add or update task-definition `status` fields",
                    "`## Log` is the sole task execution-status source",
                    "`normal` → this gate is the final check",
                    "`high-risk` or an owner's explicit `check full` → keep `in-progress`",
                    "**Stop gates (fail-closed):**",
                    "A condition you cannot evaluate from current evidence counts as matched",
                    "On a match, stop at once: no further edits, task, or `done` in this run",
                    "`gate: stop_if|escalate_when`, the condition text verbatim, the evidence that matched it",
                    "one exact next action",
                    "resume only after the owner answers",
                    "Unmatched → continue; the task's `done` notes `stop_if: not matched`",
                    "a normal blocker is an obstacle",
                    "a stop condition is a planned `stop_if:`",
                    "an owner escalation is a planned `escalate_when:`",
                    "Enforcement is prompt-level: this procedure is the guarantee",
                ],
                forbidden: &[
                    "single-phase plan skips this gate and goes straight there","## Progress", "## Decisions", "task_status="],
            },
            PlaybookContract {
                name: "work fan-out separates writers and verifies handbacks",
                path: "work/references/work-fanout.md",
                required: &[
                    "Loaded by [work-full.md](work-full.md) step 4",
                    "a fence in the brief's prose is not a lock",
                    "Never let two workers edit one file",
                    "Pass `model` explicitly on every dispatch",
                    "a different model family from the worker",
                    "A report is a claim",
                    "run the full phase check on the combined tree",
                    "lands first; reinstall the hook before spawning the rest",
                    "The owner's named model wins over this table",
                    "GOAL       one sentence",
                    "FORBIDDEN  no merge, rebase, force-push, --no-verify",
                    "REPORT     PASS | ISSUES | BLOCKED",
                    "A second miss → log `blocked`",
                    "Merge accepted branches one at a time",
                ],
                forbidden: &[],
            },
            PlaybookContract {
                name: "check preserves review intent and records evidence",
                path: "check/references/check.md",
                required: &[
                    "## Validation",
                    "Invocation intent wins",
                    "`auto` never resolves to `full`",
                    // These pin the authored routing contract, not agent behavior.
                    "resolve to `bounded` without reading any plan",
                    "invalid initiative state never falls back to `bounded`",
                    "`bounded` (aliases: `simple`, `review`)",
                    "After the preflight succeeds, print the resolved mode before running checks or writing state",
                    "A failed preflight reports its blocker instead",
                    "`bounded` is always response-only",
                    "never appends to Validation",
                    "Durable `gate` runs automated checks",
                    "`full` includes the gate and adds the complete Security, Performance, Architecture, and Code Quality review",
                    "`gate` does not perform manual review",
                    "depth: quick | standard | deep",
                    "read [check-durable.md](check-durable.md) now",
                    "read [check-review.md](check-review.md) now",
                    // #151/#152: one lane matrix; scripts/ci/test-guards.sh pins
                    // its proof and judge columns to the commit-time guard.
                    "## Lane Matrix",
                    "single source of truth for lane → proof, review depth, and judge",
                    "| `tiny` | `output` | `bounded` |",
                    "| `normal` | `output`, `unit` | `gate` | automated gate and plan alignment; no manual review |",
                    "| `high-risk` | `output`, `unit`, `integration` | `full` | complete four-area review | `independent` |",
                    "`full` IF the plan's lane is `high-risk` or the owner explicitly invoked `check full`",
                    "A plan's existence or its phase count never selects `full`",
                    "record the classes you proved in the entry's `proof_classes:` line",
                ],
                forbidden: &[
                    "which goes straight to `full`",
                    "## Progress",
                    "receipt:",
                    "mode: gate | full | review",
                    "Before reading any plan, print the resolved mode",
                    "whose selected phase reads `in-progress`; otherwise to `bounded`",
                    "Durable `gate`/`full` mode runs real checks and review",
                    "Gate/full: applicable commands have captured output, alignment and code review ran",
                ],
            },
            PlaybookContract {
                name: "check-durable owns preflight, plan state, and durable steps",
                path: "check/references/check-durable.md",
                required: &[
                    "## Validation",
                    "Loaded by [check.md](check.md) step 2",
                    "count every non-empty markdown plan under `.harness/plans/active/` before matching the requested initiative",
                    "Require exactly one active plan in total",
                    "stop even when only one matches the request",
                    "Read only its selected phase and `## Current State and Next Action`",
                    "re-reading after any compaction",
                    "including unstarted, `checked`, or `done`",
                    "stop before checks or writes",
                    "set the phase status and Current State lifecycle status to `checked`",
                    "keep the phase and Current State lifecycle status `in-progress`",
                    "read [check-validation.md](check-validation.md)",
                    "The repository's pre-commit hook is the sole proof guarantee",
                    "REQUEST_CHANGES entries may cite deliberately failing commands",
                    "`## Log` is the sole task execution-status source",
                    "record it in the entry's `requirements:` line",
                    "`not met` is a material plan contradiction",
                    "also judges the Goal's `success_signal:`",
                    "Record `rollback_point:`",
                ],
                forbidden: &[
                    "## Progress",
                    "receipt:",
                    "mode: gate | full | review",
                    "Before reading any plan, print the resolved mode",
                    "whose selected phase reads `in-progress`; otherwise to `bounded`",
                    "Durable `gate`/`full` mode runs real checks and review",
                    "Gate/full: applicable commands have captured output, alignment and code review ran",
                ],
            },
            PlaybookContract {
                name: "check-review keeps the two review axes apart",
                path: "check/references/check-review.md",
                required: &[
                    "Loaded by [check.md](check.md) step 5",
                    "**Two axes, kept apart**",
                    "**Spec axis**",
                    "**Standards axis**",
                    "Report under `Spec` and `Standards` headings",
                ],
                forbidden: &[
                    "## Progress",
                    "receipt:",
                    "mode: gate | full | review",
                    "Before reading any plan, print the resolved mode",
                    "whose selected phase reads `in-progress`; otherwise to `bounded`",
                    "Durable `gate`/`full` mode runs real checks and review",
                    "Gate/full: applicable commands have captured output, alignment and code review ran",
                ],
            },
            PlaybookContract {
                name: "check-validation defines guard-visible evidence",
                path: "check/references/check-validation.md",
                required: &[
                    "Every Validation entry must include timestamp, stable phase slug, exact command/result and concise output",
                    "so the commit-time guard can find them",
                    "The first line carries the anchored token `verdict: <VERDICT>`",
                    "at most 3 lines",
                    "- requirements: R1 met (<proof>) | R2 not met (<gap>)",
                    "- rollback_point:",
                    "Validation is append-only from an entry's first commit",
                    "**Proof re-execution contract**",
                    "a `requirements:` line is testimony",
                    "## What the Guards Cannot Check",
                ],
                forbidden: &[
                    "## Progress",
                    "receipt:",
                    "mode: gate | full | review",
                    "Before reading any plan, print the resolved mode",
                    "whose selected phase reads `in-progress`; otherwise to `bounded`",
                    "Durable `gate`/`full` mode runs real checks and review",
                    "Gate/full: applicable commands have captured output, alignment and code review ran",
                ],
            },
            PlaybookContract {
                name: "handoff closes phases before initiatives",
                path: "handoff/references/handoff.md",
                required: &[
                    "## Current State and Next Action",
                    "Close every cleanly checked phase",
                    "keep frontmatter `status: active` and the same active path",
                    "Before closing the final phase, require every prior phase to be `done`",
                    "Only after the plan shows every phase `done`",
                    "`lifecycle_status: completed`",
                    "git mv .harness/plans/active/{slug}.md .harness/plans/completed/{slug}.md",
                    "exactly one file may represent the initiative afterwards",
                    ".harness/plans/active/{slug}.md",
                    ".harness/plans/completed/{slug}.md",
                    "Preserve every phase/task definition",
                    "`## Log` is the sole task execution-status source",
                    "drop `start` and `done` entries",
                    "keep the last entry per phase byte-identical",
                ],
                forbidden: &[
                    "## Progress",
                    "## Decisions",
                    "zharness preflight handoff --mode full --json",
                    "Require every phase to be `done` or the final phase",
                ],
            },
            PlaybookContract {
                name: "watzup recaps without writing",
                path: "watzup/references/watzup.md",
                required: &[
                    "Select the active plan by name",
                    "exactly one non-empty file may exist under `.harness/plans/active/*.md`",
                    "Remain read-only",
                    ".harness/plans/active/{slug}.md",
                    "never the whole file",
                    "Read task execution status only from append-only `## Log`",
                    "the sole task execution-status source",
                ],
                forbidden: &["zharness resume --json"],
            },
        ];

        for c in &contracts {
            let data = fs::read_to_string(
                Path::new(env!("CARGO_MANIFEST_DIR"))
                    .join("../skills/stages")
                    .join(c.path),
            )
            .unwrap_or_else(|e| panic!("skill reference {}: {e}", c.path));
            let content = data;
            for phrase in c.required {
                assert!(
                    content.contains(phrase),
                    "{} ({}): missing one-plan contract phrase {phrase:?}",
                    c.path,
                    c.name
                );
            }
            for phrase in RETIRED.iter().chain(c.forbidden.iter()) {
                assert!(
                    !content.contains(phrase),
                    "{} ({}): contains forbidden lifecycle contract {phrase:?}",
                    c.path,
                    c.name
                );
            }
        }
    }

    /// #168: the Lane Matrix review-depth cell for each final check mode
    /// must agree with step 5, which says whether that mode runs a manual
    /// review. A mode step 5 excludes from manual review must not claim one
    /// in the matrix, and a mode step 5 sends to check-review.md must.
    #[test]
    fn check_lane_matrix_agrees_with_manual_review_step() {
        let data = fs::read_to_string(
            Path::new(env!("CARGO_MANIFEST_DIR"))
                .join("../skills/stages/check/references/check.md"),
        )
        .expect("check.md");
        let step5 = data
            .lines()
            .find(|l| l.starts_with("5. **Manual review**"))
            .expect("check.md step 5");
        let body = step5.split_once(" — ").expect("step 5 body").1;
        let (no_review, rest) = body
            .split_once(". ")
            .expect("step 5 first sentence names the mode without manual review");
        let review = rest
            .split_once(": read [check-review.md]")
            .expect("step 5 names the modes that read check-review.md")
            .0;
        let mut rows = 0;
        for row in data.lines().filter(|l| l.starts_with("| `")) {
            let cells: Vec<&str> = row.split('|').map(str::trim).collect();
            let (lane, mode, depth) = (cells[1], cells[3], cells[4]);
            rows += 1;
            if no_review.contains(&format!("{mode} does not perform")) {
                assert!(
                    depth.contains("no manual review"),
                    "lane {lane}: step 5 says {mode} runs no manual review, matrix says {depth:?}"
                );
            } else {
                assert!(
                    review.contains(mode) && !depth.contains("no manual review"),
                    "lane {lane}: matrix depth {depth:?} disagrees with step 5 for {mode}"
                );
            }
        }
        assert_eq!(
            rows, 3,
            "Lane Matrix must have tiny, normal, high-risk rows"
        );
    }

    /// Live instructions must not route agents to the retired `.kit/`
    /// directory; per-machine scratch lives under `.zharness/cache/`. `docs/`
    /// is excluded because it also holds historical records that describe
    /// `.kit/` accurately.
    #[test]
    fn no_legacy_kit_paths() {
        let repo_root = Path::new(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .expect("crate lives one level below the repository root");
        for rel in [
            "skills",
            "scripts",
            "setup",
            "site",
            "README.md",
            "AGENTS.md",
        ] {
            let p = repo_root.join(rel);
            assert!(p.exists(), "walk {rel}: no such path");
            let mut hits: Vec<PathBuf> = Vec::new();
            scan_for_kit(&p, &mut hits);
            assert!(
                hits.is_empty(),
                "{hits:?} reference retired .kit/; use .zharness/cache/ or docs/"
            );
        }
    }

    fn scan_for_kit(p: &Path, hits: &mut Vec<PathBuf>) {
        if p.is_dir() {
            let entries = fs::read_dir(p).unwrap_or_else(|e| panic!("walk {}: {e}", p.display()));
            for e in entries.flatten() {
                scan_for_kit(&e.path(), hits);
            }
            return;
        }
        let Ok(data) = fs::read(p) else {
            return;
        };
        if String::from_utf8_lossy(&data).contains(".kit/") {
            hits.push(p.to_path_buf());
        }
    }
}
