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
| Read-only mirror | `https://gw.koko.kg/gateworlds.git` | self-hosted, same person | Not independently operated. It raises the bar for accidental loss and does nothing for succession. Expect it to disappear with the operator. |
| World registry | `https://gw.koko.kg/v0/` | same host | Static files produced by `gateworlds-validate publish` — see [REGISTRY.md](REGISTRY.md). Reproducible from the repository by one command, so losing the host loses nothing but a URL. |

Both are pushed by one `git push` (SUCCESSION §2.4). Neither is operated by a second party,
which is the open item at the top of the §6 checklist.

## Runtime dependencies

| What | Used for | Substitutable? |
|---|---|---|
| crates.io | Rust dependencies of `server/` | Yes — the dependency set is small and the lockfile is committed. |
| GitHub Actions | CI | Yes — CI runs `cargo fmt`, `cargo clippy` and `cargo test`, which run anywhere. |

The registry host also runs a `post-receive` hook: a push to its git mirror re-fetches,
rebuilds, revalidates and republishes. The build is never skipped, because the schemas are
compiled into the binary and a gate validating against a specification that no longer
exists is worse than a late one.

### DNS, TLS and the front door

| What | Detail | If the holder is gone |
|---|---|---|
| `gw.koko.kg` | A subdomain of a domain **owned for an unrelated project**, on Cloudflare | The name disappears with that domain. Nothing depends on it: the mirror is reproducible and the registry is one command from the repository. A successor points their own name at their own host. |
| Cloudflare proxy | The record is proxied, so public DNS returns Cloudflare addresses rather than the origin | Without it the origin address is visible again. It is in this repository's history regardless (see below). |
| TLS certificate | Let's Encrypt, ECDSA, issued and renewed by acme.sh over DNS-01 | Renewal needs a Cloudflare API token, held on the host only, scoped to DNS edit on that one zone. Not in this repository. |

**The origin address is in this repository's git history and cannot be taken back.** Hiding
it in DNS is therefore only half the measure; the host's firewall restricts 80 and 443 to
Cloudflare's published ranges, so reading an old commit does not get anyone a connection.
The ranges change, so that is a script (`gateworlds-cf-firewall`) rather than a fixed set
of rules.

Port 22 stays open to the world, by key only, with fail2ban. It has to: the mirror is
pushed over SSH. It sees the constant background of credential-stuffing that any open SSH
port sees, and that is unrelated to whether the address is published — scanners find open
ports within hours either way.

Beyond this there is no package registry account, no object storage, no database, and no
paid service. That is deliberate at this stage: everything a successor would have to take
over is a thing that can be lost.

## Not yet owned

- **No domain.** The project has no DNS name and therefore nothing to transfer or lose.
- **No organisation.** Ownership is one personal account.
- **No second-party host.**

Each is an open item in [SUCCESSION.md](SUCCESSION.md) §6 rather than an oversight.
