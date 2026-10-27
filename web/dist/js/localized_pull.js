import * as THREE from 'three';

// One-sided dough deformation. All skinned pieces use the same post-skinning
// field, so facial features stay registered to the dough. The trailing edge is
// fixed; the finger-facing edge stretches and rounds outward.
export function samplePullDeformation(point, axis, amount, center = [0, 0.84, 0], radius = 0.76) {
  const smooth = (lo, hi, x) => { const q = Math.max(0, Math.min(1, (x-lo)/(hi-lo))); return q*q*(3-2*q); };
  const raw = position => {
    const p = position.map((v, i) => v - center[i]);
    const s = p.reduce((sum, v, i) => sum + v * axis[i], 0);
    const g = smooth(-radius, radius, s);
    return position.map((v, i) => v + axis[i]*amount*g + (p[i]-axis[i]*s)*(amount*0.30*g));
  };
  const p = point.map((v, i) => v-center[i]);
  const s = p.reduce((sum, v, i) => sum + v*axis[i], 0);
  const mask = smooth(.18,.42,point[2]) * (1-smooth(.52,.76,Math.abs(point[0])))
    * (1-smooth(.35,.60,Math.abs(point[1]-center[1]))) * smooth(0,.25,(s+radius)/(2*radius));
  const anchor = [0,center[1],.60], movedAnchor = raw(anchor), warped = raw(point);
  return point.map((v,i) => warped[i]*(1-mask) + (v+movedAnchor[i]-anchor[i])*mask);
}

const helpers = `
uniform vec3 bunPullAxis;
uniform float bunPullAmount;
uniform float bunPullCenterY;
uniform bool bunFaceRigid;
float bunPullWeight(float q) { q = clamp(q, 0.0, 1.0); return q*q*(3.0-2.0*q); }
float bunFaceMask(vec3 p) {
  float q = (dot(p-vec3(0.0,bunPullCenterY,0.0),bunPullAxis)+0.76)/1.52;
  return smoothstep(0.18, 0.42, p.z) * (1.0-smoothstep(0.52, 0.76, abs(p.x)))
    * (1.0-smoothstep(0.35, 0.60, abs(p.y-bunPullCenterY))) * smoothstep(0.0, 0.25, q);
}
vec3 bunRawPullPosition(vec3 p) {
  vec3 c = vec3(0.0, bunPullCenterY, 0.0);
  vec3 r = p-c;
  float s = dot(r, bunPullAxis);
  float w = bunPullWeight((s + 0.76) / 1.52);
  return p + bunPullAxis * bunPullAmount * w + (r - bunPullAxis*s) * (bunPullAmount*0.30*w);
}
vec3 bunPullFacePosition(vec3 p) {
  vec3 anchor = vec3(0.0, bunPullCenterY, 0.60);
  return p + bunRawPullPosition(anchor) - anchor;
}
vec3 bunPullPosition(vec3 p) {
  return mix(bunRawPullPosition(p), bunPullFacePosition(p), bunFaceMask(p));
}
vec3 bunPullNormal(vec3 p, vec3 n) {
  vec3 r = p - vec3(0.0, bunPullCenterY, 0.0);
  float s = dot(r, bunPullAxis);
  float q = clamp((s + 0.76) / 1.52, 0.0, 1.0);
  float w = bunPullWeight(q);
  float derivative = 6.0*q*(1.0-q)/1.52;
  float sideScale = 1.0 + bunPullAmount*0.30*w;
  float alongScale = 1.0 + bunPullAmount*derivative;
  vec3 perp = n - bunPullAxis*dot(n,bunPullAxis);
  float along = (dot(n,bunPullAxis) - dot(perp,r-bunPullAxis*s)*bunPullAmount*0.30*derivative/sideScale)/alongScale;
  return normalize(mix(perp/sideScale + bunPullAxis*along, n, bunFaceMask(p)));
}
`;

export function createLocalizedPull(model, centerY = 0.84) {
  const uniforms = {
    bunPullAxis: {value: new THREE.Vector3(1, 0, 0)},
    bunPullAmount: {value: 0},
    bunPullCenterY: {value: centerY},
  };
  const cloned = new Map();
  model.traverse(mesh => {
    if (!mesh.isSkinnedMesh) return;
    const isFace = /(?:chocolate|eye_light|blush|smile|tongue)(?:_[lr])?$/i.test(mesh.name);
    const cloneMaterial = original => {
      let variants = cloned.get(original);
      if (!variants) { variants = new Map(); cloned.set(original, variants); }
      if (variants.has(isFace)) return variants.get(isFace);
      const material = original.clone();
      material.onBeforeCompile = shader => {
        Object.assign(shader.uniforms, uniforms);
        shader.uniforms.bunFaceRigid = {value: isFace};
        shader.vertexShader = helpers + shader.vertexShader;
        shader.vertexShader = shader.vertexShader.replace('#include <skinnormal_vertex>', '#include <skinnormal_vertex>\nif (!bunFaceRigid) objectNormal = bunPullNormal(position, objectNormal);');
        shader.vertexShader = shader.vertexShader.replace('#include <skinning_vertex>', '#include <skinning_vertex>\ntransformed = bunFaceRigid ? bunPullFacePosition(transformed) : bunPullPosition(transformed);');
      };
      material.customProgramCacheKey = () => 'bunbreak-local-pull-v1';
      variants.set(isFace, material);
      return material;
    };
    mesh.material = Array.isArray(mesh.material) ? mesh.material.map(cloneMaterial) : cloneMaterial(mesh.material);
  });
  return {
    uniforms,
    update(axis, amount) { uniforms.bunPullAxis.value.copy(axis); uniforms.bunPullAmount.value = amount; },
    dispose() { for (const variants of cloned.values()) for (const material of variants.values()) material.dispose(); },
  };
}
