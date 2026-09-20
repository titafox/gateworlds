//! Keeps the contribution guide from lying.
//!
//! `CONTRIBUTING.md` hands a newcomer a complete world to copy. If the protocol moves and
//! that example is not moved with it, the first thing a contributor does is paste something
//! that does not work, and they conclude the project is broken rather than the document. So
//! the example is a real package on disk, validated like any other, and the version printed
//! in the guide is checked against it character for character after comments are removed.

use std::path::{Path, PathBuf};

use gateworlds_protocol::validate_package;
use serde_json::Value;

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .ancestors()
        .nth(3)
        .expect("crates/<name> sits three levels below the repository root")
        .to_path_buf()
}

/// Removes `//` comments while respecting string literals.
///
/// A naive strip would cut a URL in half at the first `//` inside a quoted value, and the
/// resulting parse error would look like a mistake in the guide rather than in this
/// function.
fn strip_line_comments(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    let mut chars = text.chars().peekable();
    let (mut in_string, mut escaped) = (false, false);

    while let Some(c) = chars.next() {
        if in_string {
            out.push(c);
            if escaped {
                escaped = false;
            } else if c == '\\' {
                escaped = true;
            } else if c == '"' {
                in_string = false;
            }
            continue;
        }
        match c {
            '"' => {
                in_string = true;
                out.push(c);
            }
            '/' if chars.peek() == Some(&'/') => {
                for skipped in chars.by_ref() {
                    if skipped == '\n' {
                        out.push('\n');
                        break;
                    }
                }
            }
            _ => out.push(c),
        }
    }
    out
}

fn jsonc_blocks(markdown: &str) -> Vec<String> {
    let mut blocks = Vec::new();
    let mut rest = markdown;
    while let Some(start) = rest.find("```jsonc\n") {
        let after = &rest[start + "```jsonc\n".len()..];
        let Some(end) = after.find("```") else { break };
        blocks.push(after[..end].to_string());
        rest = &after[end..];
    }
    blocks
}

#[test]
fn the_example_world_in_the_guide_actually_validates() {
    let dir = repo_root().join("examples/my_world");
    let report = validate_package(&dir).expect("the example package should be readable");
    assert!(
        report.is_ok(),
        "the world offered to newcomers does not validate:\n{}",
        report
            .findings
            .iter()
            .map(|f| format!("  {f}\n"))
            .collect::<String>()
    );
}

#[test]
fn the_guide_and_the_example_on_disk_have_not_drifted() {
    let root = repo_root();
    let guide = std::fs::read_to_string(root.join("CONTRIBUTING.md")).expect("readable");
    let blocks = jsonc_blocks(&guide);

    assert_eq!(
        blocks.len(),
        2,
        "expected the guide to print world.json and items.json, found {} jsonc blocks",
        blocks.len()
    );

    for (block, name) in blocks.iter().zip(["world.json", "items.json"]) {
        let printed: Value = serde_json::from_str(&strip_line_comments(block))
            .unwrap_or_else(|e| panic!("the {name} in CONTRIBUTING.md is not valid JSON: {e}"));

        let on_disk: Value = serde_json::from_str(
            &std::fs::read_to_string(root.join("examples/my_world").join(name)).expect("readable"),
        )
        .expect("json");

        assert_eq!(
            printed, on_disk,
            "CONTRIBUTING.md and examples/my_world/{name} disagree. \
             Change one and the other stops being true; change both."
        );
    }
}

#[test]
fn comment_stripping_does_not_cut_strings_in_half() {
    let kept = strip_line_comments(r#"{"a": "https://example.invalid/x", "b": 1} // trailing"#);
    let parsed: Value = serde_json::from_str(&kept).expect("should still parse");
    assert_eq!(parsed["a"], "https://example.invalid/x");
    assert_eq!(parsed["b"], 1);

    let escaped = strip_line_comments(r#"{"a": "quote \" then // not a comment"}"#);
    let parsed: Value = serde_json::from_str(&escaped).expect("should still parse");
    assert_eq!(parsed["a"], r#"quote " then // not a comment"#);
}
