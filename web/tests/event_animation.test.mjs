import test from 'node:test';
import assert from 'node:assert/strict';
import {mergeArrival, mergeDeparture, mergePose, escapePose, createEventEffects} from '../dist/js/event_animation.js';

test('merge gathers the old friends before the new tier pops and settles', () => {
  assert.ok(mergeArrival(0.08) < .01, 'the new bun stays hidden through the contact beat');
  assert.ok(mergeArrival(0.091) >= .82, 'the revealed bun appears at a readable size');
  assert.ok(mergeDeparture(0.08).scale > .8, 'the two friends retain readable faces through contact');
  assert.ok(mergeDeparture(0.10).progress > 0.99);
  assert.ok(mergeArrival(0.25) > 1);
  assert.equal(mergeArrival(0.58), 1);
  assert.ok(mergeDeparture(0.18).scale > 0);
  assert.equal(mergeDeparture(0.18).opacity, 0);
  assert.ok(mergeDeparture(0.08).scaleY < 1, 'the pair visibly compresses while gathering');
  assert.ok(mergePose(0.28).y > .3, 'the new tier rises');
  assert.ok(mergePose(0.57).scaleY < 1, 'the new tier compresses on landing');
  for (let i = 0; i <= 72; i++) {
    const pose = mergePose(i / 100);
    assert.ok(Math.abs(pose.scaleY * pose.scaleXZ ** 2 - 1) < 1e-9);
  }
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
  for (const boundary of [0.25, 0.58]) {
    assert.ok(Math.abs(mergeArrival(boundary - 1e-6) - mergeArrival(boundary + 1e-6)) < 0.0001);
  }
  for (const boundary of [0.09, 0.47, 0.67]) {
    const before = mergePose(boundary - 1e-6), after = mergePose(boundary + 1e-6);
    for (const key of ['y', 'scaleY', 'tilt']) assert.ok(Math.abs(before[key] - after[key]) < 0.0001, `${boundary} ${key}`);
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
