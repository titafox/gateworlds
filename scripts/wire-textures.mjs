#!/usr/bin/env node
// Points a world's sprites at the images sitting next to them.
//
//   node scripts/wire-textures.mjs [worlds-dir]
//
// The protocol already carries textures: `sprite` takes `color` or `texture`, exactly one
// (SPEC §7.1), and a texture is a package-relative path (SPEC §5). What it does not have is
// a way to say "use the picture if there is one" -- a package either names a file that
// exists or fails validation with `resource_not_found`. That is the right rule for a
// protocol and an awkward one while you are still drawing.
//
// So this walks each world and, for every entity `<id>`, looks for `art/<id>.png` (or .webp,
// .jpg). If the file is there, that entity's sprite swaps `color` for `texture`.
//
// It only goes one way. An earlier version stashed the old colour on the entity so it could
// undo itself, which the schema immediately rejected as an unknown field -- correctly, and
// it was the protocol catching a mistake in a tool meant to serve it. To undo, use
// `git checkout worlds/`. The repository already answers "how do I go back"; this does not
// need its own answer.
//
// Run the validator afterwards. This edits data; nothing here decides whether the data is
// valid, and nothing in this project decides that except the validator.

import { readdir, readFile, writeFile, stat } from 'node:fs/promises';
import { join } from 'node:path';

const EXTENSIONS = ['png', 'webp', 'jpg', 'jpeg'];
const root = process.argv[2] ?? 'worlds';

const exists = (p) => stat(p).then(() => true, () => false);

async function artFor(dir, name) {
  for (const ext of EXTENSIONS) {
    const rel = `art/${name}.${ext}`;
    if (await exists(join(dir, rel))) return rel;
  }
  return null;
}

let wired = 0;
let already = 0;
let rewritten = 0;

const entries = (await readdir(root, { withFileTypes: true })).sort((a, b) =>
  a.name.localeCompare(b.name));

for (const entry of entries) {
  if (!entry.isDirectory()) continue;
  const dir = join(root, entry.name);
  const file = join(dir, 'world.json');
  if (!(await exists(file))) continue;

  const world = JSON.parse(await readFile(file, 'utf8'));
  let changed = false;

  for (const ent of world.entities ?? []) {
    const sprite = (ent.components ?? []).find((c) => c?.type === 'sprite');
    if (!sprite) continue;

    const art = await artFor(dir, ent.id);
    if (!art) continue;
    if (sprite.texture === art) {
      already += 1;
      continue;
    }
    // Exactly one of colour and texture, so the colour goes.
    delete sprite.color;
    sprite.texture = art;
    changed = true;
    wired += 1;
  }

  if (changed) {
    await writeFile(file, `${JSON.stringify(world, null, 2)}\n`);
    rewritten += 1;
    console.log(`  ${entry.name}`);
  }
}

console.log(`${wired} sprites wired to an image (${already} already were), ${rewritten} worlds rewritten`);
if (wired) console.log('Now run: ./server/target/release/gateworlds-validate package worlds/*');
