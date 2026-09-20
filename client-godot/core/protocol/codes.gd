extends RefCounted
## The validation error taxonomy from `protocol/SPEC.md` §11, plus the JSON Pointer helpers
## the taxonomy needs.
##
## Counterpart to `server/crates/gateworlds-protocol/src/error.rs`. The two are kept
## structurally parallel on purpose: ADR-0001 §4 rests on two independent implementations
## agreeing, and agreement is easier to audit when the code reads side by side.

const SCHEMA_VIOLATION := "schema_violation"
const UNSUPPORTED_PROTOCOL_VERSION := "unsupported_protocol_version"
const UNKNOWN_COMPONENT_TYPE := "unknown_component_type"
const UNKNOWN_FIELD := "unknown_field"
const INVALID_RESOURCE_PATH := "invalid_resource_path"
const RESOURCE_NOT_FOUND := "resource_not_found"
const DUPLICATE_ID := "duplicate_id"
const UNRESOLVED_REFERENCE := "unresolved_reference"
const INVALID_ITEM_NAMESPACE := "invalid_item_namespace"
const VALUE_OUT_OF_RANGE := "value_out_of_range"


## `schema_violation` is the fallback code. SPEC §11: where more than one code could apply,
## the more specific one wins.
static func is_specific(code: String) -> bool:
	return code != SCHEMA_VIOLATION


## True when `maybe_ancestor` points at a location containing `descendant`.
##
## Compared segment-wise, not as a raw string prefix: "/entities/1" must not be treated as
## an ancestor of "/entities/10".
static func is_ancestor(maybe_ancestor: String, descendant: String) -> bool:
	if maybe_ancestor.is_empty():
		return not descendant.is_empty()
	return (
		descendant.length() > maybe_ancestor.length()
		and descendant.begins_with(maybe_ancestor)
		and descendant[maybe_ancestor.length()] == "/"
	)


## Escapes a property name for use in an RFC 6901 JSON Pointer.
static func escape_segment(segment: String) -> String:
	return segment.replace("~", "~0").replace("/", "~1")
