//! `presenterm-lsp` - a language server for presenterm decks.
//!
//! Two modes, one engine:
//!
//!   presenterm-lsp                 speak LSP over stdio (editors)
//!   presenterm-lsp --check FILE…   print diagnostics and exit non-zero (CI)
//!
//! The `--check` mode exists so that "does this deck build?" has the same
//! answer in a pre-commit hook, in CI and in the editor gutter. presenterm
//! itself has no headless validation mode: `--validate-overflows` needs a real
//! terminal to measure against, and any other path renders the deck.

mod analysis;
mod command;
mod document;
mod server;

use analysis::{analyze_with, Severity};
use document::LineIndex;
use std::{path::PathBuf, process::ExitCode};

const USAGE: &str = "\
presenterm-lsp - language server and checker for presenterm decks

USAGE:
    presenterm-lsp                  Run the language server over stdio
    presenterm-lsp --check FILE...  Check decks and exit 1 on any error

OPTIONS:
    --check           Check the given files instead of serving LSP
    --format FORMAT   Output format for --check: human (default) or json
    --quiet           Only print diagnostics, no summary
    -h, --help        Print this message
    -V, --version     Print version information
";

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();

    if args.iter().any(|arg| arg == "-h" || arg == "--help") {
        print!("{USAGE}");
        return ExitCode::SUCCESS;
    }
    if args.iter().any(|arg| arg == "-V" || arg == "--version") {
        println!(
            "presenterm-lsp {} (presenterm grammar {})",
            env!("CARGO_PKG_VERSION"),
            command::MIRRORED_PRESENTERM_VERSION
        );
        return ExitCode::SUCCESS;
    }

    if args.iter().any(|arg| arg == "--check") {
        return check(&args);
    }

    if let Err(error) = server::run() {
        eprintln!("presenterm-lsp: {error}");
        return ExitCode::FAILURE;
    }
    ExitCode::SUCCESS
}

fn check(args: &[String]) -> ExitCode {
    let mut files: Vec<PathBuf> = Vec::new();
    let mut json = false;
    let mut quiet = false;
    let mut iter = args.iter().peekable();
    while let Some(arg) = iter.next() {
        match arg.as_str() {
            "--check" => {}
            "--quiet" => quiet = true,
            "--format" => {
                json = iter.peek().map(|value| value.as_str()) == Some("json");
                iter.next();
            }
            other if other.starts_with("--format=") => json = other == "--format=json",
            other if other.starts_with('-') => {
                eprintln!("presenterm-lsp: unknown option {other}");
                return ExitCode::from(2);
            }
            other => files.push(PathBuf::from(other)),
        }
    }

    if files.is_empty() {
        eprintln!("presenterm-lsp: --check needs at least one file");
        return ExitCode::from(2);
    }

    let mut errors = 0usize;
    let mut warnings = 0usize;
    let mut records = Vec::new();

    for file in &files {
        let text = match std::fs::read_to_string(file) {
            Ok(text) => text,
            Err(error) => {
                eprintln!("presenterm-lsp: {}: {error}", file.display());
                return ExitCode::from(2);
            }
        };
        // An explicit --check is an assertion that this *is* a deck, so the
        // "does this look like a deck" heuristic is deliberately bypassed.
        let analysis = analyze_with(&text, Some(file), true);
        let index = LineIndex::new(&text);

        for diagnostic in &analysis.diagnostics {
            let (line, column) = index.position(diagnostic.span.start);
            let severity = match diagnostic.severity {
                Severity::Error => {
                    errors += 1;
                    "error"
                }
                Severity::Warning => {
                    warnings += 1;
                    "warning"
                }
                Severity::Hint => "note",
            };
            if json {
                records.push(serde_json::json!({
                    "file": file.display().to_string(),
                    "line": line + 1,
                    "column": column + 1,
                    "severity": severity,
                    "code": diagnostic.code,
                    "message": diagnostic.message,
                }));
            } else {
                println!(
                    "{}:{}:{}: {severity}[{}]: {}",
                    file.display(),
                    line + 1,
                    column + 1,
                    diagnostic.code,
                    diagnostic.message
                );
            }
        }
    }

    if json {
        println!("{}", serde_json::to_string_pretty(&records).unwrap_or_default());
    } else if !quiet {
        let decks = files.len();
        println!(
            "checked {decks} deck{}: {errors} error{}, {warnings} warning{}",
            if decks == 1 { "" } else { "s" },
            if errors == 1 { "" } else { "s" },
            if warnings == 1 { "" } else { "s" }
        );
    }

    if errors > 0 {
        ExitCode::FAILURE
    } else {
        ExitCode::SUCCESS
    }
}
