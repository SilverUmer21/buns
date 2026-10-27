import * as THREE from 'three';

// A quiet, repeatable micro-relief. It changes how light catches the fruit
// dough without painting noisy color onto the characters or changing Pip.
export function makeDoughRelief() {
  const size = 64, data = new Uint8Array(size * size * 4);
  let seed = 0x91a7c3;
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    const grain = ((seed >>> 24) / 255 - .5) * 24;
    const soft = 7 * Math.sin(x * Math.PI * 2 / size * 3) * Math.sin(y * Math.PI * 2 / size * 2);
    const value = Math.max(0, Math.min(255, Math.round(128 + grain + soft)));
    const i = (y * size + x) * 4;
    data[i] = data[i + 1] = data[i + 2] = value; data[i + 3] = 255;
  }
  const texture = new THREE.DataTexture(data, size, size, THREE.RGBAFormat);
  texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
  texture.minFilter = THREE.LinearMipmapLinearFilter;
  texture.magFilter = THREE.LinearFilter;
  texture.generateMipmaps = true;
  texture.repeat.set(2, 2);
  texture.colorSpace = THREE.NoColorSpace;
  texture.needsUpdate = true;
  return texture;
}

export function applyFruitDoughRelief(root, texture) {
  const targets = new Set(['Strawberry dough', 'Mango dough']);
  root.traverse(node => {
    if (!node.isMesh) return;
    for (const material of Array.isArray(node.material) ? node.material : [node.material]) {
      if (material && targets.has(material.name)) {
        material.bumpMap = texture;
        material.bumpScale = 0.024;
        material.needsUpdate = true;
      }
    }
  });
}
