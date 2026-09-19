//! Resource path rules from `protocol/SPEC.md` §5.
//!
//! The character rules reject engine URI schemes (`res://`), Windows absolute paths
//! (`C:\`), URLs (`https://`) and UNC paths *by construction* rather than by blacklist --
//! none of `:`, `\` or a leading `/` survives the allowed character set, so there is no
//! list of bad prefixes to keep up to date.

use std::path::Path;

/// Why a path was rejected. Carried into the finding's detail so a creator can act on it.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PathReject {
    Empty,
    TooLong,
    BadFirstCharacter,
    DisallowedCharacter(char),
    ParentSegment,
    EmptySegment,
    TrailingSlashOrDot,
}

impl PathReject {
    pub fn describe(self) -> String {
        match self {
            Self::Empty => "path is empty".into(),
            Self::TooLong => "path exceeds 255 characters".into(),
            Self::BadFirstCharacter => {
                "must start with a letter, digit or underscore (this rejects absolute paths)".into()
            }
            Self::DisallowedCharacter(c) => format!(
                "character {c:?} is not allowed (this rejects URI schemes, drive letters and backslashes)"
            ),
            Self::ParentSegment => "contains a '..' segment, which would escape the package".into(),
            Self::EmptySegment => "contains an empty segment ('//')".into(),
            Self::TrailingSlashOrDot => "must not end with '/' or '.'".into(),
        }
    }
}

const MAX_LEN: usize = 255;

/// Checks the syntactic rules. Containment against a real package root is a separate,
/// filesystem-dependent check -- see [`resolves_inside`].
pub fn check(path: &str) -> Result<(), PathReject> {
    if path.is_empty() {
        return Err(PathReject::Empty);
    }
    if path.len() > MAX_LEN {
        return Err(PathReject::TooLong);
    }

    let mut chars = path.chars();
    let first = chars.next().expect("non-empty");
    if !(first.is_ascii_alphanumeric() || first == '_') {
        return Err(PathReject::BadFirstCharacter);
    }
    for c in chars {
        let ok = c.is_ascii_alphanumeric() || matches!(c, '_' | '-' | '.' | '/');
        if !ok {
            return Err(PathReject::DisallowedCharacter(c));
        }
    }

    if path.ends_with('/') || path.ends_with('.') {
        return Err(PathReject::TrailingSlashOrDot);
    }
    for segment in path.split('/') {
        if segment.is_empty() {
            return Err(PathReject::EmptySegment);
        }
        if segment == ".." {
            return Err(PathReject::ParentSegment);
        }
    }
    Ok(())
}

/// Resolves `rel` against `root` and reports whether the real path stays inside.
///
/// SPEC §5 requires symlinks to be resolved *before* the containment check: a path can
/// satisfy every character rule and still point outside via a symlink. Returns `None` when
/// the file does not exist, which the caller reports as `resource_not_found` rather than as
/// a containment failure -- a missing file and an escaping file are different mistakes.
pub fn resolves_inside(root: &Path, rel: &str) -> Option<bool> {
    let real_root = root.canonicalize().ok()?;
    let target = real_root.join(rel).canonicalize().ok()?;
    Some(target.starts_with(&real_root))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_ordinary_package_paths() {
        for p in [
            "art/e.png",
            "a",
            "icons/herb.png",
            "a/b/c/d_e-f.2.png",
            "_private/x.ogg",
        ] {
            assert!(check(p).is_ok(), "should accept {p:?}: {:?}", check(p));
        }
    }

    #[test]
    fn rejects_the_five_escape_shapes_the_vectors_cover() {
        assert_eq!(
            check("../../../etc/passwd"),
            Err(PathReject::BadFirstCharacter)
        );
        assert_eq!(check("/etc/passwd"), Err(PathReject::BadFirstCharacter));
        assert_eq!(
            check("res://core/save_manager.gd"),
            Err(PathReject::DisallowedCharacter(':'))
        );
        assert_eq!(
            check("https://example.invalid/p.png"),
            Err(PathReject::DisallowedCharacter(':'))
        );
        assert_eq!(
            check("C:\\Windows\\System32"),
            Err(PathReject::DisallowedCharacter(':'))
        );
    }

    #[test]
    fn rejects_traversal_that_does_not_start_the_path() {
        assert_eq!(
            check("art/../../secret.png"),
            Err(PathReject::ParentSegment)
        );
    }

    #[test]
    fn rejects_empty_segments_and_trailing_junk() {
        assert_eq!(check("art//e.png"), Err(PathReject::EmptySegment));
        assert_eq!(check("art/"), Err(PathReject::TrailingSlashOrDot));
        assert_eq!(check("art/e."), Err(PathReject::TrailingSlashOrDot));
    }

    #[test]
    fn rejects_empty_and_overlong() {
        assert_eq!(check(""), Err(PathReject::Empty));
        assert_eq!(check(&"a".repeat(256)), Err(PathReject::TooLong));
        assert!(check(&"a".repeat(255)).is_ok());
    }

    #[test]
    fn single_dot_segment_is_allowed_by_character_rules_but_is_not_traversal() {
        // "./x" fails on the first character, so the degenerate form never reaches
        // containment checking.
        assert_eq!(check("./x.png"), Err(PathReject::BadFirstCharacter));
    }
}
