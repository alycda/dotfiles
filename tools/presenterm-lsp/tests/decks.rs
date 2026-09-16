//! End-to-end checks over whole decks, driven through the `--check` CLI so
//! that what CI runs is what is tested.

use std::{path::Path, process::Command};

fn check(fixture: &str) -> (bool, String) {
    let binary = env!("CARGO_BIN_EXE_presenterm-lsp");
    let path = Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures").join(fixture);
    let output = Command::new(binary).arg("--check").arg(&path).output().expect("failed to run presenterm-lsp");
    let combined = String::from_utf8_lossy(&output.stdout).to_string() + &String::from_utf8_lossy(&output.stderr);
    (output.status.success(), combined)
}

#[test]
fn a_valid_deck_passes() {
    let (ok, output) = check("valid.md");
    assert!(ok, "expected a clean exit, got:\n{output}");
    assert!(output.contains("0 errors"), "{output}");
}

#[test]
fn a_broken_deck_reports_every_problem_at_once() {
    let (ok, output) = check("broken.md");
    assert!(!ok, "expected a failing exit");

    // presenterm stops at the first of these; the point of the server is that
    // all of them surface in one pass.
    for expected in [
        "unknown-theme",
        "invalid-command",
        "no-layout",
        "invalid-layout",
        "not-inside-column",
        "column-index-too-large",
        "invalid-font-size",
        "undefined-snippet-id",
    ] {
        assert!(output.contains(expected), "missing {expected} in:\n{output}");
    }
}

#[test]
fn json_output_is_machine_readable() {
    let binary = env!("CARGO_BIN_EXE_presenterm-lsp");
    let path = Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/broken.md");
    let output = Command::new(binary).args(["--check", "--format", "json"]).arg(&path).output().expect("run failed");
    let text = String::from_utf8_lossy(&output.stdout);
    let records: serde_json::Value = serde_json::from_str(&text).expect("output is not valid json");
    let records = records.as_array().expect("expected an array");
    assert!(!records.is_empty());
    for record in records {
        for key in ["file", "line", "column", "severity", "code", "message"] {
            assert!(record.get(key).is_some(), "record missing {key}: {record}");
        }
    }
}
