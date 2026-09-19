# World registry, v0

How a client discovers and fetches worlds over HTTP.

The registry is **static files**. There is no application server: `gateworlds-validate
publish` validates every package and writes a directory, and any web server hands it out.
Nothing is listening, nothing can crash, and nothing executes on request.

Reference deployment: `http://185.138.186.150/v0/` — see
[`INFRASTRUCTURE.md`](INFRASTRUCTURE.md). It is a reference, not an authority; the layout
below is what matters, and anyone may host their own.

## Layout

```
v0/
├── index.json
└── worlds/
    └── <world_id>/
        ├── manifest.json
        ├── world.json
        └── items.json          (optional, plus any package files)
```

## `GET /v0/index.json`

```jsonc
{
  "registry_version": "0.1.0",
  "protocol_version": "0.1.0",        // the protocol every listed world conforms to
  "generated_at": "2026-09-19T12:00:03Z",
  "worlds": [
    {
      "id": "xianxia_gate",
      "display_name": { "zh-CN": "青霄山门", "en": "Azure Sky Gate", "ru": "…", "ja": "…" },
      "manifest": "v0/worlds/xianxia_gate/manifest.json",
      "sha256": "4bd5ef…"           // of manifest.json, as served
    }
  ]
}
```

`display_name` is repeated here so a client can render a world list without fetching every
manifest.

## `GET /v0/worlds/<id>/manifest.json`

```jsonc
{
  "registry_version": "0.1.0",
  "protocol_version": "0.1.0",
  "id": "xianxia_gate",
  "display_name": { … },
  "description": { … },
  "license": { "code": "0BSD", "assets": "CC0-1.0" },
  "files": [
    { "path": "items.json", "size": 948,  "sha256": "…" },
    { "path": "world.json", "size": 4025, "sha256": "…" }
  ]
}
```

`path` is package-relative and obeys the resource path rules in
[`../protocol/SPEC.md`](../protocol/SPEC.md) §5. Fetch a file from
`v0/worlds/<id>/<path>`.

## What a client must do

1. `GET v0/index.json`. Reject the registry if `protocol_version` fails the acceptance rule
   in SPEC §2.2 — an index advertising a protocol you do not implement is not a list you can
   use.
2. Fetch the manifest and **check its SHA-256 against the index**.
3. Fetch each file and **check its SHA-256 against the manifest**.
4. **Validate the documents anyway.**

Step 4 is not redundant. The hashes prove the bytes are the bytes the registry meant to
serve; they prove nothing about whether the registry should have served them. ADR-0001 §4
puts the server first in line and the client second, and *neither trusts the other*. A
client that validates only what it fetched over a channel it trusts has moved its security
boundary to somebody else's disk.

Checking one hash — the manifest's — is enough to detect any change to a package, because
every file's hash is inside the manifest.

## Version negotiation

`registry_version` covers this document's layout. `protocol_version` covers the world
documents. They are separate on purpose: the way worlds are *distributed* and the way they
are *written* should be able to change independently.

## Publishing

```sh
gateworlds-validate publish worlds/ /srv/gateworlds/registry
```

A package that fails validation is **never written to the output** — not written and
flagged. The output directory is replaced wholesale rather than merged, so a world that is
withdrawn stops being reachable instead of lingering because nobody deleted it.
