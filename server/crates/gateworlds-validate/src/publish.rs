//! Builds a static registry tree from validated world packages.
//!
//! There is no long-running service here on purpose. The registry is a directory of files
//! that any web server can hand out: nothing to crash, nothing listening, nothing to
//! exploit. `docs/adr/0001-engine-neutrality.md` §4 asks the server to be the first gate on
//! ingest, and this is where that gate sits -- a package that does not validate is never
//! written to the output at all.

use std::path::{Path, PathBuf};

use gateworlds_protocol::{Report, validate_package};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

pub const REGISTRY_VERSION: &str = "0.1.0";

pub struct Outcome {
    pub published: Vec<String>,
    pub rejected: Vec<(String, Report)>,
}

impl Outcome {
    pub fn ok(&self) -> bool {
        self.rejected.is_empty() && !self.published.is_empty()
    }
}

/// Validates every package under `src_dir` and writes the ones that pass to `out_dir`.
///
/// The output is replaced wholesale rather than merged: a registry that accumulates files
/// nobody meant to publish is how a world that was withdrawn stays reachable.
pub fn build(src_dir: &Path, out_dir: &Path, generated_at: &str) -> Result<Outcome, String> {
    let mut dirs: Vec<PathBuf> = std::fs::read_dir(src_dir)
        .map_err(|e| format!("{}: {e}", src_dir.display()))?
        .flatten()
        .map(|e| e.path())
        .filter(|p| p.is_dir() && p.join("world.json").is_file())
        .collect();
    dirs.sort();

    if dirs.is_empty() {
        return Err(format!("no world packages under {}", src_dir.display()));
    }

    let staging = out_dir.with_extension("staging");
    let _ = std::fs::remove_dir_all(&staging);
    std::fs::create_dir_all(staging.join("v0/worlds")).map_err(|e| e.to_string())?;

    let mut outcome = Outcome {
        published: Vec::new(),
        rejected: Vec::new(),
    };
    let mut entries: Vec<Value> = Vec::new();

    for dir in &dirs {
        let name = dir
            .file_name()
            .unwrap_or_default()
            .to_string_lossy()
            .to_string();

        // The gate. A package that does not validate is not written anywhere.
        let report = validate_package(dir).map_err(|e| format!("{name}: {e}"))?;
        if !report.is_ok() {
            outcome.rejected.push((name, report));
            continue;
        }

        let world: Value = read_json(&dir.join("world.json"))?;
        let id = world
            .get("id")
            .and_then(Value::as_str)
            .unwrap_or(&name)
            .to_string();

        let dest = staging.join("v0/worlds").join(&id);
        std::fs::create_dir_all(&dest).map_err(|e| e.to_string())?;

        let mut files: Vec<Value> = Vec::new();
        for rel in package_files(dir)? {
            let from = dir.join(&rel);
            let to = dest.join(&rel);
            if let Some(parent) = to.parent() {
                std::fs::create_dir_all(parent).map_err(|e| e.to_string())?;
            }
            let bytes = std::fs::read(&from).map_err(|e| format!("{}: {e}", from.display()))?;
            std::fs::write(&to, &bytes).map_err(|e| format!("{}: {e}", to.display()))?;
            files.push(json!({
                "path": rel,
                "size": bytes.len(),
                "sha256": hex(&Sha256::digest(&bytes)),
            }));
        }

        let manifest = json!({
            "registry_version": REGISTRY_VERSION,
            "protocol_version": world.get("protocol_version"),
            "id": id,
            "display_name": world.get("display_name"),
            "description": world.get("description"),
            "license": world.get("license"),
            "files": files,
        });
        let manifest_bytes = to_pretty(&manifest);
        std::fs::write(dest.join("manifest.json"), &manifest_bytes).map_err(|e| e.to_string())?;

        entries.push(json!({
            "id": id,
            "display_name": world.get("display_name"),
            "manifest": format!("v0/worlds/{id}/manifest.json"),
            // Checking this one hash is enough to detect any change to the package: every
            // file's hash is inside the manifest.
            "sha256": hex(&Sha256::digest(&manifest_bytes)),
        }));
        outcome.published.push(id);
    }

    let index = json!({
        "registry_version": REGISTRY_VERSION,
        "protocol_version": gateworlds_protocol::PROTOCOL_VERSION_STRING,
        "generated_at": generated_at,
        "worlds": entries,
    });
    std::fs::write(staging.join("v0/index.json"), to_pretty(&index)).map_err(|e| e.to_string())?;

    // Swap last, so a reader never sees a half-written registry.
    let previous = out_dir.with_extension("previous");
    let _ = std::fs::remove_dir_all(&previous);
    if out_dir.exists() {
        std::fs::rename(out_dir, &previous).map_err(|e| e.to_string())?;
    }
    std::fs::rename(&staging, out_dir).map_err(|e| e.to_string())?;
    let _ = std::fs::remove_dir_all(&previous);

    Ok(outcome)
}

/// Every file in the package, relative to its root, sorted for a reproducible manifest.
fn package_files(dir: &Path) -> Result<Vec<String>, String> {
    let mut out = Vec::new();
    walk(dir, dir, &mut out)?;
    out.sort();
    Ok(out)
}

fn walk(root: &Path, at: &Path, out: &mut Vec<String>) -> Result<(), String> {
    for entry in std::fs::read_dir(at)
        .map_err(|e| format!("{}: {e}", at.display()))?
        .flatten()
    {
        let p = entry.path();
        // Symlinks are not followed: a package must carry its own bytes, and following one
        // out of the package would publish something the validator never checked.
        let meta = std::fs::symlink_metadata(&p).map_err(|e| e.to_string())?;
        if meta.file_type().is_symlink() {
            continue;
        }
        if meta.is_dir() {
            walk(root, &p, out)?;
        } else if let Ok(rel) = p.strip_prefix(root) {
            out.push(rel.to_string_lossy().replace('\\', "/"));
        }
    }
    Ok(())
}

fn read_json(p: &Path) -> Result<Value, String> {
    let raw = std::fs::read_to_string(p).map_err(|e| format!("{}: {e}", p.display()))?;
    serde_json::from_str(&raw).map_err(|e| format!("{}: {e}", p.display()))
}

fn to_pretty(v: &Value) -> Vec<u8> {
    let mut s = serde_json::to_string_pretty(v).unwrap_or_default();
    s.push('\n');
    s.into_bytes()
}

fn hex(bytes: &[u8]) -> String {
    let mut s = String::with_capacity(bytes.len() * 2);
    for b in bytes {
        s.push_str(&format!("{b:02x}"));
    }
    s
}
