# Vendored dependencies

Checked in rather than installed, so the client has **no runtime dependency on anything
outside this repository**: it works from a plain static directory, offline, with no package
manager, no build step and no CDN that has to still be there in five years.

That matters more than it usually would. `docs/SUCCESSION.md` asks what a successor has to
take over, and the honest answer should stay "nothing that can be lost".

| File | What | Licence |
|---|---|---|
| `three.module.min.js` | three.js r186, the ES module build | MIT — see `three.LICENSE` |
| `three.core.min.js` | the half of that build it imports | MIT — same file |

Third-party code keeps its own licence and is not covered by the project's 0BSD/CC0
(README, *License*). To update: replace both files, point the import in
`three.module.min.js` at `./three.core.min.js`, update the revision here, and run the tests.
