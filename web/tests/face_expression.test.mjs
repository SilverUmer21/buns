import {test} from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from '../dist/vendor/three.module.js';
import {facePose, prepareFaceExpression, applyFaceExpression} from '../dist/js/face_expression.js';

test('eyes follow the finger and effort and delight have distinct expressions', () => {
  const effort = facePose(.40, [1, -.5], true);
  const joy = facePose(-.4, [0, 0], false);
  assert.ok(effort.eyeX < 0 && effort.eyeY > 0);
  assert.ok(effort.eyeHeight < 1 && effort.eyeHeight >= .78 && effort.mouth < 0);
  assert.ok(joy.eyeHeight > 1 && joy.mouth > 0);
  const reduced = facePose(.4, [1, 1], true, true);
  assert.equal(Math.abs(reduced.eyeX), 0);
  assert.equal(Math.abs(reduced.eyeY), 0);
});

test('smile and tongue use the same expression pivot and eye bones reset through authored poses', () => {
  function face(name, points) {
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.Float32BufferAttribute(points.flat(), 3));
    const node = new THREE.SkinnedMesh(geometry, new THREE.MeshBasicMaterial());
    node.name = name;
    return node;
  }
  const smile = face('Bun_smile', [[-1, 0, 1], [1, 2, 1]]);
  const tongue = face('Bun_tongue', [[-.5, 0, 1], [.5, .5, 1]]);
  const model = new THREE.Group(); model.add(smile, tongue);
  const shapes = prepareFaceExpression(model, THREE);
  assert.equal(shapes.length, 2);
  // Both lower vertices are transformed about the smile midpoint (y=1),
  // keeping the tongue inside the mouth as the opening changes.
  assert.ok(Math.abs(smile.geometry.morphAttributes.position[0].getY(0) + .50) < 1e-6);
  assert.ok(Math.abs(tongue.geometry.morphAttributes.position[0].getY(0) + .50) < 1e-6);
  const eyes = {'Eye.L': new THREE.Bone(), 'Eye.R': new THREE.Bone()};
  applyFaceExpression({motion: {expression: .4, pull: [1, 0], held: true}, bones: eyes, mouthShapes: shapes});
  assert.ok(eyes['Eye.L'].position.x < 0 && eyes['Eye.R'].position.x < 0);
  assert.equal(smile.morphTargetInfluences[0], tongue.morphTargetInfluences[0]);
  for (const node of shapes) { node.geometry.dispose(); node.material.dispose(); }
});
