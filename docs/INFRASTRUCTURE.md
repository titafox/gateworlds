# Infrastructure inventory

Everything outside this repository that the project depends on: what exists, who holds it,
and what a successor does if that person is unreachable.

**No secrets.** No keys, passwords or tokens belong in this file or anywhere in this
repository. This is a map, not a keyring.

Required by [SUCCESSION.md](SUCCESSION.md) §2.6. Update it in the same change that adds or
removes a dependency.

## Code hosting

| What | Where | Held by | If the holder is gone |
|---|---|---|---|
| Canonical repository | `github.com/titafox/gateworlds` | one personal GitHub account | Under 0BSD/CC0 anyone may fork and continue. The name and URL are not recoverable without that account — a successor renames, per SUCCESSION §5. |
| Read-only mirror | `http://185.138.186.150/gateworlds.git` | self-hosted, same person | Not independently operated. It raises the bar for accidental loss and does nothing for succession. Expect it to disappear with the operator. |

Both are pushed by one `git push` (SUCCESSION §2.4). Neither is operated by a second party,
which is the open item at the top of the §6 checklist.

## Runtime dependencies

| What | Used for | Substitutable? |
|---|---|---|
| crates.io | Rust dependencies of `server/` | Yes — the dependency set is small and the lockfile is committed. |
| GitHub Actions | CI | Yes — CI runs `cargo fmt`, `cargo clippy` and `cargo test`, which run anywhere. |

There is no domain, no DNS, no TLS certificate, no package registry account, no object
storage, no database, and no paid service. That is deliberate at this stage: everything a
successor would have to take over is a thing that can be lost.

## Not yet owned

- **No domain.** The project has no DNS name and therefore nothing to transfer or lose.
- **No organisation.** Ownership is one personal account.
- **No second-party host.**

Each is an open item in [SUCCESSION.md](SUCCESSION.md) §6 rather than an oversight.
