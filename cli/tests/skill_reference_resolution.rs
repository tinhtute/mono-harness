//! Installed-reference packaging proof. Host execution is separately required
//! by M12–M14; this test does not claim to execute an agent.
use std::collections::HashMap;
use std::fs;
use std::path::{Component, Path, PathBuf};

const STAGES: &[(&str, &[&str])] = &[
    (
        "brainstorm",
        &["brainstorm", "brainstorm-grill", "brainstorm-lock"],
    ),
    ("to-plan", &["to-plan"]),
    (
        "work",
        &["work", "work-bounded", "work-full", "work-fanout"],
    ),
    (
        "check",
        &[
            "check",
            "check-durable",
            "check-validation",
            "check-review",
            "check-risk",
            "check-exercise",
        ],
    ),
    ("handoff", &["handoff"]),
    ("watzup", &["watzup"]),
];

fn install_fixture(root: &Path) -> HashMap<String, PathBuf> {
    let source = Path::new(env!("CARGO_MANIFEST_DIR")).join("../skills/stages");
    let mut metadata = HashMap::new();
    for (i, (stage, refs)) in STAGES.iter().enumerate() {
        // Deliberately unrelated parents: ../other-skill routing must not work.
        let installed = root.join(format!("host-{i}/nested/package"));
        fs::create_dir_all(installed.join("references")).unwrap();
        fs::copy(
            source.join(stage).join("SKILL.md"),
            installed.join("SKILL.md"),
        )
        .unwrap();
        for name in *refs {
            let rel = format!("references/{name}.md");
            fs::copy(source.join(stage).join(&rel), installed.join(&rel))
                .unwrap_or_else(|e| panic!("copy {stage}/{rel}: {e}"));
        }
        metadata.insert(stage.to_string(), installed);
    }
    metadata
}

fn markdown_targets(text: &str) -> Vec<&str> {
    text.split("](")
        .skip(1)
        .filter_map(|s| s.split_once(')').map(|p| p.0))
        .collect()
}

fn assert_local_links(file: &Path, installed: &Path) {
    let text = fs::read_to_string(file).unwrap();
    assert!(
        !text.contains("docs/playbooks/"),
        "legacy route in {}",
        file.display()
    );
    for target in markdown_targets(&text) {
        if target.contains("://") || target.starts_with('#') {
            continue;
        }
        let relative = Path::new(target.split('#').next().unwrap());
        assert!(
            relative
                .components()
                .all(|c| matches!(c, Component::Normal(_))),
            "reference must stay within installed skill: {target}"
        );
        let resolved = file.parent().unwrap().join(relative);
        assert!(
            resolved.is_file(),
            "missing installed companion {}",
            resolved.display()
        );
        assert!(resolved
            .canonicalize()
            .unwrap()
            .starts_with(installed.canonicalize().unwrap()));
    }
}

#[test]
fn installed_references_resolve_without_source_or_shared_parent() {
    let temp = tempfile::tempdir().unwrap();
    let metadata = install_fixture(temp.path());
    let consumer = temp.path().join("consumer");
    fs::create_dir_all(consumer.join(".harness/plans/active")).unwrap();
    fs::write(
        consumer.join(".harness/plans/active/task.md"),
        b"consumer plan",
    )
    .unwrap();
    for (stage, refs) in STAGES {
        let installed = &metadata[*stage];
        let wrapper = fs::read_to_string(installed.join("SKILL.md")).unwrap();
        assert!(wrapper.contains(&format!("[references/{stage}.md](references/{stage}.md)")));
        assert!(wrapper.contains("host's skill metadata"));
        assert!(wrapper.contains("consumer repository root"));
        assert!(wrapper.contains("report the missing dependency and stop"));
        assert_local_links(&installed.join("SKILL.md"), installed);
        for name in *refs {
            assert_local_links(&installed.join(format!("references/{name}.md")), installed);
        }
        // Resolve the next stage through metadata, never through a common parent.
        let next = &metadata["check"];
        assert!(next.join("references/check.md").is_file());
        assert_eq!(
            fs::read(consumer.join(".harness/plans/active/task.md")).unwrap(),
            b"consumer plan"
        );
        assert!(!installed.join(".harness/plans/active/task.md").exists());
    }
}

#[test]
fn installed_resolution_detects_missing_companion() {
    let temp = tempfile::tempdir().unwrap();
    let metadata = install_fixture(temp.path());
    let check = &metadata["check"];
    fs::remove_file(check.join("references/check-durable.md")).unwrap();
    assert!(std::panic::catch_unwind(|| assert_local_links(
        &check.join("references/check.md"),
        check
    ))
    .is_err());
}
