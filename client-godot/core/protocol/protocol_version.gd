extends RefCounted
## The version acceptance rule from `protocol/SPEC.md` §2.2.
##
## Counterpart to `server/crates/gateworlds-protocol/src/version.rs`.

const Codes := preload("res://core/protocol/codes.gd")
const Finding := preload("res://core/protocol/finding.gd")

const MAJOR := 0
const MINOR := 1
const PATCH := 0
const VERSION_STRING := "0.1.0"


## SPEC §2.1: three non-negative integers, no leading zeros, no pre-release or build
## metadata. Deliberately stricter than general semver -- the protocol has no use for the
## extra forms, and accepting them would create two spellings of one version.
##
## Returns [major, minor, patch] or an empty array when the string is not a version.
static func parse(s: String) -> Array:
	var parts := s.split(".", true)
	if parts.size() != 3:
		return []
	var out: Array = []
	for p in parts:
		if p.is_empty():
			return []
		if p.length() > 1 and p.begins_with("0"):
			return []
		for i in p.length():
			if p[i] < "0" or p[i] > "9":
				return []
		out.append(int(p))
	return out


## SPEC §2.2. Pre-1.0 the minor version is treated as breaking: a 0.1 implementation must
## not silently accept a 0.2 document it does not understand.
static func accepts(doc: Array) -> bool:
	if doc.size() != 3:
		return false
	if doc[0] != MAJOR:
		return false
	if MAJOR == 0:
		return doc[1] == MINOR
	return doc[1] <= MINOR


## Checks the version field of a document. Returns null when fine, or a Finding when
## validation must stop: once the version is unsupported, every other check runs against a
## document shape this implementation does not claim to understand, so continuing would
## produce noise the creator cannot act on.
static func check(doc: Dictionary, field: String) -> Variant:
	var path := "/" + field
	if not doc.has(field) or typeof(doc[field]) != TYPE_STRING:
		# Missing or non-string: let the schema report it as a schema_violation instead.
		return null
	var raw: String = doc[field]
	var v := parse(raw)
	if v.is_empty():
		return Finding.new(
			Codes.UNSUPPORTED_PROTOCOL_VERSION,
			path,
			'"%s" is not a MAJOR.MINOR.PATCH version' % raw
		)
	if accepts(v):
		return null
	return Finding.new(
		Codes.UNSUPPORTED_PROTOCOL_VERSION,
		path,
		"document declares %s; this implementation implements %s" % [raw, VERSION_STRING]
	)
