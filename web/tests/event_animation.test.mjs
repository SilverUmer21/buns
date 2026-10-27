import test from 'node:test';
import assert from 'node:assert/strict';
import {mergeArrival, mergeDeparture, escapePose, createEventEffects} from '../dist/js/event_animation.js';

test('merge gathers the old friends before the new tier pops and settles', () => {
  assert.ok(mergeArrival(0.08) < 0.2);
  assert.ok(mergeDeparture(0.15).progress > 0.8);
  assert.ok(mergeArrival(0.28) > 1);
  assert.equal(mergeArrival(0.55), 1);
  assert.ok(mergeDeparture(0.20).scale > 0);
  assert.equal(mergeDeparture(0.20).opacity, 0);
});

test('celebration anticipates, hops, lands, and returns to a volume-preserving rest', () => {
  assert.ok(escapePose(0.10).scaleY < 1);
  assert.ok(escapePose(0.34).y > 0.3);
  assert.ok(escapePose(0.83).y > 0.1);
  assert.deepEqual(escapePose(1), {y: 0, scaleY: 1, scaleXZ: 1, tilt: 0, done: true});
  for (let i = 0; i <= 100; i++) {
    const pose = escapePose(i / 100);
    assert.ok(pose.scaleY > 0 && pose.scaleXZ > 0);
    assert.ok(Math.abs(pose.scaleY * pose.scaleXZ ** 2 - 1) < 1e-9);
  }
});

test('timeline poses are continuous across transition boundaries', () => {
  for (const boundary of [0.10, 0.28, 0.55]) {
    assert.ok(Math.abs(mergeArrival(boundary - 1e-6) - mergeArrival(boundary + 1e-6)) < 0.0001);
  }
  for (const boundary of [0.12, 0.56, 0.68, 0.98]) {
    const before = escapePose(boundary - 1e-6), after = escapePose(boundary + 1e-6);
    for (const key of ['y', 'scaleY', 'tilt']) assert.ok(Math.abs(before[key] - after[key]) < 0.0001, `${boundary} ${key}`);
  }
});

test('local event glints age out and reset releases every active material', () => {
  const disposed = [];
  class Shape { moveTo() {} lineTo() {} closePath() {} }
  class Geometry { dispose() { disposed.push('geometry'); } }
  class Material { constructor(options) { Object.assign(this, options); } dispose() { disposed.push('material'); } }
  class Mesh { constructor(geometry, material) { this.geometry = geometry; this.material = material; this.rotation = {}; this.position = {set(){}}; this.scale = {setScalar(){}}; } }
  const objects = new Set();
  const scene = {add: x => objects.add(x), remove: x => objects.delete(x)};
  const fx = createEventEffects({Shape, ShapeGeometry: Geometry, MeshBasicMaterial: Material, Mesh, DoubleSide: 2}, scene, 0.2);
  fx.emit({x: 0, y: 0}, 'merge', 2);
  assert.equal(objects.size, 4);
  fx.update(2);
  assert.equal(objects.size, 0);
  assert.equal(disposed.filter(item => item === 'material').length, 4);
  fx.emit({x: 1, y: 2}, 'escape');
  assert.equal(objects.size, 7);
  fx.reset();
  assert.equal(objects.size, 0);
  assert.equal(disposed.filter(item => item === 'material').length, 11);
  fx.dispose();
  assert.equal(disposed.filter(item => item === 'geometry').length, 1);
});
