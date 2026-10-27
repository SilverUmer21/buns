import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { clone } from 'three/addons/utils/SkeletonUtils.js';

// The solver owns positions. This file owns only the camera, art and soft motion.
const FLOOR = 0.215;
const STEP = 1 / 240;
const RADII = [0, 0.55, 0.65, 0.77];
const SIZES = [0, 0.76, 0.90, 1.00];
const TEMP = new THREE.Vector3();
const EULER = new THREE.Euler();
const ROTATION = new THREE.Quaternion();

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
    this.held = false; this.returning = false; this.reduced = false;
    this.phase = id * 1.173; this.clock = 0; this.accumulator = 0;
  }
  aim(dir, strength) {
    const length = Math.hypot(dir.x, dir.y) || 1;
    this.direction = [dir.x / length, dir.y / length];
    this.strength = THREE.MathUtils.clamp(strength, 0, 1);
    this.held = true; this.returning = false;
  }
  cancel() { this.held = false; this.returning = true; }
  release(velocity = {x: 0, y: 8}) {
    this.held = false; this.returning = false;
    if (this.reduced) return;
    const speed = Math.hypot(velocity.x, velocity.y) || 1;
    this.hv += 6.4 * THREE.MathUtils.clamp(speed / 12, 0.2, 1);
    this.lv[0] += velocity.x / speed * 2.8;
    this.lv[1] += velocity.y / speed * 2.8;
    this.sv += velocity.x / speed * 1.0;
  }
  impact(normal = {x: 0, y: 1}, strength = 0.5) {
    if (this.reduced) return;
    this.returning = false;
    const amount = THREE.MathUtils.clamp(strength, 0, 1);
    this.hv -= 5.7 * amount;
    this.lv[0] += normal.x * amount * 3.2;
    this.lv[1] += normal.y * amount * 3.2;
    this.sv -= normal.x * amount * 2.2;
  }
  merge() { if (!this.reduced) { this.height = 0.80; this.hv = 4.3; } }
  update(dt) {
    this.accumulator += Math.min(Math.max(dt, 0), 0.1);
    while (this.accumulator + 1e-9 >= STEP) {
      this.accumulator -= STEP;
      this.step(STEP);
    }
  }
  step(dt) {
    this.clock += dt;
    const tracking = this.held || this.returning || this.reduced;
    let target = this.held ? 1 - (this.reduced ? 0.10 : 0.28) * this.strength : 1 + 0.005 * Math.sin(this.clock * 2.4 + this.phase);
    if (this.returning) target = 1;
    [this.height, this.hv] = spring(this.height, this.hv, target, tracking ? 8 : 4.4, tracking ? 1 : 0.34, dt);
    if (this.height < 0.72 || this.height > 1.16) {
      this.height = THREE.MathUtils.clamp(this.height, 0.72, 1.16);
      this.hv *= -0.15;
    }
    for (let axis = 0; axis < 2; axis++) {
      const leanTarget = this.held ? -this.direction[axis] * this.strength * (this.reduced ? 0.03 : 0.13) : 0;
      [this.lean[axis], this.lv[axis]] = spring(this.lean[axis], this.lv[axis], leanTarget, tracking ? 8 : 4.4, tracking ? 1 : 0.4, dt);
      this.lean[axis] = THREE.MathUtils.clamp(this.lean[axis], -0.18, 0.18);
      const crestTarget = this.reduced ? 0 : -this.lean[axis] * 1.25 + (axis ? (1 - this.height) * 0.28 : 0);
      [this.crest[axis], this.cv[axis]] = spring(this.crest[axis], this.cv[axis], crestTarget, 5.2, this.returning ? 0.7 : 0.3, dt);
      this.crest[axis] = THREE.MathUtils.clamp(this.crest[axis], -0.23, 0.23);
      const limbTarget = this.reduced ? 0 : (axis ? this.lean[1] * 0.7 : (this.height - 1) * 0.75 + this.hv * 0.022);
      [this.limb[axis], this.limbv[axis]] = spring(this.limb[axis], this.limbv[axis], limbTarget, 3.7, this.returning ? 0.7 : 0.34, dt);
      this.limb[axis] = THREE.MathUtils.clamp(this.limb[axis], -0.22, 0.22);
      const offsetTarget = this.held ? -this.direction[axis] * this.strength * (this.reduced ? 0.06 : 0.17) : 0;
      [this.offset[axis], this.ov[axis]] = spring(this.offset[axis], this.ov[axis], offsetTarget, tracking ? 8 : 6.5, tracking ? 1 : 0.5, dt);
    }
    const squeezeTarget = this.held && !this.reduced ? -this.direction[0] * this.strength * 0.03 : 0;
    [this.squeeze, this.sv] = spring(this.squeeze, this.sv, squeezeTarget, 5, tracking ? 0.8 : 0.35, dt);
    this.squeeze = THREE.MathUtils.clamp(this.squeeze, -0.065, 0.065);
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
  camera.position.set(0, 14, 11);
  camera.lookAt(0, 0.35, 0);
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
  const results = await Promise.all(keys.map(key => loader.loadAsync(new URL(`../assets/${key}.glb`, import.meta.url).href)));
  const templates = Object.fromEntries(keys.map((key, index) => [key, results[index]]));
  Object.values(templates).forEach(gltf => prepareMaterials(gltf.scene));
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
  const entries = new Map(), departing = [], crumbs = [];
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
    model.rotation.x = -0.30; model.scale.setScalar(SIZES[bun.tier]);
    visual.add(model); scene.add(group);
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
    const entry = {id: bun.id, tier: bun.tier, group, visual, model, bones, authored, shadow,
      motion, clips: templates[key].animations, mixer: new THREE.AnimationMixer(model), action: null,
      pendingIdle: false, nextBlink: 2.8 + (bun.id * 1.17) % 2.5, age: 0, position: {x: bun.position.x, y: bun.position.y}};
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
        case 'merge': if (entry) { entry.motion.merge(); play(entry, reduced ? 'idle' : 'merge'); popCrumbs(entry.position); } break;
        case 'jelly': jellyAge = 0; jellyStrength = event.strength ?? 0.7; break;
        case 'gate': gateOpen = true; gateAge = 0; if (entry) popCrumbs({x: 0, y: 3.45}); break;
        case 'escape': if (entry) { play(entry, reduced ? 'idle' : 'escape'); popCrumbs(entry.position); } break;
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
    const lateral = 1 / Math.sqrt(m.height), sideways = Math.exp(m.squeeze);
    if (b.Body) {
      b.Body.scale.set(lateral * sideways, m.height, lateral / sideways);
      b.Body.quaternion.multiply(ROTATION.setFromEuler(EULER.set(m.lean[1], 0, -m.lean[0])));
    }
    if (b.Crest) b.Crest.quaternion.multiply(ROTATION.setFromEuler(EULER.set(m.crest[1], 0, -m.crest[0])));
    for (const [side, sign] of [['L', -1], ['R', 1]]) {
      if (b['Arm.' + side]) b['Arm.' + side].quaternion.multiply(ROTATION.setFromEuler(EULER.set(m.limb[1], 0, sign * m.limb[0])));
      if (b['Foot.' + side]) b['Foot.' + side].quaternion.multiply(ROTATION.setFromEuler(EULER.set(-m.limb[0] * 0.5, 0, 0)));
    }
    entry.visual.position.set(m.offset[0], 0, -m.offset[1]);
    const hop = Math.max(0, b.Root?.position.y || 0);
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
      const progress = Math.min(1, departingEntry.age / 0.11);
      departingEntry.entry.group.scale.setScalar(Math.max(0.001, 1 - progress));
      departingEntry.entry.shadow.material.opacity = (1 - progress) * 0.4;
      if (progress >= 1) { removeEntry(departingEntry.entry, true); departing.splice(i, 1); }
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
    renderer.render(scene, camera);
  }
  function resize() {
    const rect = canvas.getBoundingClientRect();
    const width = Math.max(1, rect.width), height = Math.max(1, rect.height);
    renderer.setSize(width, height, false);
    const aspect = width / height;
    const halfHeight = Math.max(5.35, 4.15 / aspect);
    camera.left = -halfHeight * aspect; camera.right = halfHeight * aspect;
    camera.top = halfHeight; camera.bottom = -halfHeight; camera.updateProjectionMatrix();
    camera.updateMatrixWorld(true);
  }
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
    for (const {entry} of departing) { scene.remove(entry.group, entry.shadow); entry.shadow.material.dispose(); }
    departing.length = 0;
    for (const {mesh} of crumbs) scene.remove(mesh);
    crumbs.length = 0;
    gateOpen = false; gateAge = 0; jellyAge = 10; jellyStrength = 0;
    jelly.scale.setScalar(1);
    if (wafer) { wafer.visible = true; wafer.position.y = 0; wafer.rotation.z = 0; }
    aimed = null; ring.visible = arrow.visible = false;
  }
  function setReducedMotion(value) {
    reduced = !!value;
    for (const entry of entries.values()) { entry.motion.reduced = reduced; if (reduced) { entry.motion.hv = entry.motion.sv = 0; entry.motion.lv.fill(0); } }
    if (reduced) { for (const {mesh} of crumbs) scene.remove(mesh); crumbs.length = 0; jelly.scale.setScalar(1); }
  }
  function inspect() {
    return {renderer: 'Three.js WebGL / real GLB meshes', exposure: renderer.toneMappingExposure,
      gateOpen, aimed, reducedMotion: reduced, count: entries.size,
      buns: [...entries.values()].map(entry => ({id: entry.id, tier: entry.tier, height: entry.motion.height,
        held: entry.motion.held, offset: {x: entry.motion.offset[0], y: entry.motion.offset[1]},
        crest: [...entry.motion.crest], limbs: [...entry.motion.limb],
        volume: entry.bones.Body ? entry.bones.Body.scale.x * entry.bones.Body.scale.y * entry.bones.Body.scale.z : 1}))};
  }
  resize();
  const observer = new ResizeObserver(resize); observer.observe(canvas);
  window.addEventListener('resize', resize);
  return {setBuns, syncEvents, aim, cancelAim, resize, render, worldFromScreen, screenFromWorld,
    pickBun, reset, setReducedMotion, inspect, debug: inspect,
    capture: () => { renderer.render(scene, camera); return canvas.toDataURL('image/png'); },
    dispose: () => { observer.disconnect(); window.removeEventListener('resize', resize); reset(); renderer.dispose(); }};
}
