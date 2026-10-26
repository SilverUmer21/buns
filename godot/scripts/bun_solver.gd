extends RefCounted
## Fixed-step planar solver. Rendering, skeletons and springs cannot change it.
const Level = preload("res://scripts/level_definition.gd")
const STEP := 1.0 / 120.0
const RADII := [0.0, 0.55, 0.65, 0.77]
const MASSES := [0.0, 1.0, 2.0, 4.0]
const DRAG := 1.45
const MAX_SPEED := 12.0
var level: Dictionary
var buns: Array[Dictionary] = []
var events: Array[Dictionary] = []
var next_id := 1
var gate_open := false
var won := false
var shots := 0
var ticks := 0

func _init() -> void:
    reset()

func reset() -> void:
    level = Level.big_escape()
    buns.clear()
    next_id = 1
    gate_open = false
    won = false
    shots = 0
    ticks = 0
    events.clear()
    for spawn in level.spawns:
        add_bun(spawn.tier, spawn.position)

func add_bun(tier: int, pos: Vector2, velocity := Vector2.ZERO) -> int:
    var id := next_id
    next_id += 1
    buns.append({"id": id, "tier": tier, "position": pos, "previous": pos, "velocity": velocity})
    return id

func find_bun(id: int) -> Dictionary:
    for bun in buns:
        if bun.id == id:
            return bun
    return {}

func is_moving() -> bool:
    for bun in buns:
        if bun.velocity.length_squared() > 0.003:
            return true
    return false

func shoot(id: int, velocity: Vector2) -> bool:
    var bun := find_bun(id)
    if bun.is_empty() or won or is_moving():
        return false
    bun.velocity = velocity.limit_length(MAX_SPEED)
    shots += 1
    events.append({"type": "release", "id": id, "velocity": bun.velocity})
    return true

func snapshot() -> Dictionary:
    return {"buns": buns.duplicate(true), "next_id": next_id, "gate_open": gate_open,
        "won": won, "shots": shots, "ticks": ticks}

func restore(state: Dictionary) -> void:
    buns.assign(state.buns.duplicate(true))
    next_id = state.next_id
    gate_open = state.gate_open
    won = state.won
    shots = state.shots
    ticks = state.ticks
    events.clear()
    for bun in buns:
        bun.previous = bun.position

func step() -> void:
    if won:
        return
    ticks += 1
    for bun in buns:
        bun.previous = bun.position
    # Four fixed collision substeps prevent fast shots crossing thin barriers.
    var dt := STEP / 4.0
    for substep in range(4):
        for bun in buns:
            bun.velocity *= exp(-DRAG * dt)
            if bun.velocity.length_squared() < 0.0025:
                bun.velocity = Vector2.ZERO
            bun.position += bun.velocity * dt
            _walls(bun)
            _bumpers(bun)
            _gate(bun)
        _contacts()
        if gate_open:
            for bun in buns:
                if bun.tier == level.required_tier and bun.position.distance_to(level.exit) < level.exit_radius:
                    won = true
                    bun.velocity = Vector2.ZERO
                    events.append({"type": "escape", "id": bun.id})
                    return

func _bounce(bun: Dictionary, normal: Vector2, restitution: float) -> void:
    var speed: float = -bun.velocity.dot(normal)
    if speed <= 0:
        return
    bun.velocity += normal * speed * (1.0 + restitution)
    bun.velocity = bun.velocity.limit_length(MAX_SPEED)
    if speed > 0.4:
        events.append({"type": "impact", "id": bun.id, "normal": normal, "strength": minf(1.0, speed / 8.0)})

func _walls(bun: Dictionary) -> void:
    var radius: float = RADII[bun.tier]
    var lo: Vector2 = level.bounds.position + Vector2.ONE * radius
    var hi: Vector2 = level.bounds.end - Vector2.ONE * radius
    if bun.position.x < lo.x:
        bun.position.x = lo.x
        _bounce(bun, Vector2.RIGHT, 0.82)
    elif bun.position.x > hi.x:
        bun.position.x = hi.x
        _bounce(bun, Vector2.LEFT, 0.82)
    if bun.position.y < lo.y:
        bun.position.y = lo.y
        _bounce(bun, Vector2.UP, 0.82)
    elif bun.position.y > hi.y:
        bun.position.y = hi.y
        _bounce(bun, Vector2.DOWN, 0.82)

func _gate(bun: Dictionary) -> void:
    if gate_open:
        return
    var separation: float = bun.position.y - level.gate_y
    var reach: float = RADII[bun.tier] + level.gate_half_depth
    if absf(separation) >= reach:
        return
    if bun.tier == level.required_tier:
        gate_open = true
        events.append({"type": "gate", "id": bun.id})
        return
    var normal := Vector2(0, -1 if separation <= 0 else 1)
    bun.position.y = level.gate_y + normal.y * reach
    _bounce(bun, normal, 0.76)

func _bumpers(bun: Dictionary) -> void:
    for bumper in level.bumpers:
        var offset: Vector2 = bun.position - bumper.position
        var reach: float = RADII[bun.tier] + bumper.radius
        var distance := offset.length()
        if distance >= reach:
            continue
        var normal := offset / distance if distance > 0.00001 else Vector2.DOWN
        bun.position = bumper.position + normal * reach
        var incoming: float = -bun.velocity.dot(normal)
        _bounce(bun, normal, 1.03)
        if incoming > 0.3:
            events.append({"type": "jelly", "strength": minf(1.0, incoming / 8.0)})

func _contacts() -> void:
    # Stable IDs, delayed removals: a bun can participate in only one merge per substep.
    var consumed: Dictionary = {}
    var born: Array[Dictionary] = []
    for i in range(buns.size()):
        var a := buns[i]
        if consumed.has(a.id):
            continue
        for j in range(i + 1, buns.size()):
            var b := buns[j]
            if consumed.has(b.id):
                continue
            var delta: Vector2 = b.position - a.position
            var distance := delta.length()
            var reach: float = RADII[a.tier] + RADII[b.tier]
            if distance >= reach:
                continue
            var ma: float = MASSES[a.tier]
            var mb: float = MASSES[b.tier]
            if a.tier == b.tier and a.tier < 3:
                consumed[a.id] = true
                consumed[b.id] = true
                var center: Vector2 = (a.position * ma + b.position * mb) / (ma + mb)
                var velocity: Vector2 = (a.velocity * ma + b.velocity * mb) / (ma + mb)
                born.append({"tier": a.tier + 1, "position": center, "velocity": velocity, "from": [a.id, b.id]})
                break
            var normal := delta / distance if distance > 0.00001 else Vector2.RIGHT
            var penetration: float = reach - distance + 0.00001
            a.position -= normal * penetration * mb / (ma + mb)
            b.position += normal * penetration * ma / (ma + mb)
            var approaching: float = (b.velocity - a.velocity).dot(normal)
            if approaching < 0:
                var impulse: float = -(1.0 + 0.7) * approaching / (1.0 / ma + 1.0 / mb)
                a.velocity -= impulse * normal / ma
                b.velocity += impulse * normal / mb
                if approaching < -0.4:
                    events.append({"type": "impact", "id": a.id, "normal": -normal, "strength": minf(1., -approaching / 8.)})
                    events.append({"type": "impact", "id": b.id, "normal": normal, "strength": minf(1., -approaching / 8.)})
    if not consumed.is_empty():
        var survivors: Array[Dictionary] = []
        for bun in buns:
            if not consumed.has(bun.id):
                survivors.append(bun)
        buns = survivors
        for birth in born:
            var id := add_bun(birth.tier, birth.position, birth.velocity)
            events.append({"type": "merge", "id": id, "tier": birth.tier, "from": birth.from})
