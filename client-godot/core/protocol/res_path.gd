extends RefCounted
## Resource path rules from `protocol/SPEC.md` §5.
##
## Counterpart to `server/crates/gateworlds-protocol/src/respath.rs`.
##
## The character rules reject engine URI schemes (`res://`), Windows absolute paths (`C:\`),
## URLs (`https://`) and UNC paths *by construction* rather than by blacklist -- none of
## ":", "\" or a leading "/" survives the allowed character set, so there is no list of bad
## prefixes to keep up to date.

const MAX_LEN := 255

const OK := ""
const EMPTY := "path is empty"
const TOO_LONG := "path exceeds 255 characters"
const BAD_FIRST := "must start with a letter, digit or underscore (this rejects absolute paths)"
const PARENT_SEGMENT := "contains a '..' segment, which would escape the package"
const EMPTY_SEGMENT := "contains an empty segment ('//')"
const TRAILING := "must not end with '/' or '.'"


static func _is_ascii_alnum(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9")


## Checks the syntactic rules. Returns "" when the path is acceptable, otherwise a reason.
## Containment against a real package root is a separate, filesystem-dependent check.
static func check(path: String) -> String:
	if path.is_empty():
		return EMPTY
	if path.length() > MAX_LEN:
		return TOO_LONG

	var first := path[0]
	if not (_is_ascii_alnum(first) or first == "_"):
		return BAD_FIRST

	for i in range(1, path.length()):
		var c := path[i]
		if not (_is_ascii_alnum(c) or c == "_" or c == "-" or c == "." or c == "/"):
			return (
				'character "%s" is not allowed (this rejects URI schemes, drive letters '
				+ "and backslashes)"
			) % c

	if path.ends_with("/") or path.ends_with("."):
		return TRAILING

	for segment in path.split("/", true):
		if segment.is_empty():
			return EMPTY_SEGMENT
		if segment == "..":
			return PARENT_SEGMENT

	return OK
