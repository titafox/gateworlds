//! The version acceptance rule from `protocol/SPEC.md` §2.2.

use crate::error::{ErrorCode, Finding};

/// The protocol version this implementation implements.
pub const PROTOCOL_VERSION: Version = Version {
    major: 0,
    minor: 1,
    patch: 0,
};

/// The same value as written in documents. Kept beside the struct so the two cannot drift;
/// a unit test asserts they agree.
pub const PROTOCOL_VERSION_STRING: &str = "0.1.0";

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Version {
    pub major: u64,
    pub minor: u64,
    pub patch: u64,
}

impl Version {
    /// SPEC §2.1: three non-negative integers, no leading zeros, no pre-release or build
    /// metadata. Deliberately stricter than general semver -- the protocol has no use for
    /// the extra forms, and accepting them would create two spellings of one version.
    pub fn parse(s: &str) -> Option<Self> {
        let mut it = s.split('.');
        let (a, b, c) = (it.next()?, it.next()?, it.next()?);
        if it.next().is_some() {
            return None;
        }
        Some(Self {
            major: part(a)?,
            minor: part(b)?,
            patch: part(c)?,
        })
    }

    /// SPEC §2.2. Pre-1.0 the minor version is treated as breaking: a 0.1 implementation
    /// must not silently accept a 0.2 document it does not understand.
    pub fn accepts(self, doc: Self) -> bool {
        if doc.major != self.major {
            return false;
        }
        if self.major == 0 {
            doc.minor == self.minor
        } else {
            doc.minor <= self.minor
        }
    }
}

fn part(s: &str) -> Option<u64> {
    if s.is_empty() || (s.len() > 1 && s.starts_with('0')) || !s.bytes().all(|b| b.is_ascii_digit())
    {
        return None;
    }
    s.parse().ok()
}

/// Checks the version field of a document. Returns `Err` when validation must stop: once the
/// version is unsupported, every other check is being run against a document shape this
/// implementation does not claim to understand, so continuing would produce noise.
pub fn check(doc: &serde_json::Value, field: &str) -> Result<(), Finding> {
    let path = format!("/{field}");
    let Some(raw) = doc.get(field).and_then(|v| v.as_str()) else {
        // Missing or non-string: let the schema report it as a schema_violation instead.
        return Ok(());
    };
    let Some(v) = Version::parse(raw) else {
        return Err(Finding::new(
            ErrorCode::UnsupportedProtocolVersion,
            path,
            format!("{raw:?} is not a MAJOR.MINOR.PATCH version"),
        ));
    };
    if PROTOCOL_VERSION.accepts(v) {
        Ok(())
    } else {
        Err(Finding::new(
            ErrorCode::UnsupportedProtocolVersion,
            path,
            format!(
                "document declares {raw}; this implementation implements {}.{}.{}",
                PROTOCOL_VERSION.major, PROTOCOL_VERSION.minor, PROTOCOL_VERSION.patch
            ),
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn v(s: &str) -> Version {
        Version::parse(s).unwrap()
    }

    #[test]
    fn the_string_and_the_struct_agree() {
        assert_eq!(
            Version::parse(PROTOCOL_VERSION_STRING),
            Some(PROTOCOL_VERSION)
        );
    }

    #[test]
    fn rejects_malformed_versions() {
        for s in [
            "1",
            "1.2",
            "1.2.3.4",
            "01.2.3",
            "1.02.3",
            "1.2.3-rc1",
            "1.2.3+build",
            "a.b.c",
            "",
        ] {
            assert!(Version::parse(s).is_none(), "should reject {s:?}");
        }
    }

    #[test]
    fn pre_1_0_treats_minor_as_breaking() {
        let me = v("0.1.0");
        assert!(me.accepts(v("0.1.0")));
        assert!(me.accepts(v("0.1.7")), "patch is ignored");
        assert!(!me.accepts(v("0.2.0")), "a 0.1 validator must reject 0.2");
        assert!(!me.accepts(v("0.0.9")));
        assert!(!me.accepts(v("1.0.0")));
    }

    #[test]
    fn post_1_0_accepts_older_minors_only() {
        let me = v("1.4.0");
        assert!(me.accepts(v("1.0.0")));
        assert!(me.accepts(v("1.4.9")));
        assert!(!me.accepts(v("1.5.0")));
        assert!(!me.accepts(v("2.0.0")));
        assert!(!me.accepts(v("0.9.0")));
    }
}
