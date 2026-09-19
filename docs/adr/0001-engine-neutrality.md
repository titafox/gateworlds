# ADR-0001: Engine neutrality, and Godot as the initial client

- **Status:** Accepted (provisional — this decision is designed to be revoked)
- **Date:** 2026-09-19
- **Supersedes:** none
- **Constitutional basis:** README principle 5 ("every technical choice can be revisited"),
  and the constitutional principles *Technology is changeable* and *Protection of existing work*.

## Context

Gateworlds's README states that the game engine, the SDK, and the world protocol are not
permanent, and that the project will not require future creators to obey a technology
merely because it happened to be used first.

At the same time, nothing can be built without picking something. Refusing to choose is
not neutrality; it is paralysis. The constitution forbids *lock-in*, not *starting*.

The real hazard is not "we used Godot on day one." It is letting an engine leak into the
**protocol layer**. If community worlds were shipped as `.tscn` / `.tres` / GDScript, then:

- replacing the engine would invalidate every community world — a direct breach of
  *Protection of existing work*;
- *Technology is changeable* would become a slogan, because the cost of change would be
  unbounded;
- the project would have done exactly what the README says it will not do.

The same reasoning applies symmetrically to Rust on the server. Neither choice gets a pass.

## Decision

### 1. The protocol is the project. Implementations are replaceable.

`protocol/` is the normative artefact: JSON Schemas, a written specification, and
language-neutral conformance vectors. It contains **no Godot types and no Rust types**.

Implementations are consumers of the protocol, not owners of it:

| Layer | Status | May be replaced by |
|---|---|---|
| `protocol/` | Normative | Only by a governed protocol version bump |
| `client-godot/` | **Provisional** | Any client that passes the conformance vectors |
| `server/` (Rust) | **Provisional** | Any server that passes the conformance vectors |

### 2. Where the line falls

**Engine-bound (an implementation may do as it likes):** rendering, input handling,
physics integration, scene-graph shape, audio mixing, windowing, asset import pipeline,
frame pacing.

**Engine-neutral (normative, no implementation may extend unilaterally):** the world
package format, the save format, the item and identity model, component type names and
their parameters, resource path rules, the validation error taxonomy, and the server HTTP
API.

### 3. Exit criteria — what "replaceable" has to mean concretely

Godot may be replaced when a candidate client satisfies all of:

1. **Zero-edit load.** Every world package in the registry loads on the new client with
   no modification to the package.
2. **Conformance parity.** The new client passes every vector in
   `protocol/conformance/`, producing the same error code for every invalid vector.
3. **Save portability.** A save written by the Godot client loads on the new client, and
   the reverse, with no lossy field.
4. **Documented rollback.** A published path back to the previous client for at least one
   release cycle.

A claim of replaceability with no written exit criteria is not replaceability. These
criteria are the test.

### 4. Neutrality is proved by two implementations, not asserted by one

The same schemas and the same conformance vectors are executed by **both** the Rust
server validator and the Godot client validator. Two independent implementations agreeing
is evidence. One implementation is just a habit.

This also serves the security requirement: the server is the first gate on ingest, the
client is the second gate on load. Neither trusts the other.

### 5. The README names no engine

Technology choices live in `docs/adr/`. They do not live in the manifesto. A README that
hard-codes an engine contradicts constitutional principle 5 on the day it is written.

## Consequences

**Accepted costs**

- Worlds cannot use arbitrary engine features. Expressive power grows by extending the
  component whitelist through governance, which is slower than letting creators ship code.
- Two validator implementations must be kept in step. The conformance vectors are what
  make that tractable, and their cost is real.
- Some work is duplicated between Rust and GDScript. This is the price of the proof.

**Rejected alternatives**

- *Ship `.tscn` / `.tres` packages.* Best expressive power, native to the chosen engine —
  and it welds the engine to the protocol permanently. Rejected on constitutional grounds,
  before the security grounds (deserialisation of scene resources is also an attack
  surface).
- *Allow sandboxed GDScript in world packages.* GDScript has no official sandbox; a safe
  subset would have to be built and maintained. Rejected as out of scope for Phase 1, and
  as engine lock-in regardless of the sandbox.
- *Decide no engine yet and design in the abstract.* Produces a specification nobody has
  executed. Rejected: the first version has to run.

## Revisiting this decision

Any community member may propose replacing Godot, Rust, or the protocol itself under the
governance procedure in force at the time. A proposal that meets the exit criteria in
section 3 does not need this ADR's authors to agree with it.
