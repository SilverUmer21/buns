// Presentation-only timelines. Simulation and colliders do not depend on these
// poses; they are sampled from elapsed time rather than incrementally integrated.
const clamp01 = value => Math.max(0, Math.min(1, value));
const easeOut = t => 1 - Math.pow(1 - clamp01(t), 3);
const smooth = t => { t = clamp01(t); return t * t * (3 - 2 * t); };

// Let the two friends gather first, then reveal the new bun with a soft overshoot.
export function mergeArrival(age) {
  const t = Math.max(0, age);
  if (t < 0.10) return 0.12 + 0.08 * smooth(t / 0.10);
  if (t < 0.28) return 0.20 + 0.90 * easeOut((t - 0.10) / 0.18);
  if (t < 0.55) return 1.10 - 0.10 * smooth((t - 0.28) / 0.27);
  return 1;
}

export function mergeDeparture(age) {
  const progress = smooth(age / 0.20);
  return {progress, scale: Math.max(0.001, 1 - progress), opacity: 1 - progress};
}

// A quick anticipation, joyful hop, landing and a smaller after-hop. These
// offsets are visual only and end exactly in the neutral pose.
export function escapePose(age) {
  const t = Math.max(0, age);
  let y = 0, sy = 1, tilt = 0;
  if (t < 0.12) {
    sy = 1 - 0.11 * smooth(t / 0.12);
  } else if (t < 0.56) {
    const p = (t - 0.12) / 0.44;
    y = 0.32 * Math.sin(Math.PI * p);
    sy = 1 - 0.11 * (1 - smooth(p / 0.16)) + 0.10 * Math.sin(Math.PI * p);
    tilt = 0.12 * Math.sin(Math.PI * p) * Math.sin(Math.PI * 2 * p);
  } else if (t < 0.68) {
    const p = (t - 0.56) / 0.12;
    sy = 1 - 0.08 * Math.sin(Math.PI * p);
  } else if (t < 0.98) {
    const p = (t - 0.68) / 0.30;
    y = 0.12 * Math.sin(Math.PI * p);
    sy = 1 + 0.04 * Math.sin(Math.PI * p);
    tilt = -0.06 * Math.sin(Math.PI * p);
  }
  return {y, scaleY: sy, scaleXZ: 1 / Math.sqrt(sy), tilt, done: t >= 0.98};
}

// Small local star glints give the merge and escape a legible finish without
// a full-screen effect. All meshes and materials are disposed on reset.
export function createEventEffects(THREE, scene, floor) {
  const effects = [];
  const shape = new THREE.Shape();
  for (let i = 0; i < 10; i++) {
    const a = Math.PI / 2 + i * Math.PI / 5;
    const r = i % 2 ? 0.045 : 0.10;
    if (i === 0) shape.moveTo(Math.cos(a) * r, Math.sin(a) * r);
    else shape.lineTo(Math.cos(a) * r, Math.sin(a) * r);
  }
  shape.closePath();
  const geometry = new THREE.ShapeGeometry(shape);
  function emit(pos, kind, tier = 1) {
    const count = kind === 'escape' ? 7 : 4;
    for (let i = 0; i < count; i++) {
      const material = new THREE.MeshBasicMaterial({color: tier === 2 && i % 2 ? '#f2b1ad' : '#efd088', transparent: true, opacity: 0, depthWrite: false, side: THREE.DoubleSide, toneMapped: false});
      const mesh = new THREE.Mesh(geometry, material);
      mesh.rotation.x = -Math.PI / 2;
      mesh.position.set(pos.x, floor + 0.05, -pos.y);
      scene.add(mesh);
      effects.push({mesh, x: pos.x, z: -pos.y, angle: i * Math.PI * 2 / count + 0.3, age: 0,
        delay: kind === 'escape' ? i * 0.025 : 0.10 + i * 0.015, duration: kind === 'escape' ? 0.65 : 0.42,
        distance: kind === 'escape' ? 0.85 : 0.55});
    }
  }
  function update(dt) {
    for (let i = effects.length - 1; i >= 0; i--) {
      const e = effects[i]; e.age += Math.max(0, dt);
      const t = clamp01((e.age - e.delay) / e.duration);
      const radius = 0.28 + e.distance * easeOut(t);
      e.mesh.position.set(e.x + Math.cos(e.angle) * radius, floor + 0.06 + 0.25 * Math.sin(Math.PI * t), e.z + Math.sin(e.angle) * radius);
      e.mesh.rotation.z = t * 0.8;
      e.mesh.scale.setScalar(0.55 + 0.45 * Math.sin(Math.PI * t));
      e.mesh.material.opacity = e.age < e.delay ? 0 : 0.8 * Math.sin(Math.PI * t);
      if (e.age >= e.delay + e.duration) { scene.remove(e.mesh); e.mesh.material.dispose(); effects.splice(i, 1); }
    }
  }
  function reset() { for (const e of effects) { scene.remove(e.mesh); e.mesh.material.dispose(); } effects.length = 0; }
  function dispose() { reset(); geometry.dispose(); }
  return {emit, update, reset, dispose};
}
