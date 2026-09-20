//! The ingest gate.
//!
//! ADR-0001 §4 puts the server first in line: unapproved content must not reach a client.
//! The property that matters is not "invalid packages are reported" -- it is that they are
//! **never written to the output**. A registry that reports a rejection and publishes the
//! package anyway would pass a weaker test and fail in exactly the way that matters.

use std::path::Path;

use gateworlds_validate::publish;
use serde_json::{Value, json};

fn write(path: &Path, v: &Value) {
    std::fs::create_dir_all(path.parent().unwrap()).unwrap();
    std::fs::write(path, serde_json::to_vec_pretty(v).unwrap()).unwrap();
}

fn good_world(id: &str) -> Value {
    json!({
        "protocol_version": "0.1.0",
        "id": id,
        "display_name": {"en": id},
        "bounds": {"width": 64, "height": 64},
        "spawns": {"default": {"at": [0, 0]}},
        "entities": [{
            "id": "e", "at": [8, 8],
            "components": [{"type": "sprite", "size": [4, 4], "color": "#ffffff"}]
        }]
    })
}

struct Tmp(std::path::PathBuf);
impl Drop for Tmp {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
        let _ = std::fs::remove_dir_all(self.0.with_extension("out"));
        let _ = std::fs::remove_dir_all(self.0.with_extension("out.staging"));
        let _ = std::fs::remove_dir_all(self.0.with_extension("out.previous"));
    }
}

fn tmp(tag: &str) -> Tmp {
    let p = std::env::temp_dir().join(format!("gw_publish_{tag}_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&p);
    std::fs::create_dir_all(&p).unwrap();
    Tmp(p)
}

#[test]
fn an_invalid_package_is_never_written_to_the_registry() {
    let t = tmp("gate");
    let (src, out) = (t.0.join("src"), t.0.with_extension("out"));

    write(&src.join("good/world.json"), &good_world("good"));

    // Same shape, but carrying a component type that is not in the whitelist.
    let mut bad = good_world("bad");
    bad["entities"][0]["components"][0] = json!({"type": "summon_dragon", "hp": 500});
    write(&src.join("bad/world.json"), &bad);

    let outcome = publish::build(&src, &out, "2026-01-01T00:00:00Z").expect("should run");

    assert_eq!(outcome.published, vec!["good".to_string()]);
    assert_eq!(
        outcome.rejected.len(),
        1,
        "the bad package should be rejected"
    );
    assert!(
        !outcome.ok(),
        "a run with a rejection must not report success"
    );

    assert!(
        out.join("v0/worlds/good/world.json").exists(),
        "the good world should be served"
    );
    assert!(
        !out.join("v0/worlds/bad").exists(),
        "REJECTED PACKAGE WAS PUBLISHED -- the ingest gate does not hold"
    );

    let index: Value =
        serde_json::from_str(&std::fs::read_to_string(out.join("v0/index.json")).unwrap()).unwrap();
    let ids: Vec<&str> = index["worlds"]
        .as_array()
        .unwrap()
        .iter()
        .filter_map(|w| w["id"].as_str())
        .collect();
    assert_eq!(
        ids,
        vec!["good"],
        "the index must not mention a rejected world"
    );
}

#[test]
fn hashes_in_the_manifest_match_the_bytes_that_are_served() {
    let t = tmp("hash");
    let (src, out) = (t.0.join("src"), t.0.with_extension("out"));
    write(&src.join("w/world.json"), &good_world("w"));

    publish::build(&src, &out, "2026-01-01T00:00:00Z").expect("should run");

    let manifest: Value = serde_json::from_str(
        &std::fs::read_to_string(out.join("v0/worlds/w/manifest.json")).unwrap(),
    )
    .unwrap();

    let mut checked = 0;
    for f in manifest["files"].as_array().unwrap() {
        let rel = f["path"].as_str().unwrap();
        let bytes = std::fs::read(out.join("v0/worlds/w").join(rel)).unwrap();
        let actual = {
            use sha2::{Digest, Sha256};
            Sha256::digest(&bytes)
                .iter()
                .map(|b| format!("{b:02x}"))
                .collect::<String>()
        };
        assert_eq!(
            f["sha256"].as_str().unwrap(),
            actual,
            "hash mismatch for {rel}"
        );
        assert_eq!(
            f["size"].as_u64().unwrap() as usize,
            bytes.len(),
            "size mismatch for {rel}"
        );
        checked += 1;
    }
    assert!(checked > 0, "manifest listed no files");
}

#[test]
fn a_withdrawn_world_disappears_from_the_registry() {
    let t = tmp("withdraw");
    let (src, out) = (t.0.join("src"), t.0.with_extension("out"));
    write(&src.join("keep/world.json"), &good_world("keep"));
    write(&src.join("drop/world.json"), &good_world("drop"));
    publish::build(&src, &out, "2026-01-01T00:00:00Z").unwrap();
    assert!(out.join("v0/worlds/drop").exists());

    // The output is replaced wholesale, not merged: a world that was withdrawn must stop
    // being reachable rather than linger because nobody deleted it.
    std::fs::remove_dir_all(src.join("drop")).unwrap();
    publish::build(&src, &out, "2026-01-01T00:01:00Z").unwrap();

    assert!(out.join("v0/worlds/keep").exists());
    assert!(
        !out.join("v0/worlds/drop").exists(),
        "a withdrawn world is still being served"
    );
}

/// The output is replaced wholesale, which is correct for a registry and catastrophic for
/// anything else.
///
/// Not hypothetical: during development `publish worlds client-web` was run in the belief
/// that the second argument was somewhere to put a registry *inside*, and it replaced the
/// entire web client with one. Everything not yet committed was gone. The tool's most
/// destructive behaviour is also its correct behaviour, so it has to be certain about its
/// target rather than trusting the person typing.
#[test]
fn publishing_refuses_a_directory_that_is_not_already_a_registry() {
    let t = tmp("clobber");
    let (src, out) = (t.0.join("src"), t.0.with_extension("out"));
    write(&src.join("w/world.json"), &good_world("w"));

    // Something precious, in the wrong place.
    std::fs::create_dir_all(&out).unwrap();
    std::fs::write(out.join("important.txt"), b"months of work").unwrap();

    let err = publish::build(&src, &out, "2026-01-01T00:00:00Z")
        .expect_err("publishing over a non-registry directory must fail");
    assert!(
        err.contains("does not look like a registry"),
        "unhelpful message: {err}"
    );

    assert!(
        out.join("important.txt").exists(),
        "THE TOOL DELETED FILES IT DID NOT WRITE -- this is the bug, not a detail"
    );
}

#[test]
fn publishing_twice_into_its_own_output_still_works() {
    let t = tmp("again");
    let (src, out) = (t.0.join("src"), t.0.with_extension("out"));
    write(&src.join("w/world.json"), &good_world("w"));

    publish::build(&src, &out, "2026-01-01T00:00:00Z").expect("first publish");
    // The guard must not cost the wholesale replacement that makes a withdrawn world
    // disappear, so a second run into the same place has to still be allowed.
    publish::build(&src, &out, "2026-01-01T00:01:00Z").expect("second publish");
    assert!(out.join("v0/index.json").exists());
}

#[test]
fn an_empty_directory_is_fine_to_publish_into() {
    let t = tmp("empty");
    let (src, out) = (t.0.join("src"), t.0.with_extension("out"));
    write(&src.join("w/world.json"), &good_world("w"));
    std::fs::create_dir_all(&out).unwrap();

    publish::build(&src, &out, "2026-01-01T00:00:00Z").expect("an empty directory is not precious");
    assert!(out.join("v0/index.json").exists());
}
