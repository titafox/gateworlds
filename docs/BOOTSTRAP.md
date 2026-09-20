# Bootstrap

From a clean clone to passing tests. No step assumes anything that is not installed by a
step above it.

`SUCCESSION.md` §2.5 requires this to be *verified by running it on a clean checkout*, not
merely written. The verification note at the bottom records the last time that happened.

## Requirements

| Tool | Version | For |
|---|---|---|
| Rust | 1.85+ (edition 2024) | the protocol validator and the server |
| Godot | 4.7.2 | the client's protocol layer and its headless tests |

Rust, if absent:

```sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

## Clone, test

```sh
git clone https://github.com/titafox/gateworlds
cd gateworlds/server
cargo test --all
```

That runs the unit tests, every conformance vector in `protocol/conformance/`, and full
validation of every world package under `worlds/`.

## The validator, as a CLI

```sh
cd server && cargo build --release && cd ..

# every conformance vector
./server/target/release/gateworlds-validate conformance protocol/conformance

# a world package directory (also checks referenced files exist and stay inside the package)
./server/target/release/gateworlds-validate package worlds/pastoral_village worlds/xianxia_gate

# a single document
./server/target/release/gateworlds-validate doc world worlds/xianxia_gate/world.json

# validate everything, then write a static registry any web server can serve
./server/target/release/gateworlds-validate publish worlds /tmp/registry
```

The registry layout is [`REGISTRY.md`](REGISTRY.md).

Exit code is `0` when everything passes, `1` on any finding, `2` on bad usage — so it drops
into CI or a pre-commit hook unchanged.

## Writing a world

A world package is data. There is no code in it, and no way to put code in it — see
[`../protocol/SPEC.md`](../protocol/SPEC.md) §9.

```sh
mkdir -p worlds/my_world
# write world.json and items.json, then:
./server/target/release/gateworlds-validate package worlds/my_world
```

`worlds/pastoral_village/` is the smallest complete example. The validator reports **every**
problem it can find in one pass, so you are not fixing one error per round trip.

## The client's tests

```sh
godot --headless --path client-godot --script res://tests/run_tests.gd
```

Runs the GDScript unit tests and **the same 27 conformance vectors the Rust validator
runs**. Exits non-zero on failure.

### Playing it

```sh
godot --path client-godot
```

Arrow keys or WASD. Walk east from the village into the portal, pick up the herb, walk
back. `F5` saves, `F9` loads.

There is also a scripted walkthrough that drives the real game, lets the real portal
triggers fire, and saves screenshots:

```sh
GW_SHOTS=/tmp/shots godot --path client-godot --script res://tests/walkthrough.gd
```

It needs a display, so it is not part of CI. It exists because "you can walk between the
two worlds" is not something a headless assertion can honestly claim.

`client-godot/protocol` is a symlink to `../protocol`, not a copy: the client compiles the
schemas from the one normative source, exactly as the Rust crate does with `include_str!`.
Two copies of a schema are two schemas.

## What is not here yet

- **Any interface.** There is no inventory panel and no on-screen text: the herb is in the
  save file and in the log, not on the screen. That is the next milestone.
- **The registry service.** There is none by design — the registry is static files, see
  [REGISTRY.md](REGISTRY.md).

Both are deliberate: [ADR-0001](adr/0001-engine-neutrality.md) puts the protocol first so
that the client and the server are replaceable rather than foundational.

---

## Verification

Every command above was executed in order on a fresh `git clone`, not read over.

| Date | Platform | Result |
|---|---|---|
| 2026-09-19 | macOS 27.0 arm64, rustc 1.93.0 | all 6 steps pass |

The first such run failed: `doc world` reported a false `unresolved_reference` because it
ignored the `items.json` beside the file. That is the whole argument for executing this
document rather than maintaining it. Re-verify after any change to the build, the layout or
the toolchain requirement, and record the result here.
