import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { clone } from 'three/addons/utils/SkeletonUtils.js';
import {CAMERA_DEFAULT, clampCameraAngle, fitBoardCamera} from './camera.js?v=motion3';
import {makeDoughRelief, applyFruitDoughRelief} from './dough_surface.js';
import {prepareFaceExpression, applyFaceExpression} from './face_expression.js?v=anchored4';
import {createLocalizedPull, samplePullDeformation} from './localized_pull.js?v=teardrop5';
import {mergePose, mergeDeparture, escapePose, createEventEffects} from './event_animation.js?v=anchored4';

// The solver owns positions. This file owns only the camera, art and soft motion.
const FLOOR = 0.215;
const STEP = 1 / 240;
const RADII = [0, 0.55, 0.65, 0.77];
const SIZES = [0, 0.82, 0.94, 1.05];
const TEMP = new THREE.Vector3();
const EULER = new THREE.Euler();
const ROTATION = new THREE.Quaternion();
const PULL_AXIS = new THREE.Vector3();
const PULL_ROTATION = new THREE.Quaternion();
const TENSOR = new THREE.Matrix4();
const TENSOR_ROTATION = new THREE.Matrix4();
const TENSOR_INVERSE = new THREE.Matrix4();
const TENSOR_SCALE = new THREE.Matrix4();

function spring(value, velocity, target, hz, damping, dt) {
  const w = Math.PI * 2 * hz;
  const x = value - target;
  const decay = Math.exp(-damping * w * dt);
  if (damping >= 0.999) {
    const c = velocity + w * x;
    return [target + (x + c * dt) * decay, (velocity - w * c * dt) * decay];
  }
  const wd = w * Math.sqrt(1 - damping * damping);
  const c = (velocity + damping * w * x) / wd;
  const co = Math.cos(wd * dt), si = Math.sin(wd * dt);
  return [target + decay * (x * co + c * si), decay * ((c * wd - damping * w * x) * co - (x * wd + damping * w * c) * si)];
}

class DoughMotion {
  constructor(id) {
    this.height = 1; this.hv = 0; this.squeeze = 0; this.sv = 0;
    this.lean = [0, 0]; this.lv = [0, 0];
    this.crest = [0, 0]; this.cv = [0, 0];
    this.limb = [0, 0]; this.limbv = [0, 0];
    this.offset = [0, 0]; this.ov = [0, 0];
    this.direction = [0, 0]; this.strength = 0;
    // Pointer samples can arrive unevenly on touchscreens. Filter the whole
    // pull vector, rather than its angle, so reversing direction passes smoothly
    // through the neutral pose instead of snapping the bun around.
    this.pull = [0, 0]; this.pullVelocity = [0, 0];
    this.squashDirection = [0, 1];
    this.directional = 0; this.directionalVelocity = 0;
    this.expression = 0; this.expressionVelocity = 0;
    this.reactionAge = 10;
    this.held = false; this.returning = false; this.reduced = false;
    this.phase = id * 1.173; this.clock = 0; this.accumulator = 0;
  }
  aim(dir, strength) {
    const length = Math.hypot(dir.x, dir.y);
    if (length > 0.001) this.direction = [dir.x / length, dir.y / length];
    this.strength = THREE.MathUtils.clamp(strength, 0, 1);
    this.held = true; this.returning = false;
  }
  cancel() { this.held = false; this.returning = true; }
  release(velocity = {x: 0, y: 8}) {
    this.held = false; this.returning = false;
    if (this.reduced) return;
    const speed = Math.hypot(velocity.x, velocity.y) || 1;
    this.squashDirection = [velocity.x / speed, velocity.y / speed];
    this.directionalVelocity -= 2.1 * THREE.MathUtils.clamp(speed / 12, 0.2, 1);
    this.expressionVelocity -= 3.5;
    this.reactionAge = 0;
    this.hv += 6.4 * THREE.MathUtils.clamp(speed / 12, 0.2, 1);
    this.lv[0] += velocity.x / speed * 2.8;
    this.lv[1] += velocity.y / speed * 2.8;
    this.sv += velocity.x / speed * 1.0;
  }
  impact(normal = {x: 0, y: 1}, strength = 0.5) {
    if (this.reduced) return;
    this.returning = false;
    const amount = THREE.MathUtils.clamp(strength, 0, 1);
    const normalLength = Math.hypot(normal.x, normal.y) || 1;
    this.squashDirection = [normal.x / normalLength, normal.y / normalLength];
    this.directionalVelocity += 3.2 * amount;
    this.expressionVelocity += 4.5 * amount;
    this.reactionAge = 0;
    this.hv -= 5.7 * amount;
    this.lv[0] += normal.x * amount * 3.2;
    this.lv[1] += normal.y * amount * 3.2;
    this.sv -= normal.x * amount * 2.2;
  }
  merge() { if (!this.reduced) { this.height = 0.85; this.hv = 5.3; this.expression = -0.55; this.expressionVelocity = -1.8; this.reactionAge = 0; } }
  update(dt) {
    this.accumulator += Math.min(Math.max(dt, 0), 0.1);
    while (this.accumulator + 1e-9 >= STEP) {
      this.accumulator -= STEP;
      this.step(STEP);
    }
  }
  step(dt) {
    this.clock += dt;
    this.reactionAge += dt;
    for (let axis = 0; axis < 2; axis++) {
      const pullTarget = this.held ? this.direction[axis] * this.strength : 0;
      [this.pull[axis], this.pullVelocity[axis]] = spring(this.pull[axis], this.pullVelocity[axis], pullTarget, 4.5, this.held || this.returning || this.reduced ? 1 : 0.38, dt);
    }
    const pullAmount = Math.min(1, Math.hypot(...this.pull));
    if (this.held && pullAmount > 0.005) this.squashDirection = this.pull.map(value => value / pullAmount);
    const tracking = this.held || this.returning || this.reduced;
    // Selection gives a small anticipatory crouch, then the bun stretches
    // along the drag as the player loads the shot. The physics stays still.
    let target = this.held ? 1 - (this.reduced ? 0.03 * pullAmount : 0.02 + 0.06 * pullAmount) : 1 + (this.reduced ? 0 : 0.012) * Math.sin(this.clock * 2.4 + this.phase);
    if (this.returning) target = 1;
    [this.height, this.hv] = spring(this.height, this.hv, target, tracking ? 5.5 : 4.4, tracking ? 1 : 0.34, dt);
    if (this.height < 0.72 || this.height > 1.16) {
      this.height = THREE.MathUtils.clamp(this.height, 0.72, 1.16);
      this.hv *= -0.15;
    }
    for (let axis = 0; axis < 2; axis++) {
      const idleLean = this.reduced ? 0 : 0.010 * Math.sin(this.clock * 1.45 + this.phase + axis * 1.3);
      const leanTarget = this.held ? -this.pull[axis] * (this.reduced ? 0.015 : 0.06) : idleLean;
      [this.lean[axis], this.lv[axis]] = spring(this.lean[axis], this.lv[axis], leanTarget, tracking ? 5.5 : 4.4, tracking ? 1 : 0.4, dt);
      this.lean[axis] = THREE.MathUtils.clamp(this.lean[axis], -0.18, 0.18);
      const crestTarget = this.reduced ? 0 : -this.lean[axis] * 1.25 + (axis ? (1 - this.height) * 0.28 : 0);
      [this.crest[axis], this.cv[axis]] = spring(this.crest[axis], this.cv[axis], crestTarget, 5.2, this.returning ? 0.7 : 0.3, dt);
      this.crest[axis] = THREE.MathUtils.clamp(this.crest[axis], -0.23, 0.23);
      const limbTarget = this.reduced ? 0 : (axis ? this.lean[1] * 0.7 : (this.height - 1) * 0.75 + this.hv * 0.022);
      [this.limb[axis], this.limbv[axis]] = spring(this.limb[axis], this.limbv[axis], limbTarget, 3.7, this.returning ? 0.7 : 0.34, dt);
      this.limb[axis] = THREE.MathUtils.clamp(this.limb[axis], -0.22, 0.22);
      const offsetTarget = this.held ? -this.pull[axis] * (this.reduced ? 0.01 : 0.025) : 0;
      [this.offset[axis], this.ov[axis]] = spring(this.offset[axis], this.ov[axis], offsetTarget, tracking ? 5.5 : 6.5, tracking ? 1 : 0.5, dt);
    }
    const squeezeTarget = this.held && !this.reduced ? -this.pull[0] * 0.025 : 0;
    [this.squeeze, this.sv] = spring(this.squeeze, this.sv, squeezeTarget, 5, tracking ? 0.8 : 0.35, dt);
    this.squeeze = THREE.MathUtils.clamp(this.squeeze, -0.065, 0.065);
    const directionalTarget = 0;
    [this.directional, this.directionalVelocity] = spring(this.directional, this.directionalVelocity, directionalTarget, tracking ? 5.5 : 4.7, tracking ? 1 : 0.40, dt);
    this.directional = THREE.MathUtils.clamp(this.directional, -0.13, 0.16);
    const expressionTarget = this.held && !this.reduced ? 0.08 + 0.30 * pullAmount : 0;
    [this.expression, this.expressionVelocity] = spring(this.expression, this.expressionVelocity, expressionTarget, tracking ? 7 : 4.8, tracking ? 1 : 0.45, dt);
    this.expression = THREE.MathUtils.clamp(this.expression, -0.65, 0.55);
    if (this.returning && Math.abs(this.height - 1) < 0.001 && Math.hypot(...this.offset) < 0.001) this.returning = false;
  }
}

const PALETTE = {
  'Warm dough': '#f3dfb4', 'Strawberry dough': '#e96e96', 'Mango dough': '#edba4c',
  'Golden crest': '#dfa331', 'Vanilla ceramic': '#eee1c3', 'Turquoise ceramic': '#62b4a6',
  'Mint inlay': '#b6d3bc', 'Quiet glaze': '#72b9aa', 'Honey trim': '#d1b378',
  'Warm biscuit': '#ead5ab', 'Biscuit shading': '#c7a878',
  'Wafer strawberry': '#dc8c9d', 'Wafer relief': '#efb8bf', 'Glossy jelly': '#e86c91',
  'Peach blush': '#e59869', 'Berry blush': '#ce527d',
};

function prepareMaterials(object) {
  object.traverse(node => {
    if (!node.isMesh) return;
    node.castShadow = true; node.receiveShadow = true;
    for (const material of Array.isArray(node.material) ? node.material : [node.material]) {
      if (!material) continue;
      if (PALETTE[material.name]) material.color.set(PALETTE[material.name]);
      material.metalness = 0;
      material.envMapIntensity = 0.35;
      const glossy = material.name === 'Glossy jelly';
      material.roughness = glossy ? 0.26 : Math.max(material.roughness ?? 0.5, material.name.includes('Chocolate') ? 0.32 : 0.64);
      if ('clearcoat' in material) material.clearcoat = glossy ? 0.16 : 0.02;
      material.needsUpdate = true;
    }
  });
}

// The exported smile and tongue are separate skinned meshes. Give each clone a
// small, relative mouth shape so the face can react without moving away from the
// Body bone or changing the original authoring assets. Bounding boxes, not
// hard-coded face coordinates, keep this compatible with revised GLB geometry.
function makeMouthExpressions(model) { return prepareFaceExpression(model, THREE); }

function shadowTexture() {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 128;
  const context = canvas.getContext('2d');
  const gradient = context.createRadialGradient(64, 64, 8, 64, 64, 64);
  gradient.addColorStop(0, 'rgba(39,61,40,0.40)');
  gradient.addColorStop(0.42, 'rgba(39,61,40,0.19)');
  gradient.addColorStop(1, 'rgba(39,61,40,0)');
  context.fillStyle = gradient; context.fillRect(0, 0, 128, 128);
  return new THREE.CanvasTexture(canvas);
}

export async function createView(canvas) {
  const renderer = new THREE.WebGLRenderer({canvas, antialias: true, alpha: true, powerPreference: 'high-performance'});
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 0.85;
  renderer.setClearColor(0x000000, 0);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  // Soft hand-painted contact shadows keep the board readable on mobile without
  // the harsh, angular dark silhouettes produced by a small directional light.
  renderer.shadowMap.enabled = false;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  const scene = new THREE.Scene();
  const camera = new THREE.OrthographicCamera(-4.15, 4.15, 5.8, -5.8, 0.1, 70);
  let cameraAngle = CAMERA_DEFAULT;
  scene.add(new THREE.HemisphereLight(0xfff8e9, 0x9caf9b, 0.85));
  const key = new THREE.DirectionalLight(0xfff5e3, 2.0);
  key.position.set(-4.5, 9, 6);
  key.castShadow = false;
  key.shadow.mapSize.set(1024, 1024);
  Object.assign(key.shadow.camera, {left: -8, right: 8, top: 8, bottom: -8, near: 0.5, far: 30});
  key.shadow.bias = -0.00015;
  key.shadow.normalBias = 0.02;
  key.shadow.radius = 3;
  scene.add(key);
  const fill = new THREE.DirectionalLight(0xe5f2f4, 0.32);
  fill.position.set(5, 4, -3);
  scene.add(fill);

  const loader = new GLTFLoader();
  const keys = ['pip', 'berry', 'mango', 'tray', 'wafer_gate', 'jelly_bumper', 'exit_plate'];
  const results = await Promise.all(keys.map(key => loader.loadAsync(new URL(`../assets/${key}.glb?v=feel2`, import.meta.url).href)));
  const templates = Object.fromEntries(keys.map((key, index) => [key, results[index]]));
  Object.values(templates).forEach(gltf => prepareMaterials(gltf.scene));
  const doughRelief = makeDoughRelief();
  applyFruitDoughRelief(templates.berry.scene, doughRelief);
  applyFruitDoughRelief(templates.mango.scene, doughRelief);
  function prop(name, x = 0, y = 0, scale = 1) {
    const model = clone(templates[name].scene);
    model.position.set(x, name === 'tray' ? 0 : FLOOR, -y);
    model.scale.setScalar(scale);
    scene.add(model);
    return model;
  }
  prop('tray');
  const gate = prop('wafer_gate', 0, 3.45);
  const wafer = gate.getObjectByName('WaferBar');
  const jelly = prop('jelly_bumper', 0, 1.38);
  prop('exit_plate', 0, 4.43, 0.70);
  let gateOpen = false, gateAge = 0, jellyAge = 10, jellyStrength = 0;
  let reduced = false;
  const entries = new Map(), departing = [], crumbs = [], mergeRings = [];
  const eventEffects = createEventEffects(THREE, scene, FLOOR);
  const shadowMap = shadowTexture();
  const shadowGeometry = new THREE.PlaneGeometry(1, 1);
  const crumbGeometry = new THREE.SphereGeometry(0.045, 7, 5);
  const crumbMaterial = new THREE.MeshStandardMaterial({color: '#efc76b', roughness: 0.8});
  const ring = new THREE.Mesh(new THREE.RingGeometry(0.66, 0.69, 48), new THREE.MeshBasicMaterial({color: '#efd088', transparent: true, opacity: 0.82, side: THREE.DoubleSide, depthWrite: false, toneMapped: false}));
  ring.rotation.x = -Math.PI / 2; ring.visible = false;
  scene.add(ring);
  const arrow = new THREE.ArrowHelper(new THREE.Vector3(0, 0, -1), new THREE.Vector3(0, FLOOR + 0.035, 0), 1, 0xe3c06c, 0.20, 0.13);
  arrow.visible = false;
  for (const part of [arrow.line, arrow.cone]) { part.material.toneMapped = false; part.material.transparent = true; part.material.opacity = 0.8; }
  scene.add(arrow);
  let aimed = null;
  const raycaster = new THREE.Raycaster();
  const plane = new THREE.Plane(new THREE.Vector3(0, 1, 0), -FLOOR);
  const ndc = new THREE.Vector2();

  function play(entry, name, fade = 0.07) {
    const clip = entry.clips.find(clip => clip.name === name || clip.name.endsWith('/' + name));
    if (!clip) return;
    const action = entry.mixer.clipAction(clip);
    if (entry.action === action && name === 'idle' && action.isRunning()) return;
    action.reset().setEffectiveWeight(1).setEffectiveTimeScale(1);
    action.setLoop(name === 'idle' ? THREE.LoopRepeat : THREE.LoopOnce, name === 'idle' ? Infinity : 1);
    action.clampWhenFinished = name !== 'idle';
    if (entry.action && entry.action !== action) entry.action.crossFadeTo(action, fade, false);
    action.play(); entry.action = action;
  }
  function addBun(bun) {
    const key = ['', 'pip', 'berry', 'mango'][bun.tier];
    const group = new THREE.Group();
    const visual = new THREE.Group(); group.add(visual);
    const model = clone(templates[key].scene);
    // The larger fruit buns face the player a little more than Pip, making
    // their expressions readable from the existing elevated camera.
    model.rotation.x = bun.tier === 1 ? -0.30 : -0.42;
    model.scale.setScalar(SIZES[bun.tier]);
    visual.add(model); scene.add(group);
    const mouthShapes = makeMouthExpressions(model);
    const localizedPull = createLocalizedPull(model, bun.tier === 3 ? 0.87 : 0.84);
    const bones = {}, authored = [];
    model.traverse(node => {
      node.userData.bunId = bun.id;
      if (node.isBone) {
        bones[node.name] = node;
        if (node.userData.name) bones[node.userData.name] = node;
        authored.push({bone: node, position: node.position.clone(), rotation: node.quaternion.clone(), scale: node.scale.clone()});
      }
    });
    const shadowMaterial = new THREE.MeshBasicMaterial({map: shadowMap, transparent: true, opacity: 0.65, depthWrite: false, toneMapped: false});
    const shadow = new THREE.Mesh(shadowGeometry, shadowMaterial);
    shadow.rotation.x = -Math.PI / 2; shadow.position.y = FLOOR + 0.008;
    shadow.scale.setScalar(RADII[bun.tier] * 2.8); scene.add(shadow);
    const motion = new DoughMotion(bun.id); motion.reduced = reduced;
    const entry = {id: bun.id, tier: bun.tier, group, visual, model, bones, authored, shadow, mouthShapes, localizedPull,
      motion, clips: templates[key].animations, mixer: new THREE.AnimationMixer(model), action: null,
      pendingIdle: false, nextBlink: 2.8 + (bun.id * 1.17) % 2.5, age: 0, arrival: null, escapeAge: null, position: {x: bun.position.x, y: bun.position.y}};
    entry.mixer.addEventListener('finished', () => { entry.pendingIdle = true; });
    play(entry, 'idle', 0);
    entry.action.time = (bun.id * 0.317) % Math.max(0.01, entry.action.getClip().duration);
    entries.set(bun.id, entry);
    return entry;
  }
  function removeEntry(entry, instant = false) {
    entries.delete(entry.id);
    if (instant || reduced) {
      scene.remove(entry.group, entry.shadow); entry.mixer.stopAllAction(); entry.shadow.material.dispose();
      for (const shape of entry.mouthShapes) shape.geometry.dispose();
      entry.localizedPull.dispose();
      // SkeletonUtils creates per-character skeletons. Their GPU bone textures
      // are not released by removing the mesh or disposing its material.
      const skeletons = new Set();
      entry.model.traverse(mesh => { if (mesh.isSkinnedMesh) skeletons.add(mesh.skeleton); });
      for (const skeleton of skeletons) skeleton.dispose();
    } else { departing.push({entry, age: 0}); }
  }
  function setBuns(buns, alpha = 1) {
    const present = new Set();
    for (const bun of buns) {
      present.add(bun.id);
      let entry = entries.get(bun.id);
      if (entry && entry.tier !== bun.tier) { removeEntry(entry, true); entry = null; }
      if (!entry) entry = addBun(bun);
      const previous = bun.previous || bun.position;
      const a = THREE.MathUtils.clamp(alpha, 0, 1);
      entry.position.x = THREE.MathUtils.lerp(previous.x, bun.position.x, a);
      entry.position.y = THREE.MathUtils.lerp(previous.y, bun.position.y, a);
      entry.group.position.set(entry.position.x, FLOOR, -entry.position.y);
      entry.shadow.position.x = entry.position.x; entry.shadow.position.z = -entry.position.y;
    }
    for (const entry of [...entries.values()]) if (!present.has(entry.id)) removeEntry(entry);
    if (aimed !== null && !entries.has(aimed)) { aimed = null; ring.visible = arrow.visible = false; }
  }
  function popCrumbs(pos) {
    if (reduced) return;
    for (let index = 0; index < 7; index++) {
      const angle = index * Math.PI * 2 / 7;
      const mesh = new THREE.Mesh(crumbGeometry, crumbMaterial);
      mesh.position.set(pos.x, FLOOR + 0.5, -pos.y); scene.add(mesh);
      crumbs.push({mesh, age: 0, velocity: new THREE.Vector3(Math.cos(angle) * 1.1, 1.4, Math.sin(angle) * 1.1)});
    }
  }
  function popMerge(pos, tier) {
    if (reduced) return;
    popCrumbs(pos);
    const ringMaterial = new THREE.MeshBasicMaterial({color: tier === 3 ? '#efc76b' : '#f2b1ad', transparent: true, opacity: 0.8, side: THREE.DoubleSide, depthWrite: false, toneMapped: false});
    const ripple = new THREE.Mesh(new THREE.RingGeometry(0.52, 0.57, 48), ringMaterial);
    ripple.rotation.x = -Math.PI / 2;
    ripple.position.set(pos.x, FLOOR + 0.035, -pos.y);
    scene.add(ripple);
    mergeRings.push({mesh: ripple, age: 0});
  }
  function syncEvents(events, buns) {
    if (buns) setBuns(buns, 1);
    for (const event of events) {
      const entry = entries.get(event.id);
      switch (event.type) {
        case 'release':
          if (entry) { entry.motion.release(event.velocity); play(entry, reduced ? 'idle' : 'release'); }
          if (aimed === event.id) { aimed = null; ring.visible = arrow.visible = false; }
          break;
        case 'impact': if (entry) entry.motion.impact(event.normal, event.strength ?? event.intensity ?? 0.5); break;
        case 'merge':
          if (entry) {
            entry.motion.merge();
            entry.arrival = reduced ? null : 0;
            play(entry, reduced ? 'idle' : 'merge');
            popMerge(entry.position, entry.tier);
            if (!reduced) eventEffects.emit(entry.position, 'merge', entry.tier);
            for (const item of departing) if (event.from?.includes(item.entry.id)) { item.target = {...entry.position}; item.targetId = entry.id; }
          }
          break;
        case 'jelly': jellyAge = 0; jellyStrength = event.strength ?? 0.7; break;
        case 'gate': gateOpen = true; gateAge = 0; if (entry) popCrumbs({x: 0, y: 3.45}); break;
        case 'escape': if (entry) {
          play(entry, reduced ? 'idle' : 'escape');
          entry.escapeAge = reduced ? null : 0;
          popCrumbs(entry.position);
          if (!reduced) eventEffects.emit(entry.position, 'escape', entry.tier);
        } break;
      }
    }
  }
  function aim(id, dir, strength) {
    const entry = entries.get(id);
    if (!entry) return;
    if (aimed !== null && aimed !== id) entries.get(aimed)?.motion.cancel();
    aimed = id; entry.motion.aim(dir, strength);
    ring.visible = true;
    ring.scale.setScalar((RADII[entry.tier] + 0.1) / 0.69);
    ring.position.set(entry.position.x, FLOOR + 0.018, -entry.position.y);
    const length = Math.hypot(dir.x, dir.y);
    arrow.visible = strength > 0.035 && length > 0.001;
    if (arrow.visible) {
      arrow.position.set(entry.position.x, FLOOR + 0.035, -entry.position.y);
      arrow.setDirection(TEMP.set(dir.x / length, 0, -dir.y / length));
      arrow.setLength(0.6 + strength * 1.1, 0.20, 0.13);
    }
  }
  function cancelAim(id = aimed) {
    entries.get(id)?.motion.cancel();
    if (aimed === id) { aimed = null; ring.visible = arrow.visible = false; }
  }
  function deform(entry, dt) {
    // Restore the last authored pose before mixing: unchanged animation channels
    // may be skipped by Three's mixer, so post-animation offsets must not accumulate.
    for (const pose of entry.authored) { pose.bone.position.copy(pose.position); pose.bone.quaternion.copy(pose.rotation); pose.bone.scale.copy(pose.scale); }
    entry.mixer.update(dt);
    for (const pose of entry.authored) { pose.position.copy(pose.bone.position); pose.rotation.copy(pose.bone.quaternion); pose.scale.copy(pose.bone.scale); }
    entry.motion.update(dt);
    const m = entry.motion, b = entry.bones;
    // Convert the finger direction from board coordinates into model-local
    // coordinates; the animated mesh bends, but the physics collider stays put.
    const pullMagnitude = Math.min(1, Math.hypot(...m.pull));
    const pullAxis = PULL_AXIS.set(-m.pull[0], 0, m.pull[1]);
    if (pullMagnitude > 0.00001) pullAxis.normalize().applyQuaternion(PULL_ROTATION.copy(entry.model.quaternion).invert());
    else pullAxis.set(1, 0, 0);
    const pullDeformation = pullMagnitude * (m.reduced ? 0.10 : 0.58);
    entry.localizedPull.update(pullAxis, pullDeformation);
    const lateral = 1 / Math.sqrt(m.height);
    const [dx, dy] = m.squashDirection;
    // The impact/release stretch is an oriented tensor in the board plane.
    // A single X/Z scale loses all directional effect on a 45-degree shot;
    // composing R * S * R^-1 keeps the correct diagonal and determinant 1.
    const sideways = Math.exp(m.squeeze);
    if (b.Body) {
      b.Body.scale.set(lateral * sideways, m.height, lateral / sideways);
      b.Body.quaternion.multiply(ROTATION.setFromEuler(EULER.set(m.lean[1], 0, -m.lean[0])));
      const localAxis = PULL_AXIS.set(dx, 0, -dy).applyQuaternion(PULL_ROTATION.copy(entry.model.quaternion).invert());
      const angle = Math.atan2(-localAxis.z, localAxis.x);
      TENSOR_ROTATION.makeRotationY(angle);
      TENSOR_INVERSE.makeRotationY(-angle);
      TENSOR_SCALE.makeScale(Math.exp(-m.directional), 1, Math.exp(m.directional));
      TENSOR.multiplyMatrices(TENSOR_ROTATION, TENSOR_SCALE).multiply(TENSOR_INVERSE);
      b.Body.matrixAutoUpdate = false;
      b.Body.matrix.compose(b.Body.position, b.Body.quaternion, b.Body.scale).multiply(TENSOR);
      b.Body.matrixWorldNeedsUpdate = true;
    }
    if (b.Crest) b.Crest.quaternion.multiply(ROTATION.setFromEuler(EULER.set(m.crest[1], 0, -m.crest[0])));
    applyFaceExpression(entry);
    for (const [side, sign] of [['L', -1], ['R', 1]]) {
      if (b['Arm.' + side]) b['Arm.' + side].quaternion.multiply(ROTATION.setFromEuler(EULER.set(m.limb[1], 0, sign * m.limb[0])));
      if (b['Foot.' + side]) b['Foot.' + side].quaternion.multiply(ROTATION.setFromEuler(EULER.set(-m.limb[0] * 0.5, 0, 0)));
    }
    entry.visual.position.set(m.offset[0], 0, -m.offset[1]);
    entry.visual.rotation.z = 0;
    // Start from a clean presentation scale every frame; celebration poses
    // are samples, not cumulative transforms.
    entry.visual.scale.setScalar(1);
    if (entry.arrival !== null) {
      entry.arrival += dt;
      const pose = mergePose(entry.arrival);
      entry.visual.scale.set(pose.scale * pose.scaleXZ, pose.scale * pose.scaleY, pose.scale * pose.scaleXZ);
      entry.visual.position.y += pose.y;
      entry.visual.rotation.z = pose.tilt;
      if (pose.done) { entry.arrival = null; entry.visual.scale.setScalar(1); entry.visual.rotation.z = 0; }
    }
    let celebrationHop = 0;
    if (entry.escapeAge !== null) {
      entry.escapeAge += dt;
      const pose = escapePose(entry.escapeAge);
      celebrationHop = pose.y;
      entry.visual.position.y += pose.y;
      entry.visual.rotation.z = pose.tilt;
      const baseScale = entry.visual.scale.x;
      entry.visual.scale.set(baseScale * pose.scaleXZ, baseScale * pose.scaleY, baseScale * pose.scaleXZ);
      if (pose.done) entry.escapeAge = null;
    }
    const hop = Math.max(0, (b.Root?.position.y || 0) + celebrationHop);
    entry.shadow.material.opacity = 0.65 / (1 + hop * 3);
    entry.shadow.scale.setScalar(RADII[entry.tier] * 2.8 * (1 + hop * 0.2));
    entry.age += dt;
    if (entry.pendingIdle) { entry.pendingIdle = false; play(entry, 'idle'); }
    if (entry.age >= entry.nextBlink && !m.held && entry.action?.getClip().name.endsWith('idle')) {
      play(entry, 'blink'); entry.nextBlink = entry.age + 3.2 + (entry.id * 0.73) % 2;
    }
  }
  function render(dt = 1 / 60) {
    dt = Math.min(Math.max(dt, 0), 0.1);
    for (const entry of entries.values()) deform(entry, dt);
    for (let i = departing.length - 1; i >= 0; i--) {
      const departingEntry = departing[i]; departingEntry.age += dt;
      const {progress, done, scale, opacity, scaleY, scaleXZ, y, tilt} = mergeDeparture(departingEntry.age);
      deform(departingEntry.entry, dt);
      departingEntry.entry.group.scale.setScalar(scale);
      // The new friend already covers the contact; avoid a distracting tiny
      // leftover face appearing underneath it during the final dissolve.
      departingEntry.entry.group.visible = scale >= 0.45;
      departingEntry.entry.visual.scale.set(scaleXZ, scaleY, scaleXZ);
      departingEntry.entry.visual.position.y = y;
      if (departingEntry.target) {
        const p = departingEntry.entry.position;
        const target = entries.get(departingEntry.targetId)?.position || departingEntry.target;
        departingEntry.entry.group.position.x = THREE.MathUtils.lerp(p.x, target.x, progress);
        departingEntry.entry.group.position.z = -THREE.MathUtils.lerp(p.y, target.y, progress);
        departingEntry.entry.shadow.position.x = departingEntry.entry.group.position.x;
        departingEntry.entry.shadow.position.z = departingEntry.entry.group.position.z;
        const sign = Math.sign(target.x - p.x) || Math.sign(target.y - p.y) || 1;
        departingEntry.entry.visual.rotation.z = -sign * tilt;
      }
      departingEntry.entry.shadow.material.opacity = opacity * 0.4;
      if (done) { removeEntry(departingEntry.entry, true); departing.splice(i, 1); }
    }
    for (let i = mergeRings.length - 1; i >= 0; i--) {
      const effect = mergeRings[i]; effect.age += dt;
      const t = Math.min(1, effect.age / 0.34);
      effect.mesh.scale.setScalar(0.72 + 0.65 * t);
      effect.mesh.material.opacity = 0.7 * (1 - t);
      if (t >= 1) { scene.remove(effect.mesh); effect.mesh.geometry.dispose(); effect.mesh.material.dispose(); mergeRings.splice(i, 1); }
    }
    if (gateOpen) {
      gateAge += dt;
      if (wafer) { wafer.visible = gateAge < 0.32; wafer.position.y = -gateAge * 3.4; wafer.rotation.z = reduced ? 0 : Math.sin(gateAge * 18) * 0.12; }
    }
    jellyAge += dt;
    const jellyHeight = reduced ? 1 : 1 - Math.sin(jellyAge * 30) * Math.exp(-jellyAge * 8) * jellyStrength * 0.16;
    jelly.scale.set(1 / Math.sqrt(jellyHeight), jellyHeight, 1 / Math.sqrt(jellyHeight));
    for (let i = crumbs.length - 1; i >= 0; i--) {
      const crumb = crumbs[i]; crumb.age += dt; crumb.velocity.y -= dt * 4;
      crumb.mesh.position.addScaledVector(crumb.velocity, dt);
      crumb.mesh.scale.setScalar(Math.max(0.01, 1 - crumb.age / 0.5));
      if (crumb.age >= 0.5) { scene.remove(crumb.mesh); crumbs.splice(i, 1); }
    }
    eventEffects.update(dt);
    renderer.render(scene, camera);
  }
  function resize() {
    const rect = canvas.getBoundingClientRect();
    const width = Math.max(1, rect.width), height = Math.max(1, rect.height);
    renderer.setSize(width, height, false);
    fitBoardCamera(camera, cameraAngle, width / height);
  }
  function setCameraAngle(value) { cameraAngle = clampCameraAngle(value); resize(); }
  function ray(clientX, clientY) {
    const rect = canvas.getBoundingClientRect();
    ndc.set((clientX - rect.left) / rect.width * 2 - 1, -(clientY - rect.top) / rect.height * 2 + 1);
    raycaster.setFromCamera(ndc, camera);
  }
  function worldFromScreen(clientX, clientY) {
    ray(clientX, clientY);
    const point = raycaster.ray.intersectPlane(plane, TEMP);
    return point ? {x: point.x, y: -point.z} : null;
  }
  function screenFromWorld(pos) {
    const rect = canvas.getBoundingClientRect();
    TEMP.set(pos.x, FLOOR, -pos.y).project(camera);
    return {x: rect.left + (TEMP.x + 1) * rect.width / 2, y: rect.top + (1 - TEMP.y) * rect.height / 2};
  }
  function pickBun(clientX, clientY) {
    ray(clientX, clientY);
    const hit = raycaster.intersectObjects([...entries.values()].map(entry => entry.model), true)[0];
    return hit?.object.userData.bunId ?? null;
  }
  function reset() {
    for (const entry of [...entries.values()]) removeEntry(entry, true);
    for (const {entry} of departing) removeEntry(entry, true);
    departing.length = 0;
    for (const {mesh} of crumbs) scene.remove(mesh);
    crumbs.length = 0;
    for (const {mesh} of mergeRings) { scene.remove(mesh); mesh.geometry.dispose(); mesh.material.dispose(); }
    mergeRings.length = 0;
    eventEffects.reset();
    gateOpen = false; gateAge = 0; jellyAge = 10; jellyStrength = 0;
    jelly.scale.setScalar(1);
    if (wafer) { wafer.visible = true; wafer.position.y = 0; wafer.rotation.z = 0; }
    aimed = null; ring.visible = arrow.visible = false;
  }
  function setReducedMotion(value) {
    reduced = !!value;
    for (const entry of entries.values()) { entry.motion.reduced = reduced; if (reduced) { entry.motion.hv = entry.motion.sv = entry.motion.directionalVelocity = entry.motion.expressionVelocity = 0; entry.motion.lv.fill(0); entry.arrival = null; entry.escapeAge = null; entry.visual.rotation.z = 0; entry.visual.scale.setScalar(1); } }
    if (reduced) { for (const {entry} of departing) removeEntry(entry, true); departing.length = 0; for (const {mesh} of crumbs) scene.remove(mesh); crumbs.length = 0; for (const {mesh} of mergeRings) { scene.remove(mesh); mesh.geometry.dispose(); mesh.material.dispose(); } mergeRings.length = 0; eventEffects.reset(); jelly.scale.setScalar(1); }
  }
  function configureLevel(level) {
    const bumper = level.bumpers[0];
    jelly.visible = !!bumper;
    if (bumper) jelly.position.set(bumper.position.x, FLOOR, -bumper.position.y);
  }
  function setGateOpen(value) {
    gateOpen = !!value;
    gateAge = gateOpen ? 1 : 0;
    if (wafer) wafer.visible = !gateOpen;
  }
  function inspect() {
    const pullReport = entry => {
      const uniforms = entry.localizedPull.uniforms;
      const axis = uniforms.bunPullAxis.value.toArray(), amount = uniforms.bunPullAmount.value;
      const center = [0, uniforms.bunPullCenterY.value, 0];
      const edge = sign => center.map((v, i) => v + sign * 0.76 * axis[i]);
      return {axis, amount, anchor: samplePullDeformation(edge(-1), axis, amount, center),
        fingerSide: samplePullDeformation(edge(1), axis, amount, center)};
    };
    return {renderer: 'Three.js WebGL / real GLB meshes', exposure: renderer.toneMappingExposure, cameraAngle,
      resources: {geometries: renderer.info.memory.geometries, textures: renderer.info.memory.textures, programs: renderer.info.programs.length},
      gateOpen, aimed, reducedMotion: reduced, count: entries.size,
      buns: [...entries.values()].map(entry => ({id: entry.id, tier: entry.tier, height: entry.motion.height,
        held: entry.motion.held, offset: {x: entry.motion.offset[0], y: entry.motion.offset[1]},
        crest: [...entry.motion.crest], limbs: [...entry.motion.limb],
        directional: entry.motion.directional, squashDirection: [...entry.motion.squashDirection], expression: entry.motion.expression,
        pullDeformation: pullReport(entry),
        mouthShapes: entry.mouthShapes.length,
        bodyMatrix: entry.bones.Body ? entry.bones.Body.matrix.elements.slice() : null,
        volume: entry.bones.Body ? entry.bones.Body.matrix.determinant() : 1}))};
  }
  resize();
  const observer = new ResizeObserver(resize); observer.observe(canvas);
  window.addEventListener('resize', resize);
  return {setBuns, syncEvents, aim, cancelAim, resize, render, worldFromScreen, screenFromWorld,
    pickBun, reset, configureLevel, setGateOpen, setReducedMotion, setCameraAngle, inspect, debug: inspect,
    capture: () => { renderer.render(scene, camera); return canvas.toDataURL('image/png'); },
    dispose: () => { observer.disconnect(); window.removeEventListener('resize', resize); reset(); eventEffects.dispose(); doughRelief.dispose(); renderer.dispose(); }};
}
