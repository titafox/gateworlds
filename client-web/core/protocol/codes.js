// The validation error taxonomy from `protocol/SPEC.md` §11.
//
// A direct counterpart to `server/crates/gateworlds-protocol/src/error.rs` and
// `client-godot/core/protocol/codes.gd`. Three implementations are kept structurally
// parallel on purpose: ADR-0001 §4 rests on them agreeing, and agreement is easier to audit
// when the files can be read side by side.

export const SCHEMA_VIOLATION = 'schema_violation';
export const UNSUPPORTED_PROTOCOL_VERSION = 'unsupported_protocol_version';
export const UNKNOWN_COMPONENT_TYPE = 'unknown_component_type';
export const UNKNOWN_FIELD = 'unknown_field';
export const INVALID_RESOURCE_PATH = 'invalid_resource_path';
export const RESOURCE_NOT_FOUND = 'resource_not_found';
export const DUPLICATE_ID = 'duplicate_id';
export const UNRESOLVED_REFERENCE = 'unresolved_reference';
export const INVALID_ITEM_NAMESPACE = 'invalid_item_namespace';
export const VALUE_OUT_OF_RANGE = 'value_out_of_range';

/// `schema_violation` is the fallback code. SPEC §11: where more than one code could apply,
/// the more specific one wins.
export function isSpecific(code) {
  return code !== SCHEMA_VIOLATION;
}

/// True when `maybeAncestor` points at a location containing `descendant`.
///
/// Compared segment-wise, not as a raw string prefix: `/entities/1` must not be treated as
/// an ancestor of `/entities/10`.
export function isAncestor(maybeAncestor, descendant) {
  if (maybeAncestor === '') return descendant !== '';
  return (
    descendant.length > maybeAncestor.length &&
    descendant.startsWith(maybeAncestor) &&
    descendant[maybeAncestor.length] === '/'
  );
}

/// Escapes a property name for use in an RFC 6901 JSON Pointer.
export function escapeSegment(segment) {
  return String(segment).replaceAll('~', '~0').replaceAll('/', '~1');
}
