// Drawing a world with three.js.
//
// ADR-0001 §2 puts rendering on the engine-bound side of the line: a client may present a
// world however it likes, as long as the semantics match. So this one does not imitate the
// Godot client's flat rectangles -- it stands the world up.
//
// The heights are not invented. `solid` is a semantic the protocol defines (it blocks
// movement), so things that block you are tall and things that do not lie flat. The same
// data, read the same way, shown differently.

import * as THREE from '../vendor/three.module.min.js';

/// How much world to keep on screen, in protocol units.
///
/// A fixed camera distance shows wildly different amounts of a world depending on the
/// screen: a wide desktop window has a narrow vertical field and ends up pressed against
/// the player, while a tall phone sees far too much. So the distance is computed from the
/// field of view and the aspect instead, and both axes are honoured -- otherwise a portrait
/// phone gets a comfortable depth and a letterbox of width.
/// Never more than this, and never more than the world itself -- framing empty space beyond
/// the edge of a small world tells the player nothing and makes everything in it smaller.
const VISIBLE_DEPTH = 430;
const VISIBLE_WIDTH = 430;
const TILT = (56 * Math.PI) / 180;

const WALL_HEIGHT = 22;
const FLAT_HEIGHT = 1.5;
const TRIGGER_HEIGHT = 9;
const PLAYER_HEIGHT = 16;

export class SceneView {
  constructor(canvas) {
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
    // Two is enough for a phone; more costs battery for pixels nobody resolves.
    this.renderer.setPixelRatio(Math.min(globalThis.devicePixelRatio ?? 1, 2));

    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(52, 1, 1, 4000);

    this.scene.add(new THREE.AmbientLight(0xffffff, 1.6));
    const key = new THREE.DirectionalLight(0xffffff, 1.7);
    key.position.set(-0.4, 1, 0.55);
    this.scene.add(key);

    this.worldGroup = new THREE.Group();
    this.scene.add(this.worldGroup);

    this.player = new THREE.Mesh(
      new THREE.BoxGeometry(16, PLAYER_HEIGHT, 16),
      new THREE.MeshLambertMaterial({ color: 0xf2e9d8 }),
    );
    this.scene.add(this.player);

    this.bobbing = [];
    this.bounds = { w: VISIBLE_WIDTH, h: VISIBLE_DEPTH };
    // Textures are shared between meshes and between worlds. A world you walk back into
    // should not pay for its art twice.
    this.textures = new Map();
    this.loader = new THREE.TextureLoader();
    this.resize();
  }

  resize() {
    const w = globalThis.innerWidth ?? 640;
    const h = globalThis.innerHeight ?? 480;
    this.renderer.setSize(w, h, false);
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
  }

  /// Rebuilds the scene for a world. Called on arrival and whenever an entity leaves --
  /// there are tens of objects, not thousands, so rebuilding is simpler than diffing and
  /// fast enough that nobody can tell.
  setWorld(runtime) {
    this.bobbing = [];
    this.bounds = runtime.bounds;
    this.worldGroup.clear();

    const ground = new THREE.Color(runtime.background.hex);
    this.scene.background = ground;
    this.scene.fog = new THREE.Fog(runtime.background.hex, 280, 820);

    const { w, h } = runtime.bounds;
    const floor = new THREE.Mesh(
      new THREE.PlaneGeometry(w, h),
      new THREE.MeshLambertMaterial({ color: ground.clone().multiplyScalar(1.3) }),
    );
    floor.rotation.x = -Math.PI / 2;
    floor.position.set(w / 2, 0, h / 2);
    this.worldGroup.add(floor);

    const triggers = new Map();
    for (const p of runtime.portals) triggers.set(p.entityId, 'portal');
    for (const p of runtime.pickups) triggers.set(p.entityId, 'pickup');

    for (const v of runtime.visuals) {
      const kind = triggers.get(v.entityId);
      const height = v.blocks ? WALL_HEIGHT : kind ? TRIGGER_HEIGHT : FLAT_HEIGHT;

      const mesh = new THREE.Mesh(
        new THREE.BoxGeometry(v.rect.w, height, v.rect.h),
        new THREE.MeshLambertMaterial({
          // A texture replaces the colour; the schema allows exactly one of the two
          // (SPEC §7.1), so there is never a question of which wins.
          map: v.texture ? this.#texture(v.texture) : null,
          color: v.texture ? 0xffffff : v.hex,
          transparent: v.alpha < 1,
          opacity: v.alpha,
        }),
      );
      mesh.position.set(v.centre.x, height / 2, v.centre.y);
      this.worldGroup.add(mesh);

      // The only motion in the scene, and it marks the two things that respond to you.
      if (kind) this.bobbing.push({ mesh, base: height / 2, phase: v.centre.x + v.centre.y });
    }
  }

  /// Loads a texture once per URL.
  ///
  /// The URL is a data: URL the registry produced from bytes whose hash it checked, so
  /// nothing here reaches the network -- the renderer cannot be pointed at an address a
  /// package chose.
  #texture(url) {
    if (!this.textures.has(url)) {
      const texture = this.loader.load(url);
      texture.colorSpace = THREE.SRGBColorSpace;
      // Stylised art at small sizes: keep the edges rather than smearing them.
      texture.magFilter = THREE.NearestFilter;
      texture.minFilter = THREE.LinearMipmapLinearFilter;
      this.textures.set(url, texture);
    }
    return this.textures.get(url);
  }

  render(player, elapsed) {
    this.player.position.set(player.x + 8, PLAYER_HEIGHT / 2, player.y + 8);

    // Bobbing only, never spinning. A rotating box changes its apparent footprint while its
    // trigger rectangle stays put, so it would advertise a way in at the corners that does
    // not exist. Motion here marks the two things that respond to you; it must not lie about
    // where they respond.
    for (const b of this.bobbing) {
      b.mesh.position.y = b.base + Math.sin(elapsed * 2 + b.phase * 0.05) * 2;
    }

    // Behind and above, looking down the way you are walking, far enough back that the room
    // you are in fits on whatever screen you are holding.
    const vFov = (this.camera.fov * Math.PI) / 180;
    const hFov = 2 * Math.atan(Math.tan(vFov / 2) * this.camera.aspect);
    const wantDepth = Math.min(VISIBLE_DEPTH, this.bounds.h);
    const wantWidth = Math.min(VISIBLE_WIDTH, this.bounds.w);
    const distance = Math.max(
      wantDepth / 2 / Math.tan(vFov / 2),
      wantWidth / 2 / Math.tan(hFov / 2),
    );

    const { x, z } = this.player.position;
    this.camera.position.set(x, Math.sin(TILT) * distance, z + Math.cos(TILT) * distance);
    this.camera.lookAt(x, 0, z - distance * 0.12);

    this.renderer.render(this.scene, this.camera);
  }
}
