//! The conformance vectors and the shipped world packages, run as ordinary tests.
//!
//! `cargo test` is the single command. A check that only ever runs when someone remembers
//! to type a CLI invocation is not a regression defence.

use std::path::{Path, PathBuf};

use gateworlds_protocol::{conformance, validate_package};
use serde_json::Value;

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

/// Every portal that names a world we ship must land on a spawn that world actually has.
///
/// A portal may name a world this client does not hold -- SPEC §7.3 allows it, and
/// resolution happens at travel time. But a portal pointing at a *shipped* world with a
/// spawn name nobody defined is a dead end that validation cannot see, because each package
/// is valid on its own. It is only wrong in company.
///
/// This replaced a test that checked two specific worlds by name. That version stopped
/// being enough the moment a third world was added, which is the usual fate of a test that
/// knows its subjects by name.
#[test]
fn every_portal_into_a_shipped_world_lands_on_a_spawn_that_exists() {
    let worlds = repo_root().join("worlds");
    let mut docs: std::collections::BTreeMap<String, Value> = std::collections::BTreeMap::new();

    let mut dirs: Vec<PathBuf> = std::fs::read_dir(&worlds)
        .expect("worlds/ should exist")
        .flatten()
        .map(|e| e.path())
        .filter(|p| p.is_dir())
        .collect();
    dirs.sort();

    for dir in &dirs {
        let doc: Value = serde_json::from_str(
            &std::fs::read_to_string(dir.join("world.json")).expect("readable"),
        )
        .expect("json");
        docs.insert(doc["id"].as_str().unwrap_or_default().to_string(), doc);
    }
    assert!(
        docs.len() >= 2,
        "expected several worlds, found {}",
        docs.len()
    );

    let mut problems = String::new();
    let mut checked = 0;

    for (from, doc) in &docs {
        for entity in doc["entities"].as_array().into_iter().flatten() {
            for component in entity["components"].as_array().into_iter().flatten() {
                if component["type"] != "portal" {
                    continue;
                }
                let to = component["target_world"].as_str().unwrap_or_default();
                let Some(target) = docs.get(to) else { continue }; // not shipped: allowed
                checked += 1;
                let spawn = component["target_spawn"].as_str().unwrap_or("default");
                if target["spawns"].get(spawn).is_none() {
                    problems.push_str(&format!(
                        "  {from} sends the player to {to} spawn {spawn:?}, which {to} does not define\n"
                    ));
                }
            }
        }
    }

    assert!(
        checked > 0,
        "no portal pointed at a shipped world; the worlds are disconnected"
    );
    assert!(
        problems.is_empty(),
        "dead ends between shipped worlds:\n{problems}"
    );
}

/// A repository convention, not a protocol rule.
///
/// The protocol says nothing about directories: a package could be a zip, an HTTP response,
/// or anything else. But inside *this* repository a world lives in a directory, and if the
/// directory is called one thing while the world calls itself another, the registry
/// publishes under an id that does not appear anywhere in the tree. A contributor renaming
/// their folder and not the `id` -- or the reverse -- is an easy mistake and an annoying one
/// to trace, so it is caught here rather than left to a reviewer's eye.
#[test]
fn every_world_directory_is_named_after_the_world_it_holds() {
    let worlds = repo_root().join("worlds");
    let mut dirs: Vec<PathBuf> = std::fs::read_dir(&worlds)
        .expect("worlds/ should exist")
        .flatten()
        .map(|e| e.path())
        .filter(|p| p.is_dir())
        .collect();
    dirs.sort();

    let mut problems = String::new();
    for dir in &dirs {
        let folder = dir.file_name().unwrap_or_default().to_string_lossy();
        let world: serde_json::Value = serde_json::from_str(
            &std::fs::read_to_string(dir.join("world.json")).expect("readable"),
        )
        .expect("json");
        let id = world["id"].as_str().unwrap_or_default();
        if id != folder {
            problems.push_str(&format!("  worlds/{folder}/ declares id {id:?}\n"));
        }
    }
    assert!(
        problems.is_empty(),
        "directory and world id disagree:\n{problems}"
    );
}

/// A contributor's world must not quietly take over an id another world already uses.
///
/// Item ids are namespaced by their defining world (SPEC §3.2), so two worlds sharing an id
/// would also share an item namespace, and a save could no longer say which one it meant.
#[test]
fn no_two_shipped_worlds_claim_the_same_id() {
    let worlds = repo_root().join("worlds");
    let mut seen: std::collections::BTreeMap<String, String> = std::collections::BTreeMap::new();
    let mut problems = String::new();

    let mut dirs: Vec<PathBuf> = std::fs::read_dir(&worlds)
        .expect("worlds/ should exist")
        .flatten()
        .map(|e| e.path())
        .filter(|p| p.is_dir())
        .collect();
    dirs.sort();

    for dir in &dirs {
        let folder = dir
            .file_name()
            .unwrap_or_default()
            .to_string_lossy()
            .to_string();
        let world: serde_json::Value = serde_json::from_str(
            &std::fs::read_to_string(dir.join("world.json")).expect("readable"),
        )
        .expect("json");
        let id = world["id"].as_str().unwrap_or_default().to_string();
        if let Some(first) = seen.get(&id) {
            problems.push_str(&format!(
                "  {id:?} is claimed by both {first} and {folder}\n"
            ));
        } else {
            seen.insert(id, folder);
        }
    }
    assert!(problems.is_empty(), "duplicate world ids:\n{problems}");
}

/// A spawn must not sit inside something solid.
///
/// Arriving inside a wall is the worst kind of world bug: the package validates, the client
/// loads it, and the player is simply stuck with nothing to read. It is also easy to create
/// by moving a building and forgetting the spawn it used to sit beside.
///
/// This does not check that anywhere is *reachable* -- that is a pathfinding question and a
/// house in the way is a design decision, not an error. It checks the one case that is
/// never a decision.
#[test]
fn no_spawn_point_sits_inside_something_solid() {
    const PLAYER: i64 = 16;

    let worlds = repo_root().join("worlds");
    let mut dirs: Vec<PathBuf> = std::fs::read_dir(&worlds)
        .expect("worlds/ should exist")
        .flatten()
        .map(|e| e.path())
        .filter(|p| p.is_dir())
        .collect();
    dirs.sort();

    let mut problems = String::new();
    let mut checked = 0;

    for dir in &dirs {
        let doc: Value = serde_json::from_str(
            &std::fs::read_to_string(dir.join("world.json")).expect("readable"),
        )
        .expect("json");
        let world_id = doc["id"].as_str().unwrap_or_default();

        // Every solid rectangle in the world, in absolute coordinates.
        let mut solids: Vec<(i64, i64, i64, i64)> = Vec::new();
        for entity in doc["entities"].as_array().into_iter().flatten() {
            let ax = entity["at"][0].as_i64().unwrap_or(0);
            let ay = entity["at"][1].as_i64().unwrap_or(0);
            for component in entity["components"].as_array().into_iter().flatten() {
                if component["type"] != "solid" {
                    continue;
                }
                let ox = component["offset"][0].as_i64().unwrap_or(0);
                let oy = component["offset"][1].as_i64().unwrap_or(0);
                let w = component["size"][0].as_i64().unwrap_or(0);
                let h = component["size"][1].as_i64().unwrap_or(0);
                solids.push((ax + ox, ay + oy, w, h));
            }
        }

        for (name, spawn) in doc["spawns"].as_object().into_iter().flatten() {
            let sx = spawn["at"][0].as_i64().unwrap_or(0);
            let sy = spawn["at"][1].as_i64().unwrap_or(0);
            checked += 1;

            for (x, y, w, h) in &solids {
                let overlaps = sx < x + w && *x < sx + PLAYER && sy < y + h && *y < sy + PLAYER;
                if overlaps {
                    problems.push_str(&format!(
                        "  {world_id} spawn {name:?} at [{sx}, {sy}] is inside a solid at \
                         [{x}, {y}] {w}x{h}\n"
                    ));
                }
            }
        }
    }

    assert!(checked >= 2, "expected several spawns, checked {checked}");
    assert!(problems.is_empty(), "spawns inside walls:\n{problems}");
}
