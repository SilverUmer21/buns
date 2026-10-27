import * as THREE from 'three';

// A monotone teardrop field: preserve the anchored bulb, extend the pulled
// shoulder and taper the terminal cap. Facial details sit on the fuller
// shoulder; limbs retain their round shape instead of becoming part of the tip.
export function samplePullDeformation(point, axis, amount, center = [0, 0.84, 0], radius = 0.76) {
  const smooth = (lo, hi, x) => { const q = Math.max(0, Math.min(1, (x-lo)/(hi-lo))); return q*q*(3-2*q); };
  const raw = position => {
    const p = position.map((v, i) => v - center[i]);
    const s = p.reduce((sum, v, i) => sum + v * axis[i], 0);
    const q = (s+radius)/(2*radius);
    const tip = smooth(.35,1,q);
    const taper = 1 - Math.min(amount/.58,1)*.48*smooth(.38,.98,q);
    return position.map((v, i) => center[i] + axis[i]*(s+amount*1.45*tip) + (p[i]-axis[i]*s)*taper);
  };
  return raw(point);
}

const helpers = `
uniform vec3 bunPullAxis;
uniform float bunPullAmount;
uniform float bunPullCenterY;
uniform int bunPullKind;
vec3 bunRawPullPosition(vec3 p) {
  vec3 c = vec3(0.0, bunPullCenterY, 0.0);
  vec3 r = p-c;
  float s = dot(r, bunPullAxis);
  float q = (s + 0.76) / 1.52;
  float tip = smoothstep(0.35, 1.0, q);
  float taper = 1.0-min(bunPullAmount/0.58,1.0)*0.48*smoothstep(0.38,0.98,q);
  return c + bunPullAxis*(s+bunPullAmount*1.45*tip) + (r-bunPullAxis*s)*taper;
}
float bunFaceTilt() { return -0.50*max(bunPullAxis.z,0.0)*min(bunPullAmount/0.58,1.0); }
vec3 bunFaceRotate(vec3 p) {
  float a = bunFaceTilt();
  return vec3(p.x,cos(a)*p.y-sin(a)*p.z,sin(a)*p.y+cos(a)*p.z);
}
vec3 bunPullFacePosition(vec3 p) {
  vec3 anchor = vec3(0.0,bunPullCenterY,0.60);
  float front = max(bunPullAxis.z,0.0)*min(bunPullAmount/0.58,1.0);
  vec3 shoulder = anchor+vec3(0.0,0.50*front,-0.22*front);
  vec3 local = bunFaceRotate(p-anchor);
  local.x *= 1.0-0.15*front;
  return bunRawPullPosition(shoulder)+local;
}
vec3 bunPullLimbPosition(vec3 p) {
  vec3 anchor=vec3(0.0,bunPullCenterY,0.0);
  return p+bunRawPullPosition(anchor)-anchor;
}
vec3 bunPullPosition(vec3 p) {
  return bunRawPullPosition(p);
}
vec3 bunPullNormal(vec3 p, vec3 n) {
  vec3 r = p - vec3(0.0, bunPullCenterY, 0.0);
  float s = dot(r, bunPullAxis);
  float q = (s + 0.76) / 1.52;
  float u = clamp((q-0.35)/0.65,0.0,1.0);
  float v = clamp((q-0.38)/0.60,0.0,1.0);
  float tipDerivative = 6.0*u*(1.0-u)/(0.65*1.52);
  float taperStrength = min(bunPullAmount/0.58,1.0)*0.48;
  float sideScale = 1.0-taperStrength*smoothstep(0.38,0.98,q);
  float sideDerivative = -taperStrength*6.0*v*(1.0-v)/(0.60*1.52);
  float alongScale = 1.0+bunPullAmount*1.45*tipDerivative;
  vec3 perp = n-bunPullAxis*dot(n,bunPullAxis);
  float along = (dot(n,bunPullAxis)-dot(perp,r-bunPullAxis*s)*sideDerivative/sideScale)/alongScale;
  return normalize(perp/sideScale+bunPullAxis*along);
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
    mesh.geometry.computeBoundingBox();
    const bounds = mesh.geometry.boundingBox;
    const face = /(?:chocolate|eye_light|smile|tongue)(?:_[lr])?$/i.test(mesh.name);
    const cheek = /blush(?:_[lr])?$/i.test(mesh.name);
    // Body/face/appendage variants share the shader program but keep their
    // own material uniforms. Body meshes span more than one local Z unit.
    const kind = face ? 1 : cheek ? 3 : bounds.max.z-bounds.min.z < 1 ? 2 : 0;
    const cloneMaterial = original => {
      let variants = cloned.get(original);
      if (!variants) { variants = new Map(); cloned.set(original, variants); }
      if (variants.has(kind)) return variants.get(kind);
      const material = original.clone();
      material.onBeforeCompile = shader => {
        Object.assign(shader.uniforms, uniforms);
        shader.uniforms.bunPullKind = {value: kind};
        shader.vertexShader = helpers + shader.vertexShader;
        shader.vertexShader = shader.vertexShader.replace('#include <skinnormal_vertex>', '#include <skinnormal_vertex>\nif (bunPullKind == 0) objectNormal = bunPullNormal(position, objectNormal); else if (bunPullKind == 1 || bunPullKind == 3) objectNormal = bunFaceRotate(objectNormal);');
        shader.vertexShader = shader.vertexShader.replace('#include <skinning_vertex>', '#include <skinning_vertex>\ntransformed = bunPullKind == 3 ? bunPullFacePosition(transformed)+vec3(0.0,0.0,(0.15+0.03*max(bunPullAxis.z,0.0))*min(bunPullAmount/0.58,1.0)) : bunPullKind == 1 ? bunPullFacePosition(transformed) : bunPullKind == 2 ? bunPullLimbPosition(transformed) : bunPullPosition(transformed);');
      };
      material.customProgramCacheKey = () => 'bunbreak-teardrop-pull-v2';
      variants.set(kind, material);
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
