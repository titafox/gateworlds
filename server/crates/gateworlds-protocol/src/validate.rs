//! Procedural checks and orchestration.
//!
//! The schema catches shape. These catch the rules a schema cannot express: version
//! acceptance, the closed component whitelist, resource path containment, uniqueness,
//! reference resolution, item namespacing and bounds.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use serde_json::Value;

use crate::error::{ErrorCode, Finding, Report};
use crate::respath;
use crate::schema::{self, DocKind};
use crate::version;

/// The closed component whitelist, SPEC §7. Adding to this is a protocol change.
pub const COMPONENT_TYPES: &[&str] = &["sprite", "solid", "portal", "pickup"];

/// Facts a document cannot carry about itself. Stated explicitly by the caller -- a
/// conformance vector declares it in `$vector.context`, a package validator derives it from
/// the package on disk.
#[derive(Debug, Clone, Default)]
pub struct Context {
    /// The world that defines this document. When `None`, item-namespace checking is skipped
    /// because there is nothing to compare against.
    pub world_id: Option<String>,
    /// Item ids a `pickup` may reference.
    pub known_items: BTreeSet<String>,
    /// Package root on disk. When `None`, resource paths are checked syntactically only.
    pub package_root: Option<PathBuf>,
}

impl Context {
    pub fn with_world_id(mut self, id: impl Into<String>) -> Self {
        self.world_id = Some(id.into());
        self
    }
    pub fn with_items<I: IntoIterator<Item = S>, S: Into<String>>(mut self, items: I) -> Self {
        self.known_items = items.into_iter().map(Into::into).collect();
        self
    }
    pub fn with_root(mut self, root: impl Into<PathBuf>) -> Self {
        self.package_root = Some(root.into());
        self
    }
}

pub fn validate(kind: DocKind, doc: &Value, ctx: &Context) -> Report {
    let mut report = Report::default();

    // SPEC §2.2: stop here on an unsupported version. Every later check would be run
    // against a document shape this implementation does not claim to understand, and would
    // report noise the creator cannot act on.
    if let Err(f) = version::check(doc, kind.version_field()) {
        report.push(f);
        return report.finish();
    }

    for f in schema::validate(kind, doc) {
        report.push(f);
    }

    match kind {
        DocKind::World => check_world(doc, ctx, &mut report),
        DocKind::Items => check_items(doc, ctx, &mut report),
        DocKind::Save => check_save(doc, ctx, &mut report),
    }

    report.finish()
}

// ---------------------------------------------------------------------------- world

fn check_world(doc: &Value, ctx: &Context, r: &mut Report) {
    let bounds = doc.get("bounds").map(|b| {
        (
            b.get("width").and_then(Value::as_i64),
            b.get("height").and_then(Value::as_i64),
        )
    });

    if let Some(spawns) = doc.get("spawns").and_then(Value::as_object) {
        for (name, spawn) in spawns {
            let path = format!("/spawns/{name}/at");
            check_in_bounds(spawn.get("at"), bounds, &path, r);
        }
    }

    let Some(entities) = doc.get("entities").and_then(Value::as_array) else {
        return;
    };
    let mut seen_ids: BTreeMap<&str, usize> = BTreeMap::new();

    for (i, entity) in entities.iter().enumerate() {
        if let Some(id) = entity.get("id").and_then(Value::as_str) {
            if let Some(&first) = seen_ids.get(id) {
                r.push(Finding::new(
                    ErrorCode::DuplicateId,
                    format!("/entities/{i}/id"),
                    format!("entity id {id:?} is already used at /entities/{first}"),
                ));
            } else {
                seen_ids.insert(id, i);
            }
        }

        check_in_bounds(entity.get("at"), bounds, &format!("/entities/{i}/at"), r);

        let Some(components) = entity.get("components").and_then(Value::as_array) else {
            continue;
        };
        let mut seen_types: BTreeMap<&str, usize> = BTreeMap::new();

        for (j, comp) in components.iter().enumerate() {
            let base = format!("/entities/{i}/components/{j}");
            let Some(ty) = comp.get("type").and_then(Value::as_str) else {
                continue;
            };

            if !COMPONENT_TYPES.contains(&ty) {
                r.push(Finding::new(
                    ErrorCode::UnknownComponentType,
                    format!("{base}/type"),
                    format!(
                        "{ty:?} is not in the component whitelist ({}); the set is closed and \
                         adding to it is a protocol change (SPEC §7)",
                        COMPONENT_TYPES.join(", ")
                    ),
                ));
                continue;
            }

            if let Some(&first) = seen_types.get(ty) {
                r.push(Finding::new(
                    ErrorCode::DuplicateId,
                    format!("{base}/type"),
                    format!(
                        "this entity already carries a {ty:?} component at \
                         /entities/{i}/components/{first}; draw and trigger order would be undefined"
                    ),
                ));
            } else {
                seen_types.insert(ty, j);
            }

            if ty == "sprite" {
                check_resource(comp.get("texture"), ctx, &format!("{base}/texture"), r);
            }
            if ty == "pickup" {
                if let Some(item) = comp.get("item").and_then(Value::as_str) {
                    if !ctx.known_items.contains(item) {
                        r.push(Finding::new(
                            ErrorCode::UnresolvedReference,
                            format!("{base}/item"),
                            format!(
                                "{item:?} is not defined in this package; in 0.1.0 a pickup must \
                                 reference an item of its own package (SPEC §3.2)"
                            ),
                        ));
                    }
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------- items

fn check_items(doc: &Value, ctx: &Context, r: &mut Report) {
    let Some(items) = doc.get("items").and_then(Value::as_array) else {
        return;
    };
    let mut seen: BTreeMap<&str, usize> = BTreeMap::new();

    for (i, item) in items.iter().enumerate() {
        let path = format!("/items/{i}/id");
        if let Some(id) = item.get("id").and_then(Value::as_str) {
            if let Some(&first) = seen.get(id) {
                r.push(Finding::new(
                    ErrorCode::DuplicateId,
                    &path,
                    format!("item id {id:?} is already defined at /items/{first}"),
                ));
            } else {
                seen.insert(id, i);
            }

            // SPEC §3.2: a world may only define items in its own namespace, or one world
            // could shadow another's items.
            if let (Some(world), Some((ns, _))) = (ctx.world_id.as_deref(), id.split_once(':')) {
                if ns != world {
                    r.push(Finding::new(
                        ErrorCode::InvalidItemNamespace,
                        &path,
                        format!(
                            "namespace {ns:?} does not match the defining world {world:?}; \
                             a world may only define items in its own namespace"
                        ),
                    ));
                }
            }
        }
        check_resource(
            item.get("icon").and_then(|ic| ic.get("texture")),
            ctx,
            &format!("/items/{i}/icon/texture"),
            r,
        );
    }
}

// ---------------------------------------------------------------------------- save

fn check_save(doc: &Value, ctx: &Context, r: &mut Report) {
    let defs: BTreeSet<&str> = doc
        .get("item_defs")
        .and_then(Value::as_object)
        .map(|m| m.keys().map(String::as_str).collect())
        .unwrap_or_default();

    if let Some(stacks) = doc.pointer("/inventory/stacks").and_then(Value::as_array) {
        for (i, stack) in stacks.iter().enumerate() {
            let Some(item) = stack.get("item").and_then(Value::as_str) else {
                continue;
            };
            if !defs.contains(item) {
                r.push(Finding::new(
                    ErrorCode::UnresolvedReference,
                    format!("/inventory/stacks/{i}/item"),
                    format!(
                        "no definition for {item:?} in item_defs; a save must embed the \
                         definition of every item it holds, so that it survives its defining \
                         world being unpublished (SPEC §8.3)"
                    ),
                ));
            }
        }
    }

    if let Some(map) = doc.get("item_defs").and_then(Value::as_object) {
        for (key, def) in map {
            check_resource(
                def.get("icon").and_then(|ic| ic.get("texture")),
                ctx,
                &format!(
                    "/item_defs/{}/icon/texture",
                    key.replace('~', "~0").replace('/', "~1")
                ),
                r,
            );
        }
    }
}

// ---------------------------------------------------------------------------- shared

fn check_in_bounds(
    at: Option<&Value>,
    bounds: Option<(Option<i64>, Option<i64>)>,
    path: &str,
    r: &mut Report,
) {
    let (Some(at), Some((Some(w), Some(h)))) = (at.and_then(Value::as_array), bounds) else {
        return;
    };
    let (Some(x), Some(y)) = (
        at.first().and_then(Value::as_i64),
        at.get(1).and_then(Value::as_i64),
    ) else {
        return;
    };
    if x < 0 || y < 0 || x > w || y > h {
        r.push(Finding::new(
            ErrorCode::ValueOutOfRange,
            path,
            format!("[{x}, {y}] lies outside the world bounds {w}x{h}"),
        ));
    }
}

fn check_resource(value: Option<&Value>, ctx: &Context, path: &str, r: &mut Report) {
    let Some(rel) = value.and_then(Value::as_str) else {
        return;
    };

    if let Err(why) = respath::check(rel) {
        r.push(Finding::new(
            ErrorCode::InvalidResourcePath,
            path,
            why.describe(),
        ));
        return;
    }

    // Containment and existence need a real package on disk. A conformance vector has no
    // package, so it stops at the syntactic rules.
    let Some(root) = ctx.package_root.as_deref() else {
        return;
    };
    match respath::resolves_inside(root, rel) {
        Some(true) => {}
        Some(false) => r.push(Finding::new(
            ErrorCode::InvalidResourcePath,
            path,
            format!("{rel:?} resolves outside the package root after following symlinks"),
        )),
        None => r.push(Finding::new(
            ErrorCode::ResourceNotFound,
            path,
            format!("{rel:?} is not present in the package"),
        )),
    }
}

// ---------------------------------------------------------------------------- packages

/// Validates a world package directory: `world.json`, optional `items.json`, and the files
/// they reference. This is the check CI runs over everything under `worlds/`.
pub fn validate_package(dir: &Path) -> Result<Report, String> {
    let world_path = dir.join("world.json");
    let world: Value = read_json(&world_path)?;

    let world_id = world
        .get("id")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();

    let items_path = dir.join("items.json");
    let items: Option<Value> = if items_path.exists() {
        Some(read_json(&items_path)?)
    } else {
        None
    };

    let known: BTreeSet<String> = items
        .as_ref()
        .and_then(|v| v.get("items"))
        .and_then(Value::as_array)
        .map(|a| {
            a.iter()
                .filter_map(|i| i.get("id").and_then(Value::as_str))
                .map(str::to_owned)
                .collect()
        })
        .unwrap_or_default();

    let ctx = Context::default()
        .with_world_id(&world_id)
        .with_root(dir)
        .with_items(known);

    let mut report = validate(DocKind::World, &world, &ctx);
    if let Some(items) = items {
        let items_report = validate(DocKind::Items, &items, &ctx);
        for mut f in items_report.findings {
            f.path = format!("items.json#{}", f.path);
            report.push(f);
        }
    }
    Ok(report)
}

fn read_json(p: &Path) -> Result<Value, String> {
    let raw = std::fs::read_to_string(p).map_err(|e| format!("{}: {e}", p.display()))?;
    serde_json::from_str(&raw).map_err(|e| format!("{}: {e}", p.display()))
}
