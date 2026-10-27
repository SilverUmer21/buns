import test from 'node:test';
import assert from 'node:assert/strict';
import {Solver, STEP, RADII, SOLUTION} from '../dist/js/physics.js';
import {LEVELS, applyLevel} from '../dist/js/levels.js';

function settle(solver, events) {
  for (let i = 0; i < 1800; i++) {
    solver.step(); events.push(...solver.events); solver.events.length = 0;
    if (solver.won || solver.buns.every(b => b.velocity.x === 0 && b.velocity.y === 0)) return;
  }
  assert.fail('Buns failed to settle');
}

function fixture(index) {
  const solver = new Solver(), level = applyLevel(solver, index), schedule = [], events = [];
  for (const shot of level.solution) {
    schedule.push({...shot, tick: solver.ticks});
    assert.ok(solver.shoot(shot.id, {x: shot.vx, y: shot.vy}), `${level.title}: shot ${shot.id}`);
    settle(solver, events);
  }
  assert.ok(solver.won, `${level.title} reaches the escape plate`);
  assert.equal(solver.buns.filter(b => b.tier === level.requiredTier).length, 1);
  if (level.requiresJelly) assert.ok(events.some(e => e.type === 'jelly'), 'Jelly belly fixture hits the bumper');
  return {solver, schedule, events};
}

test('exactly six distinct stages with valid non-overlapping starts', () => {
  assert.equal(LEVELS.length, 6);
  assert.equal(new Set(LEVELS.map(l => l.id)).size, 6);
  for (let index=0; index<LEVELS.length; index++) {
    const s = new Solver(), level=applyLevel(s,index);
    assert.equal(s.buns.length, level.spawns.length);
    for(let i=0;i<s.buns.length;i++) for(let j=i+1;j<s.buns.length;j++) {
      const a=s.buns[i],b=s.buns[j];
      assert.ok(Math.hypot(a.position.x-b.position.x,a.position.y-b.position.y) >= RADII[a.tier]+RADII[b.tier], level.title);
    }
  }
  assert.throws(() => applyLevel(new Solver(), -1), RangeError);
  assert.throws(() => applyLevel(new Solver(), 6), RangeError);
  assert.deepEqual(LEVELS[4].solution, SOLUTION, 'existing four-shot escape is preserved');
});

test('each introductory fixture actually demonstrates its intended mechanic', () => {
  const mergeTiers = index => fixture(index).events.filter(e => e.type === 'merge').map(e => e.tier);
  assert.deepEqual(mergeTiers(0), []);
  assert.deepEqual(mergeTiers(1), [2]);
  assert.ok(fixture(2).events.some(e => e.type === 'jelly'));
  assert.deepEqual(mergeTiers(3), [3]);
  assert.deepEqual(mergeTiers(4), [2, 2, 3]);
  assert.deepEqual(mergeTiers(5), [2, 3]);
});

test('reset after play restores the selected level and its tier requirement', () => {
  const s = new Solver(); applyLevel(s, 1);
  const initial = s.snapshot();
  s.shoot(1,{x:0,y:7}); settle(s, []);
  assert.notDeepEqual(s.snapshot(),initial);
  applyLevel(s,1);
  assert.deepEqual(s.snapshot(),initial);
  assert.equal(s.level.requiredTier,2);
  assert.equal(s.level.bumpers.length,0);
});

test('an aim preview cloned from a snapshot keeps the selected level geometry and tier', () => {
  const original = new Solver(); applyLevel(original, 2);
  const preview = new Solver(); preview.restore(original.snapshot());
  assert.deepEqual(preview.level, original.level);
  assert.equal(preview.level.requiredTier, 1);
  assert.equal(preview.level.bumpers[0].position.y, 0);
});

for (let index=0; index<LEVELS.length; index++) {
  test(`${LEVELS[index].title}: verified actual-physics solution`, () => fixture(index));
  for (const fps of [30,60,120]) test(`${LEVELS[index].title}: same replay at ${fps} render FPS`, () => {
    const baseline=fixture(index), solver=new Solver(); applyLevel(solver,index);
    let accumulator=0,next=0;
    for(let frame=0;frame<fps*60&&!solver.won;frame++) {
      accumulator+=1/fps;
      while(accumulator+1e-10>=STEP&&!solver.won) {
        if(next<baseline.schedule.length && solver.ticks===baseline.schedule[next].tick) {
          const shot=baseline.schedule[next++];
          assert.ok(solver.shoot(shot.id,{x:shot.vx,y:shot.vy}));
        }
        solver.step(); solver.events.length=0; accumulator-=STEP;
      }
    }
    assert.deepEqual(solver.snapshot(),baseline.solver.snapshot());
  });
}
