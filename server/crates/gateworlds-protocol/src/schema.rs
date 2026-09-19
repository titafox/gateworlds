//! JSON Schema validation, and the mapping from schema errors onto the SPEC §11 taxonomy.
//!
//! The schema files are embedded with `include_str!` from `protocol/`. That is deliberate:
//! the binary cannot drift from the specification, because a change to a schema forces a
//! recompile, and a deleted schema breaks the build.

use std::sync::OnceLock;

use jsonschema::Validator;
use serde_json::Value;

use crate::error::{ErrorCode, Finding};

pub const WORLD_SCHEMA: &str = include_str!("../../../../protocol/world-v0.1.schema.json");
pub const ITEMS_SCHEMA: &str = include_str!("../../../../protocol/items-v0.1.schema.json");
pub const SAVE_SCHEMA: &str = include_str!("../../../../protocol/save-v0.1.schema.json");

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DocKind {
    World,
    Items,
    Save,
}

impl DocKind {
    pub fn parse(s: &str) -> Option<Self> {
        match s {
            "world" => Some(Self::World),
            "items" => Some(Self::Items),
            "save" => Some(Self::Save),
            _ => None,
        }
    }

    pub fn as_str(self) -> &'static str {
        match self {
            Self::World => "world",
            Self::Items => "items",
            Self::Save => "save",
        }
    }

    /// The field carrying this document's version. SPEC §2.
    pub fn version_field(self) -> &'static str {
        match self {
            Self::World | Self::Items => "protocol_version",
            Self::Save => "save_version",
        }
    }

    fn source(self) -> &'static str {
        match self {
            Self::World => WORLD_SCHEMA,
            Self::Items => ITEMS_SCHEMA,
            Self::Save => SAVE_SCHEMA,
        }
    }

    fn validator(self) -> &'static Validator {
        static CELLS: [OnceLock<Validator>; 3] =
            [OnceLock::new(), OnceLock::new(), OnceLock::new()];
        let idx = match self {
            Self::World => 0,
            Self::Items => 1,
            Self::Save => 2,
        };
        CELLS[idx].get_or_init(|| {
            let schema: Value = serde_json::from_str(self.source())
                .expect("embedded schema is not valid JSON -- the build should have caught this");
            jsonschema::validator_for(&schema).expect("embedded schema is not a valid JSON Schema")
        })
    }
}

/// Escapes a property name for use in an RFC 6901 JSON Pointer.
fn escape(segment: &str) -> String {
    segment.replace('~', "~0").replace('/', "~1")
}

/// Runs the schema and maps each error onto the taxonomy.
///
/// Only one schema error kind gets a specific code: `additionalProperties` becomes
/// `unknown_field`, because SPEC §9 leans on it -- a package trying to smuggle a behaviour
/// hook fails validation rather than being quietly stripped, and the creator deserves to be
/// told which field did it. Everything else is `schema_violation`, and may later be
/// suppressed by a more specific procedural finding (SPEC §11).
pub fn validate(kind: DocKind, doc: &Value) -> Vec<Finding> {
    let mut out = Vec::new();
    for err in kind.validator().iter_errors(doc) {
        let at = err.instance_path.to_string();
        match &err.kind {
            jsonschema::error::ValidationErrorKind::AdditionalProperties { unexpected } => {
                for name in unexpected {
                    let path = format!("{at}/{}", escape(name));
                    out.push(Finding::new(
                        ErrorCode::UnknownField,
                        path,
                        format!(
                            "{name:?} is not defined by the {} schema; unknown fields are \
                             rejected, never ignored (SPEC §9)",
                            kind.as_str()
                        ),
                    ));
                }
            }
            _ => out.push(Finding::new(
                ErrorCode::SchemaViolation,
                at,
                err.to_string(),
            )),
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn all_three_embedded_schemas_compile() {
        for k in [DocKind::World, DocKind::Items, DocKind::Save] {
            let _ = k.validator();
        }
    }

    #[test]
    fn additional_property_becomes_unknown_field_at_the_offending_path() {
        let doc = serde_json::json!({
            "protocol_version": "0.1.0", "id": "w", "display_name": {"en": "W"},
            "bounds": {"width": 64, "height": 64},
            "spawns": {"default": {"at": [0, 0]}}, "entities": [],
            "difficulty": "hard"
        });
        let f = validate(DocKind::World, &doc);
        assert_eq!(f.len(), 1, "{f:?}");
        assert_eq!(f[0].code, ErrorCode::UnknownField);
        assert_eq!(f[0].path, "/difficulty");
    }

    #[test]
    fn pointer_escaping_follows_rfc_6901() {
        assert_eq!(escape("a/b"), "a~1b");
        assert_eq!(escape("a~b"), "a~0b");
        assert_eq!(escape("plain"), "plain");
    }
}
