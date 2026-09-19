//! Validator for the Gateworlds world protocol.
//!
//! The normative definition lives in `protocol/SPEC.md`; this crate implements it and
//! nothing more. It has no engine dependency and no web dependency, so a server, a CLI, a
//! CI job or a future host can all reuse it.
//!
//! Per `docs/adr/0001-engine-neutrality.md`, this is one of two independent implementations
//! of the same specification. Two implementations agreeing on the conformance vectors is
//! evidence of engine neutrality; one implementation is just a habit.

pub mod conformance;
pub mod error;
pub mod respath;
pub mod schema;
pub mod validate;
pub mod version;

pub use error::{ErrorCode, Finding, Report};
pub use schema::DocKind;
pub use validate::{COMPONENT_TYPES, Context, context_for_file, validate, validate_package};
pub use version::{PROTOCOL_VERSION, PROTOCOL_VERSION_STRING, Version};
