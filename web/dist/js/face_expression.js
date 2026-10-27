// A lightweight face rig built from the authored smile, tongue and eye bones.
// Both mouth pieces share the smile's pivot, so the tongue stays inside the
// opening as it changes size. The body shader/rig carries every piece together.
const clamp = (n, lo, hi) => Math.max(lo, Math.min(hi, n));

export function facePose(expression, pull, held, reduced = false) {
  const feeling = clamp(Number.isFinite(expression) ? expression : 0, -0.65, 0.55);
  const attention = held && !reduced ? 1 : 0;
  const effort = Math.max(0, feeling);
  return {
    // Positive expression means effort; negative means surprise/delight.
    mouth: -feeling,
    eyeHeight: clamp(1 - effort * 0.50 + Math.max(0, -feeling) * 0.12, 0.72, 1.08),
    eyeX: -clamp(pull?.[0] || 0, -1, 1) * 0.045 * attention,
    eyeY: -clamp(pull?.[1] || 0, -1, 1) * 0.030 * attention,
  };
}

export function prepareFaceExpression(model, THREE) {
  const faces = [];
  model.traverse(node => {
    if (node.isSkinnedMesh && /(?:_smile|_tongue)$/i.test(node.name)) faces.push(node);
  });
  const smile = faces.find(node => /_smile$/i.test(node.name));
  if (!smile) return [];
  smile.geometry.computeBoundingBox();
  const pivot = smile.geometry.boundingBox.getCenter(new THREE.Vector3());
  for (const node of faces) {
    const geometry = node.geometry.clone();
    const position = geometry.attributes.position;
    const offsets = new Float32Array(position.count * 3);
    for (let i = 0; i < position.count; i++) {
      offsets[i * 3] = (position.getX(i) - pivot.x) * 0.20;
      offsets[i * 3 + 1] = (position.getY(i) - pivot.y) * 0.50;
      // Move the expression just in front of the curved dough as it pinches.
      offsets[i * 3 + 2] = -0.018;
    }
    geometry.morphAttributes.position = [new THREE.Float32BufferAttribute(offsets, 3)];
    geometry.morphTargetsRelative = true;
    node.geometry = geometry;
    node.updateMorphTargets();
  }
  return faces;
}

export function applyFaceExpression(entry) {
  const m = entry.motion;
  const pose = facePose(m.expression, m.pull, m.held, m.reduced);
  for (const side of ['L', 'R']) {
    const eye = entry.bones['Eye.' + side];
    if (!eye) continue;
    eye.scale.y *= pose.eyeHeight;
    eye.position.x += pose.eyeX;
    eye.position.y += pose.eyeY;
  }
  for (const shape of entry.mouthShapes) {
    if (shape.morphTargetInfluences) shape.morphTargetInfluences[0] = pose.mouth;
  }
}
