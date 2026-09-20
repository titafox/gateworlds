// Resource path rules from `protocol/SPEC.md` §5.
//
// The character rules reject engine URI schemes (`res://`), Windows absolute paths (`C:\`),
// URLs (`https://`) and UNC paths *by construction* rather than by blacklist -- none of
// `:`, `\` or a leading `/` survives the allowed character set, so there is no list of bad
// prefixes to keep up to date.

const MAX_LEN = 255;

export const OK = '';
export const EMPTY = 'path is empty';
export const TOO_LONG = 'path exceeds 255 characters';
export const BAD_FIRST =
  'must start with a letter, digit or underscore (this rejects absolute paths)';
export const PARENT_SEGMENT = "contains a '..' segment, which would escape the package";
export const EMPTY_SEGMENT = "contains an empty segment ('//')";
export const TRAILING = "must not end with '/' or '.'";

const isAlnum = (c) => /^[A-Za-z0-9]$/.test(c);

/// Returns '' when the path is acceptable, otherwise a reason. Containment against a real
/// package root is a separate, filesystem-dependent check.
export function check(path) {
  if (typeof path !== 'string' || path.length === 0) return EMPTY;
  if (path.length > MAX_LEN) return TOO_LONG;

  if (!(isAlnum(path[0]) || path[0] === '_')) return BAD_FIRST;
  for (const c of path.slice(1)) {
    if (!(isAlnum(c) || c === '_' || c === '-' || c === '.' || c === '/')) {
      return `character "${c}" is not allowed (this rejects URI schemes, drive letters and backslashes)`;
    }
  }

  if (path.endsWith('/') || path.endsWith('.')) return TRAILING;
  for (const segment of path.split('/')) {
    if (segment === '') return EMPTY_SEGMENT;
    if (segment === '..') return PARENT_SEGMENT;
  }
  return OK;
}
