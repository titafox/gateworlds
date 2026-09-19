# Bootstrap

From a clean clone to passing tests. No step assumes anything that is not installed by a
step above it.

`SUCCESSION.md` §2.5 requires this to be *verified by running it on a clean checkout*, not
merely written. The verification note at the bottom records the last time that happened.

## Requirements

| Tool | Version | For |
|---|---|---|
| Rust | 1.85+ (edition 2024) | the protocol validator and the server |
| Godot | 4.x | the client — **not yet written**, nothing to run |

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
```

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

## What is not here yet

- **The Godot client.** Nothing to run, nothing to look at. The conformance vectors define
  what it will have to do before it exists.
- **The registry server.** `server/` currently holds the protocol library and the CLI only.

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
