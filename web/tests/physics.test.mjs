import assert from 'node:assert/strict';
import test from 'node:test';
import { Solver, STEP, SOLUTION, RADII } from '../dist/js/physics.js';

function settle(solver) {
  for (let i = 0; i < 1800; i++) {
    solver.step();
    if (solver.won || solver.buns.every(bun => bun.velocity.x === 0 && bun.velocity.y === 0)) return;
  }
  throw new Error('Physics did not settle within fifteen seconds');
}

function fixture() {
  const solver = new Solver();
  const schedule = [];
  for (const shot of SOLUTION) {
    schedule.push({ ...shot, tick: solver.ticks });
    assert.equal(solver.shoot(shot.id, { x: shot.vx, y: shot.vy }), true);
    settle(solver);
    solver.events.length = 0;
  }
  return { solver, schedule };
}

test('the actual four-shot route merges four Pips and escapes with one Mango', () => {
  const { solver } = fixture();
  assert.equal(solver.won, true);
  assert.equal(solver.gateOpen, true);
  assert.equal(solver.shots, 4);
  assert.equal(solver.buns.length, 1);
  assert.equal(solver.buns[0].tier, 3);
});

for (const fps of [30, 60, 120]) {
  test(`fixed tick replay is identical at ${fps} render FPS`, () => {
    const baseline = fixture();
    const solver = new Solver();
    let accumulator = 0, nextShot = 0;
    for (let frame = 0; frame < fps * 60 && !solver.won; frame++) {
      accumulator += 1 / fps;
      while (accumulator + 1e-10 >= STEP && !solver.won) {
        if (nextShot < baseline.schedule.length && solver.ticks === baseline.schedule[nextShot].tick) {
          const shot = baseline.schedule[nextShot++];
          assert.equal(solver.shoot(shot.id, { x: shot.vx, y: shot.vy }), true);
        }
        solver.step();
        solver.events.length = 0;
        accumulator -= STEP;
      }
    }
    assert.deepEqual(solver.snapshot(), baseline.solver.snapshot());
  });
}

for (const tier of [1, 2, 3]) {
  test(`gate checks tier ${tier}, even at negligible speed`, () => {
    const solver = new Solver();
    solver.buns = [];
    solver.addBun(tier, { x: 0, y: 3.45 - RADII[tier] - 0.25 }, { x: 0, y: 0.01 });
    solver.step();
    assert.equal(solver.gateOpen, tier === 3);
    assert.ok(solver.buns[0].position.y < 3.45);
  });
}

test('Undo snapshots are independent and restore the complete pre-shot state', () => {
  const solver = new Solver();
  const before = solver.snapshot();
  solver.shoot(1, { x: 0, y: 5.4 });
  settle(solver);
  assert.notDeepEqual(solver.snapshot(), before);
  solver.restore(before);
  assert.deepEqual(solver.snapshot(), before);
  solver.buns[0].position.x += 1;
  assert.equal(before.buns[0].position.x, -1.48);
});

test('maximum-speed shot cannot tunnel through the jelly', () => {
  const solver = new Solver();
  solver.buns = [];
  solver.addBun(1, { x: 0, y: -2 }, { x: 0, y: 12 });
  let hit = false;
  for (let i = 0; i < 90; i++) {
    solver.step();
    const bun = solver.buns[0];
    assert.ok(Math.hypot(bun.position.x, bun.position.y - 1.38) >= 1.27 - 1e-8);
    hit ||= solver.events.some(event => event.type === 'jelly');
    solver.events.length = 0;
  }
  assert.equal(hit, true);
  assert.ok(solver.buns[0].velocity.y < 0);
});

test('vertical and horizontal walls reflect inward instead of pinning fast buns', () => {
  for (const [x, y, vx, vy] of [[2.72, -2, 12, 0], [-2.72, -2, -12, 0], [2, -4.54, 0, -12], [2, 4.54, 0, 12]]) {
    const solver = new Solver();
    solver.gateOpen = true;
    solver.buns = [];
    solver.addBun(1, { x, y }, { x: vx, y: vy });
    solver.step();
    const velocity = solver.buns[0].velocity;
    assert.ok(vx ? velocity.x * vx < 0 : velocity.y * vy < 0);
  }
});

test('a merge conserves mass-weighted planar momentum', () => {
  const solver = new Solver();
  solver.buns = [];
  solver.addBun(1, { x: -0.4, y: 0 }, { x: 2, y: 1 });
  solver.addBun(1, { x: 0.4, y: 0 }, { x: -1, y: 3 });
  solver._contacts();
  assert.equal(solver.buns.length, 1);
  assert.equal(solver.buns[0].tier, 2);
  assert.deepEqual(solver.buns[0].velocity, { x: 0.5, y: 2 });
});

test('triple contacts consume a bun only once per merge pass', () => {
  const solver = new Solver();
  solver.buns = [];
  for (const x of [-0.5, 0, 0.5]) solver.addBun(1, { x, y: -2 });
  solver._contacts();
  assert.equal(solver.buns.length, 2);
  assert.equal(solver.events.filter(event => event.type === 'merge').length, 1);
  assert.deepEqual(solver.buns.map(bun => bun.tier).sort(), [1, 2]);
});

test('unequal tiers bounce and maximum tiers never invent an upgrade', () => {
  for (const tiers of [[1, 2], [3, 3]]) {
    const solver = new Solver();
    solver.buns = [];
    solver.addBun(tiers[0], { x: -0.4, y: -2 }, { x: 2, y: 0 });
    solver.addBun(tiers[1], { x: 0.4, y: -2 });
    solver._contacts();
    assert.deepEqual(solver.buns.map(bun => bun.tier), tiers);
    assert.equal(solver.events.some(event => event.type === 'merge'), false);
  }
});

test('input refuses an invalid, already-moving or completed shot and caps launch speed', () => {
  const solver = new Solver();
  assert.equal(solver.shoot(999, { x: 1, y: 2 }), false);
  assert.equal(solver.shoot(1, { x: NaN, y: 2 }), false);
  assert.equal(solver.shoot(1, { x: 300, y: 400 }), true);
  assert.ok(Math.abs(Math.hypot(...Object.values(solver.findBun(1).velocity)) - 12) < 1e-12);
  assert.equal(solver.shoot(2, { x: 1, y: 1 }), false);
  solver.won = true;
  solver.findBun(1).velocity = { x: 0, y: 0 };
  assert.equal(solver.shoot(2, { x: 1, y: 1 }), false);
});
