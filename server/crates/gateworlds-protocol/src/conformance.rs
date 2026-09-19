//! The conformance vector runner, per `protocol/conformance/README.md`.
//!
//! It lives in the library rather than in the CLI so that the binary, `cargo test` and any
//! future host all run *one* implementation. Two copies of a runner are two things that can
//! disagree about what passing means.

use std::collections::BTreeSet;
use std::path::{Path, PathBuf};

use serde_json::Value;

use crate::error::Report;
use crate::schema::DocKind;
use crate::validate::{Context, validate};

/// One `{code, path}` pair, from a vector's expectations or from a report.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub struct Pair {
    pub code: String,
    pub path: String,
}

impl std::fmt::Display for Pair {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let at = if self.path.is_empty() {
            "<root>"
        } else {
            &self.path
        };
        write!(f, "{} at {}", self.code, at)
    }
}

#[derive(Debug)]
pub struct Outcome {
    pub name: String,
    pub failure: Option<String>,
    pub report: Option<Report>,
}

impl Outcome {
    pub fn passed(&self) -> bool {
        self.failure.is_none()
    }
}

/// Runs every `*.json` under `<dir>/valid` and `<dir>/invalid`, in a stable order.
pub fn run_dir(dir: &Path) -> Result<Vec<Outcome>, String> {
    let mut files = Vec::new();
    for sub in ["valid", "invalid"] {
        let d = dir.join(sub);
        let entries =
            std::fs::read_dir(&d).map_err(|e| format!("cannot read {}: {e}", d.display()))?;
        let mut batch: Vec<PathBuf> = entries
            .flatten()
            .map(|e| e.path())
            .filter(|p| p.extension().is_some_and(|x| x == "json"))
            .collect();
        batch.sort();
        files.extend(batch);
    }
    if files.is_empty() {
        return Err(format!("no vectors found under {}", dir.display()));
    }
    Ok(files.iter().map(|p| run_one(p)).collect())
}

fn run_one(path: &Path) -> Outcome {
    let name = path
        .file_name()
        .unwrap_or_default()
        .to_string_lossy()
        .to_string();
    match evaluate(path) {
        Ok(report) => Outcome {
            name,
            failure: None,
            report: Some(report),
        },
        Err((why, report)) => Outcome {
            name,
            failure: Some(why),
            report,
        },
    }
}

type Failure = (String, Option<Report>);

fn evaluate(path: &Path) -> Result<Report, Failure> {
    let bail = |m: String| -> Failure { (m, None) };

    let raw = std::fs::read_to_string(path).map_err(|e| bail(format!("unreadable: {e}")))?;
    let vector: Value =
        serde_json::from_str(&raw).map_err(|e| bail(format!("vector is not valid JSON: {e}")))?;

    let meta = vector
        .get("$vector")
        .ok_or_else(|| bail("missing $vector".into()))?;
    let doc = vector
        .get("document")
        .ok_or_else(|| bail("missing document".into()))?;

    let kind_str = meta
        .get("kind")
        .and_then(Value::as_str)
        .ok_or_else(|| bail("missing $vector.kind".into()))?;
    let kind =
        DocKind::parse(kind_str).ok_or_else(|| bail(format!("unknown kind {kind_str:?}")))?;

    let expect_valid = match meta.get("expect").and_then(Value::as_str) {
        Some("valid") => true,
        Some("invalid") => false,
        other => return Err(bail(format!("bad $vector.expect: {other:?}"))),
    };
    let exhaustive = meta
        .get("exhaustive")
        .and_then(Value::as_bool)
        .unwrap_or(false);

    // The context is stated by the vector, never inferred from `expect`. A runner that
    // decided how to validate by looking at the expected outcome would argue in a circle and
    // pass its own vectors no matter what the validator did.
    let ctx_node = meta.get("context");
    let mut ctx = Context::default();
    if let Some(w) = ctx_node
        .and_then(|c| c.get("world_id"))
        .and_then(Value::as_str)
        .or_else(|| doc.get("id").and_then(Value::as_str))
    {
        ctx = ctx.with_world_id(w);
    }
    if let Some(items) = ctx_node
        .and_then(|c| c.get("items"))
        .and_then(Value::as_array)
    {
        ctx = ctx.with_items(items.iter().filter_map(Value::as_str).map(str::to_owned));
    }

    let report = validate(kind, doc, &ctx);
    let got: BTreeSet<Pair> = report
        .findings
        .iter()
        .map(|f| Pair {
            code: f.code.as_str().into(),
            path: f.path.clone(),
        })
        .collect();

    if expect_valid {
        return if report.is_ok() {
            Ok(report)
        } else {
            Err(("expected no findings".into(), Some(report)))
        };
    }

    let want: BTreeSet<Pair> = meta
        .get("errors")
        .and_then(Value::as_array)
        .map(|a| {
            a.iter()
                .map(|e| Pair {
                    code: e.get("code").and_then(Value::as_str).unwrap_or("?").into(),
                    path: e.get("path").and_then(Value::as_str).unwrap_or("").into(),
                })
                .collect()
        })
        .unwrap_or_default();

    let missing: Vec<String> = want.difference(&got).map(ToString::to_string).collect();
    let extra: Vec<String> = got.difference(&want).map(ToString::to_string).collect();

    let mut why = String::new();
    if !missing.is_empty() {
        why.push_str(&format!(
            "expected but not reported: {}",
            missing.join("; ")
        ));
    }
    if exhaustive && !extra.is_empty() {
        if !why.is_empty() {
            why.push_str(" | ");
        }
        why.push_str(&format!(
            "reported but not expected (vector is exhaustive): {}",
            extra.join("; ")
        ));
    }
    if why.is_empty() {
        Ok(report)
    } else {
        Err((why, Some(report)))
    }
}
