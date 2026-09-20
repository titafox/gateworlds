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
          color: v.hex,
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

  render(player, elapsed) {
    this.player.position.set(player.x + 8, PLAYER_HEIGHT / 2, player.y + 8);

    for (const b of this.bobbing) {
      b.mesh.position.y = b.base + Math.sin(elapsed * 2 + b.phase * 0.05) * 2;
      b.mesh.rotation.y = elapsed * 0.55;
    }

    // Behind and above, looking down the way you are walking. Close enough that a phone
    // screen still shows the room you are in.
    this.camera.position.set(this.player.position.x, 150, this.player.position.z + 118);
    this.camera.lookAt(this.player.position.x, 0, this.player.position.z - 26);

    this.renderer.render(this.scene, this.camera);
  }
}
