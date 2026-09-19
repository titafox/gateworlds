//! The validation error taxonomy from `protocol/SPEC.md` §11.
//!
//! These codes are normative. The conformance vectors assert on them, which is what holds
//! this implementation and the client implementation to the same taxonomy.

use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum ErrorCode {
    SchemaViolation,
    UnsupportedProtocolVersion,
    UnknownComponentType,
    UnknownField,
    InvalidResourcePath,
    ResourceNotFound,
    DuplicateId,
    UnresolvedReference,
    InvalidItemNamespace,
    ValueOutOfRange,
}

impl ErrorCode {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::SchemaViolation => "schema_violation",
            Self::UnsupportedProtocolVersion => "unsupported_protocol_version",
            Self::UnknownComponentType => "unknown_component_type",
            Self::UnknownField => "unknown_field",
            Self::InvalidResourcePath => "invalid_resource_path",
            Self::ResourceNotFound => "resource_not_found",
            Self::DuplicateId => "duplicate_id",
            Self::UnresolvedReference => "unresolved_reference",
            Self::InvalidItemNamespace => "invalid_item_namespace",
            Self::ValueOutOfRange => "value_out_of_range",
        }
    }

    /// `schema_violation` is the fallback code. SPEC §11: where more than one code could
    /// apply, the more specific one wins, so a specific finding suppresses a generic
    /// schema complaint about the same location.
    pub fn is_specific(self) -> bool {
        self != Self::SchemaViolation
    }
}

impl fmt::Display for ErrorCode {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}

/// A single finding. `path` is an RFC 6901 JSON Pointer into the document; `""` is the root.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Finding {
    pub code: ErrorCode,
    pub path: String,
    pub detail: String,
}

impl Finding {
    pub fn new(code: ErrorCode, path: impl Into<String>, detail: impl Into<String>) -> Self {
        Self {
            code,
            path: path.into(),
            detail: detail.into(),
        }
    }
}

impl fmt::Display for Finding {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let at = if self.path.is_empty() {
            "<root>"
        } else {
            &self.path
        };
        write!(f, "{} at {}: {}", self.code, at, self.detail)
    }
}

/// The outcome of validating one document.
#[derive(Debug, Clone, Default)]
pub struct Report {
    pub findings: Vec<Finding>,
}

impl Report {
    pub fn is_ok(&self) -> bool {
        self.findings.is_empty()
    }

    pub fn push(&mut self, f: Finding) {
        self.findings.push(f);
    }

    /// SPEC §11: report every error found, not only the first. A creator fixing one error
    /// per round trip through review is a bad experience, and a bad experience means fewer
    /// worlds.
    ///
    /// Applies the specificity rule, then sorts and dedupes so that output is stable
    /// regardless of the order checks ran in.
    pub fn finish(mut self) -> Self {
        let specific: Vec<String> = self
            .findings
            .iter()
            .filter(|f| f.code.is_specific())
            .map(|f| f.path.clone())
            .collect();

        self.findings.retain(|f| {
            f.code.is_specific()
                || !specific
                    .iter()
                    .any(|s| s == &f.path || is_ancestor(&f.path, s))
        });

        self.findings
            .sort_by(|a, b| a.path.cmp(&b.path).then(a.code.cmp(&b.code)));
        self.findings
            .dedup_by(|a, b| a.code == b.code && a.path == b.path);
        self
    }
}

/// True when `maybe_ancestor` points at a location containing `descendant`.
///
/// Compared segment-wise, not as a raw string prefix: `/entities/1` must not be treated as
/// an ancestor of `/entities/10`.
fn is_ancestor(maybe_ancestor: &str, descendant: &str) -> bool {
    if maybe_ancestor.is_empty() {
        return !descendant.is_empty();
    }
    descendant.len() > maybe_ancestor.len()
        && descendant.starts_with(maybe_ancestor)
        && descendant.as_bytes()[maybe_ancestor.len()] == b'/'
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ancestry_is_segment_wise_not_string_prefix() {
        assert!(is_ancestor("/entities/1", "/entities/1/components/0"));
        assert!(is_ancestor("", "/anything"));
        assert!(!is_ancestor("/entities/1", "/entities/10"));
        assert!(!is_ancestor("/entities/1", "/entities/1"));
        assert!(!is_ancestor("/a/b", "/a"));
    }

    #[test]
    fn specific_finding_suppresses_generic_one_at_same_path() {
        let mut r = Report::default();
        r.push(Finding::new(
            ErrorCode::SchemaViolation,
            "/entities/0/components/0/texture",
            "pattern",
        ));
        r.push(Finding::new(
            ErrorCode::InvalidResourcePath,
            "/entities/0/components/0/texture",
            "escapes package",
        ));
        let r = r.finish();
        assert_eq!(r.findings.len(), 1);
        assert_eq!(r.findings[0].code, ErrorCode::InvalidResourcePath);
    }

    #[test]
    fn specific_finding_suppresses_generic_one_at_an_ancestor_path() {
        // The schema reports a failed oneOf at the component; the specific finding is on the
        // field inside it. Keep the specific one.
        let mut r = Report::default();
        r.push(Finding::new(
            ErrorCode::SchemaViolation,
            "/entities/1/components/0",
            "oneOf",
        ));
        r.push(Finding::new(
            ErrorCode::UnknownComponentType,
            "/entities/1/components/0/type",
            "summon_dragon",
        ));
        let r = r.finish();
        assert_eq!(r.findings.len(), 1);
        assert_eq!(r.findings[0].code, ErrorCode::UnknownComponentType);
    }

    #[test]
    fn unrelated_schema_violation_survives() {
        let mut r = Report::default();
        r.push(Finding::new(
            ErrorCode::SchemaViolation,
            "/spawns",
            "missing default",
        ));
        r.push(Finding::new(
            ErrorCode::DuplicateId,
            "/entities/1/id",
            "twin",
        ));
        assert_eq!(r.finish().findings.len(), 2);
    }
}
