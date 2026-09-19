//! The conformance vectors and the shipped world packages, run as ordinary tests.
//!
//! `cargo test` is the single command. A check that only ever runs when someone remembers
//! to type a CLI invocation is not a regression defence.

use std::path::{Path, PathBuf};

use gateworlds_protocol::{conformance, validate_package};

/// The repository root, from this crate's manifest directory.
fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .ancestors()
        .nth(3)
        .expect("crates/<name> sits three levels below the repository root")
        .to_path_buf()
}

#[test]
fn every_conformance_vector_passes() {
    let dir = repo_root().join("protocol/conformance");
    let outcomes = conformance::run_dir(&dir).expect("vectors should be readable");

    let failed: Vec<&_> = outcomes.iter().filter(|o| !o.passed()).collect();
    if !failed.is_empty() {
        let mut msg = format!("{} of {} vectors failed:\n", failed.len(), outcomes.len());
        for o in failed {
            msg.push_str(&format!(
                "  {}: {}\n",
                o.name,
                o.failure.as_deref().unwrap_or("")
            ));
        }
        panic!("{msg}");
    }
    assert!(
        outcomes.len() >= 27,
        "expected at least 27 vectors, found {}",
        outcomes.len()
    );
}

/// Guards against a vector directory that silently stops being read: a runner reporting
/// "0 failed" over an empty set looks exactly like success.
#[test]
fn both_vector_directions_are_populated() {
    let dir = repo_root().join("protocol/conformance");
    for sub in ["valid", "invalid"] {
        let count = std::fs::read_dir(dir.join(sub))
            .unwrap_or_else(|e| panic!("cannot read {sub}: {e}"))
            .flatten()
            .filter(|e| e.path().extension().is_some_and(|x| x == "json"))
            .count();
        assert!(count > 0, "{sub}/ contains no vectors");
    }
}

/// SPEC / conformance README: every shipped package must validate with the full validator,
/// including the checks the vectors cannot reach because they have no directory on disk
/// (`resource_not_found`, package-root containment after symlink resolution).
#[test]
fn every_shipped_world_package_validates() {
    let worlds = repo_root().join("worlds");
    let mut checked = 0;
    let mut problems = String::new();

    let mut dirs: Vec<PathBuf> = std::fs::read_dir(&worlds)
        .expect("worlds/ should exist")
        .flatten()
        .map(|e| e.path())
        .filter(|p| p.is_dir())
        .collect();
    dirs.sort();

    for dir in dirs {
        checked += 1;
        match validate_package(&dir) {
            Err(e) => problems.push_str(&format!("  {}: {e}\n", dir.display())),
            Ok(report) if report.is_ok() => {}
            Ok(report) => {
                problems.push_str(&format!("  {}:\n", dir.display()));
                for f in report.findings {
                    problems.push_str(&format!("    {f}\n"));
                }
            }
        }
    }

    assert!(
        checked >= 2,
        "expected the two reference worlds, found {checked}"
    );
    assert!(
        problems.is_empty(),
        "shipped packages failed validation:\n{problems}"
    );
}

/// The two reference worlds must actually reach each other. A portal naming a world that is
/// not shipped would validate fine on its own -- resolution happens at travel time -- and
/// the player would hit a dead end at runtime.
#[test]
fn the_two_reference_worlds_link_to_each_other() {
    let worlds = repo_root().join("worlds");
    let read = |id: &str| -> serde_json::Value {
        let p = worlds.join(id).join("world.json");
        serde_json::from_str(&std::fs::read_to_string(&p).expect("readable")).expect("json")
    };

    for (from, to) in [
        ("pastoral_village", "xianxia_gate"),
        ("xianxia_gate", "pastoral_village"),
    ] {
        let src = read(from);
        let dst = read(to);

        let portal = src["entities"]
            .as_array()
            .unwrap()
            .iter()
            .flat_map(|e| e["components"].as_array().unwrap())
            .find(|c| c["type"] == "portal" && c["target_world"] == to)
            .unwrap_or_else(|| panic!("{from} has no portal to {to}"));

        let spawn = portal["target_spawn"].as_str().unwrap_or("default");
        assert!(
            dst["spawns"].get(spawn).is_some(),
            "{from} sends the player to {to} spawn {spawn:?}, which {to} does not define"
        );
    }
}

/// Regression: validating a `world.json` on its own must still resolve the item definitions
/// sitting next to it.
///
/// Without this, every `pickup` in a real package is reported as an unresolved reference --
/// a false positive that blames the creator for the tool's blind spot. Found by running
/// `docs/BOOTSTRAP.md` verbatim on a clean clone, which is the only way that document is
/// worth anything.
#[test]
fn validating_a_world_file_alone_resolves_its_sibling_items() {
    use gateworlds_protocol::{DocKind, context_for_file, validate};

    let file = repo_root().join("worlds/xianxia_gate/world.json");
    let doc: serde_json::Value =
        serde_json::from_str(&std::fs::read_to_string(&file).expect("readable")).expect("json");

    let ctx = context_for_file(DocKind::World, &doc, &file);
    assert!(
        ctx.known_items.contains("xianxia_gate:spirit_herb"),
        "the sibling items.json was not picked up: {:?}",
        ctx.known_items
    );

    let report = validate(DocKind::World, &doc, &ctx);
    assert!(
        report.is_ok(),
        "expected no findings, got: {:?}",
        report.findings
    );
}
