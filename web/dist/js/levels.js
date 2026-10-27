// The six handoff puzzles. Physics owns all results; fixtures are reproducible
// shots, not scripted teleports. Star thresholds are provisional pending playtests.
const bounds = {minX: -3.28, maxX: 3.28, minY: -5.1, maxY: 5.1};
const shared = {bounds, gateY: 3.45, gateHalfDepth: 0.26, exit: {x: 0, y: 4.43}, exitRadius: 0.88};
const shot = (id, vx, vy) => ({id, vx, vy});

export const LEVELS = [
  {id: 'hello-bun', title: 'Hello bun', goal: 'Flick Pip to the escape plate.', requiredTier: 1,
    spawns: [{tier: 1, x: 0, y: -2}], bumpers: [],
    solution: [shot(1, 0, 10)], mastery: 1, generous: 3},
  {id: 'better-together', title: 'Better together', goal: 'Merge two Pips into a Berry.', requiredTier: 2,
    spawns: [{tier: 1, x: 0, y: -1.5}, {tier: 1, x: 0, y: .1}], bumpers: [],
    solution: [shot(1, 0, 7), shot(3, 0, 9)], mastery: 2, generous: 4},
  {id: 'jelly-belly', title: 'Jelly belly', goal: 'Bounce off the jelly, then find the plate.', requiredTier: 1,
    spawns: [{tier: 1, x: -1.4, y: -2.8}], bumpers: [{position: {x: 0, y: 0}, radius: .72}],
    solution: [shot(1, .5, 5), shot(1, -8, 7)], mastery: 2, generous: 4, requiresJelly: true},
  {id: 'mango-magic', title: 'Mango magic', goal: 'Merge two Berries into a Mango.', requiredTier: 3,
    spawns: [{tier: 2, x: 0, y: -1.6}, {tier: 2, x: 0, y: .25}], bumpers: [],
    solution: [shot(1, 0, 7), shot(3, 0, 9)], mastery: 2, generous: 4},
  {id: 'the-big-escape', title: 'The big escape', goal: 'Make a Mango. Crack the wafer.', requiredTier: 3,
    spawns: [{tier: 1, x: -1.48, y: -3.15}, {tier: 1, x: 1.48, y: -3.15},
      {tier: 1, x: -1.48, y: -.7}, {tier: 1, x: 1.48, y: -.7}],
    bumpers: [{position: {x: 0, y: 1.38}, radius: .72}],
    solution: [shot(1, 0, 5.4), shot(2, 0, 5.4), shot(5, 7, 0), shot(7, -4, 9)], mastery: 4, generous: 6},
  {id: 'one-happy-family', title: 'One happy family', goal: 'Bring Pips and Berry together.', requiredTier: 3,
    spawns: [{tier: 1, x: -1.4, y: -2.7}, {tier: 1, x: -1.4, y: -.5}, {tier: 2, x: 1.4, y: -.3}],
    bumpers: [], solution: [shot(1, 0, 5.5), shot(4, 7, 0), shot(5, -4, 9)], mastery: 3, generous: 5},
];

/** Load one level without changing physics implementation or visual state. */
export function applyLevel(solver, index) {
  if (!Number.isInteger(index) || index < 0 || index >= LEVELS.length) throw new RangeError('Unknown puzzle');
  const level = LEVELS[index];
  solver.reset();
  solver.level = structuredClone({...shared, title: level.title, requiredTier: level.requiredTier, bumpers: level.bumpers});
  solver.buns = [];
  solver.nextId = 1;
  solver.events = [];
  for (const spawn of level.spawns) solver.addBun(spawn.tier, {x: spawn.x, y: spawn.y});
  return level;
}
