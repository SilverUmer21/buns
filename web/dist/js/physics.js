// Fixed-step planar game rules. Rendering and squash rigs never change this state.
export const STEP = 1 / 120;
export const RADII = Object.freeze([0, 0.55, 0.65, 0.77]);
export const MASSES = Object.freeze([0, 1, 2, 4]);
export const MAX_SPEED = 12;
export const DRAG = 1.45;
export const SOLUTION = Object.freeze([
  { id: 1, vx: 0, vy: 5.4 }, { id: 2, vx: 0, vy: 5.4 },
  { id: 5, vx: 7, vy: 0 }, { id: 7, vx: -4, vy: 9 },
]);

const copy = value => structuredClone(value);
const vec = (x = 0, y = 0) => ({ x, y });
const dot = (a, b) => a.x * b.x + a.y * b.y;
const length = a => Math.hypot(a.x, a.y);
const limited = (a, cap) => {
  const magnitude = length(a);
  return magnitude > cap ? vec(a.x * cap / magnitude, a.y * cap / magnitude) : vec(a.x, a.y);
};

export class Solver {
  static STEP = STEP;
  static RADII = RADII;
  static MAX_SPEED = MAX_SPEED;

  constructor() { this.reset(); }

  reset() {
    this.level = {
      title: 'The big escape', requiredTier: 3,
      bounds: { minX: -3.28, maxX: 3.28, minY: -5.1, maxY: 5.1 },
      gateY: 3.45, gateHalfDepth: 0.26,
      exit: vec(0, 4.43), exitRadius: 0.88,
      bumpers: [{ position: vec(0, 1.38), radius: 0.72 }],
    };
    this.buns = [];
    this.events = [];
    this.nextId = 1;
    this.gateOpen = false;
    this.won = false;
    this.shots = 0;
    this.ticks = 0;
    for (const [x, y] of [[-1.48, -3.15], [1.48, -3.15], [-1.48, -0.7], [1.48, -0.7]]) {
      this.addBun(1, vec(x, y));
    }
  }

  addBun(tier, position, velocity = vec()) {
    if (!Number.isInteger(tier) || tier < 1 || tier > 3) throw new RangeError('Unknown bun tier');
    const id = this.nextId++;
    this.buns.push({ id, tier, position: copy(position), previous: copy(position), velocity: copy(velocity) });
    return id;
  }

  findBun(id) { return this.buns.find(bun => bun.id === id) ?? null; }

  isMoving() { return this.buns.some(bun => dot(bun.velocity, bun.velocity) > 0.003); }

  shoot(id, velocity) {
    const bun = this.findBun(id);
    if (!bun || this.won || this.isMoving() || !Number.isFinite(velocity.x) || !Number.isFinite(velocity.y)) return false;
    bun.velocity = limited(velocity, MAX_SPEED);
    this.shots++;
    this.events.push({ type: 'release', id, velocity: copy(bun.velocity) });
    return true;
  }

  snapshot() {
    return copy({ buns: this.buns, nextId: this.nextId, gateOpen: this.gateOpen, won: this.won,
      shots: this.shots, ticks: this.ticks });
  }

  restore(state) {
    const data = copy(state);
    this.buns = data.buns;
    this.nextId = data.nextId;
    this.gateOpen = data.gateOpen;
    this.won = data.won;
    this.shots = data.shots;
    this.ticks = data.ticks;
    this.events = [];
    for (const bun of this.buns) bun.previous = copy(bun.position);
  }

  step() {
    if (this.won) return;
    this.ticks++;
    for (const bun of this.buns) bun.previous = copy(bun.position);
    const dt = STEP / 4;
    const decay = Math.exp(-DRAG * dt);
    for (let substep = 0; substep < 4; substep++) {
      for (const bun of this.buns) {
        bun.velocity.x *= decay;
        bun.velocity.y *= decay;
        if (dot(bun.velocity, bun.velocity) < 0.0025) bun.velocity = vec();
        bun.position.x += bun.velocity.x * dt;
        bun.position.y += bun.velocity.y * dt;
        this._walls(bun);
        this._bumpers(bun);
        this._gate(bun);
      }
      this._contacts();
      if (this.gateOpen) {
        for (const bun of this.buns) {
          if (bun.tier === this.level.requiredTier &&
              Math.hypot(bun.position.x - this.level.exit.x, bun.position.y - this.level.exit.y) < this.level.exitRadius) {
            this.won = true;
            bun.velocity = vec();
            this.events.push({ type: 'escape', id: bun.id });
            return;
          }
        }
      }
    }
  }

  _bounce(bun, normal, restitution) {
    const speed = -dot(bun.velocity, normal);
    if (speed <= 0) return;
    bun.velocity.x += normal.x * speed * (1 + restitution);
    bun.velocity.y += normal.y * speed * (1 + restitution);
    bun.velocity = limited(bun.velocity, MAX_SPEED);
    if (speed > 0.4) this.events.push({ type: 'impact', id: bun.id, normal: copy(normal), strength: Math.min(1, speed / 8) });
  }

  _walls(bun) {
    const radius = RADII[bun.tier];
    const bounds = this.level.bounds;
    if (bun.position.x < bounds.minX + radius) {
      bun.position.x = bounds.minX + radius;
      this._bounce(bun, vec(1, 0), 0.82);
    } else if (bun.position.x > bounds.maxX - radius) {
      bun.position.x = bounds.maxX - radius;
      this._bounce(bun, vec(-1, 0), 0.82);
    }
    // Positive planar Y means forward. Normals must point into the playfield.
    if (bun.position.y < bounds.minY + radius) {
      bun.position.y = bounds.minY + radius;
      this._bounce(bun, vec(0, 1), 0.82);
    } else if (bun.position.y > bounds.maxY - radius) {
      bun.position.y = bounds.maxY - radius;
      this._bounce(bun, vec(0, -1), 0.82);
    }
  }

  _gate(bun) {
    if (this.gateOpen) return;
    const separation = bun.position.y - this.level.gateY;
    const reach = RADII[bun.tier] + this.level.gateHalfDepth;
    if (Math.abs(separation) >= reach) return;
    if (bun.tier === this.level.requiredTier) {
      this.gateOpen = true;
      this.events.push({ type: 'gate', id: bun.id });
      return;
    }
    const normal = vec(0, separation <= 0 ? -1 : 1);
    bun.position.y = this.level.gateY + normal.y * reach;
    this._bounce(bun, normal, 0.76);
  }

  _bumpers(bun) {
    for (const bumper of this.level.bumpers) {
      const offset = vec(bun.position.x - bumper.position.x, bun.position.y - bumper.position.y);
      const reach = RADII[bun.tier] + bumper.radius;
      const distance = length(offset);
      if (distance >= reach) continue;
      const normal = distance > 0.00001 ? vec(offset.x / distance, offset.y / distance) : vec(0, 1);
      bun.position = vec(bumper.position.x + normal.x * reach, bumper.position.y + normal.y * reach);
      const incoming = -dot(bun.velocity, normal);
      this._bounce(bun, normal, 1.03);
      if (incoming > 0.3) this.events.push({ type: 'jelly', strength: Math.min(1, incoming / 8) });
    }
  }

  _contacts() {
    const consumed = new Set();
    const born = [];
    for (let i = 0; i < this.buns.length; i++) {
      const a = this.buns[i];
      if (consumed.has(a.id)) continue;
      for (let j = i + 1; j < this.buns.length; j++) {
        const b = this.buns[j];
        if (consumed.has(b.id)) continue;
        const delta = vec(b.position.x - a.position.x, b.position.y - a.position.y);
        const distance = length(delta);
        const reach = RADII[a.tier] + RADII[b.tier];
        if (distance >= reach) continue;
        const ma = MASSES[a.tier], mb = MASSES[b.tier];
        if (a.tier === b.tier && a.tier < 3) {
          consumed.add(a.id);
          consumed.add(b.id);
          born.push({ tier: a.tier + 1,
            position: vec((a.position.x * ma + b.position.x * mb) / (ma + mb), (a.position.y * ma + b.position.y * mb) / (ma + mb)),
            velocity: vec((a.velocity.x * ma + b.velocity.x * mb) / (ma + mb), (a.velocity.y * ma + b.velocity.y * mb) / (ma + mb)),
            from: [a.id, b.id] });
          break;
        }
        const normal = distance > 0.00001 ? vec(delta.x / distance, delta.y / distance) : vec(1, 0);
        const penetration = reach - distance + 0.00001;
        a.position.x -= normal.x * penetration * mb / (ma + mb);
        a.position.y -= normal.y * penetration * mb / (ma + mb);
        b.position.x += normal.x * penetration * ma / (ma + mb);
        b.position.y += normal.y * penetration * ma / (ma + mb);
        const approaching = (b.velocity.x - a.velocity.x) * normal.x + (b.velocity.y - a.velocity.y) * normal.y;
        if (approaching < 0) {
          const impulse = -(1 + 0.7) * approaching / (1 / ma + 1 / mb);
          a.velocity.x -= impulse * normal.x / ma;
          a.velocity.y -= impulse * normal.y / ma;
          b.velocity.x += impulse * normal.x / mb;
          b.velocity.y += impulse * normal.y / mb;
          if (approaching < -0.4) {
            this.events.push({ type: 'impact', id: a.id, normal: vec(-normal.x, -normal.y), strength: Math.min(1, -approaching / 8) });
            this.events.push({ type: 'impact', id: b.id, normal: copy(normal), strength: Math.min(1, -approaching / 8) });
          }
        }
      }
    }
    if (consumed.size) {
      this.buns = this.buns.filter(bun => !consumed.has(bun.id));
      for (const birth of born) {
        const id = this.addBun(birth.tier, birth.position, birth.velocity);
        this.events.push({ type: 'merge', id, tier: birth.tier, from: birth.from });
      }
    }
  }
}
