extends Node3D
const Spring = preload("res://scripts/spring_profile.gd")
const Modifier = preload("res://scripts/bun_modifier.gd")
const MOTION_STEP := 1.0 / 240.0
var profile = Spring.new()
var model: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var height := 1.0
var height_velocity := 0.0
var lean := Vector2.ZERO
var lean_velocity := Vector2.ZERO
var crest := Vector2.ZERO
var crest_velocity := Vector2.ZERO
var limb_swing := Vector2.ZERO
var limb_velocity := Vector2.ZERO
var squeeze := 0.0
var squeeze_velocity := 0.0
var held := false
var pull_strength := 0.0
var pull_direction := Vector2.ZERO
var elapsed := 0.0
var next_blink := 3.2
var wobble_enabled := true
var _motion_accumulator := 0.0
var _returning := false

func setup(tier: int, seed_id: int) -> void:
    var key: String = ["", "pip", "berry", "mango"][tier]
    model = load("res://assets/" + key + ".glb").instantiate()
    add_child(model)
    model.rotation.x = -0.30
    var size_factor: float = [0.0, 0.70, 0.80, 0.91][tier]
    model.scale = Vector3.ONE * size_factor
    player = find_player(model)
    skeleton = find_skeleton(model)
    if skeleton:
        var modifier = Modifier.new()
        modifier.driver = self
        skeleton.add_child(modifier)
    next_blink += fmod(seed_id * 1.173, 2.1)
    play_clip("idle")

static func find_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node
    for child in node.get_children():
        var found := find_player(child)
        if found:
            return found
    return null

static func find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node
    for child in node.get_children():
        var found := find_skeleton(child)
        if found:
            return found
    return null

func play_clip(clip: String) -> void:
    if not player:
        return
    for name in player.get_animation_list():
        if name == clip or name.ends_with("/" + clip):
            player.get_animation(name).loop_mode = Animation.LOOP_LINEAR if clip == "idle" else Animation.LOOP_NONE
            player.play(name, 0.08)
            return

func pull(direction: Vector2, strength: float) -> void:
    held = true
    _returning = false
    pull_direction = direction.limit_length(1.0)
    pull_strength = clampf(strength, 0, 1)

func release(velocity: Vector2) -> void:
    held = false
    _returning = false
    height_velocity += 7.0 * clampf(velocity.length() / 12.0, 0.15, 1.0)
    lean_velocity += velocity.normalized() * 3.0
    squeeze_velocity += velocity.normalized().x * 1.3
    play_clip("release")

func impact(normal: Vector2, intensity: float) -> void:
    _returning = false
    intensity = clampf(intensity, 0.0, 1.0)
    normal = normal.limit_length(1.0)
    height_velocity -= 6.0 * intensity
    lean_velocity += normal * 4.0 * intensity
    squeeze_velocity -= normal.x * intensity * 2.6

func merge() -> void:
    _returning = false
    height = 0.76
    height_velocity = 4.8
    play_clip("merge")

func reset_motion(immediate := false) -> void:
    held = false
    pull_strength = 0.0
    pull_direction = Vector2.ZERO
    _returning = not immediate
    if immediate:
        _zero_motion()
    else:
        # Cancellation relaxes the held pose; it must not snap to a new silhouette.
        height_velocity *= 0.2
        lean_velocity *= 0.2
    play_clip("idle")

func _zero_motion() -> void:
    height = 1.0
    height_velocity = 0.0
    lean = Vector2.ZERO
    lean_velocity = Vector2.ZERO
    crest = Vector2.ZERO
    crest_velocity = Vector2.ZERO
    limb_swing = Vector2.ZERO
    limb_velocity = Vector2.ZERO
    squeeze = 0.0
    squeeze_velocity = 0.0
    _motion_accumulator = 0.0

func _process(delta: float) -> void:
    if not wobble_enabled:
        _zero_motion()
        return
    _motion_accumulator += clampf(delta, 0.0, 0.25)
    # Collision physics has its own clock. This clock makes the visible motion,
    # including limits and delayed parts, agree at 30, 60 and 120 render FPS.
    while _motion_accumulator + 0.000000001 >= MOTION_STEP:
        _advance_motion(MOTION_STEP)
        _motion_accumulator -= MOTION_STEP
    if player and not held and not player.is_playing():
        play_clip("idle")
    if elapsed > next_blink and not held and player and str(player.current_animation).ends_with("idle"):
        play_clip("blink")
        next_blink = elapsed + 3.0 + fmod(next_blink * 1.37, 2.0)
func _advance_motion(delta: float) -> void:
    elapsed += delta
    var target := 1.0 - 0.28 * pull_strength if held else 1.0 + 0.008 * sin(elapsed * 2.6)
    if _returning:
        target = 1.0
    var tracking: bool = held or _returning
    var h := Spring.advance(height, height_velocity, target, profile.pull_frequency if tracking else profile.frequency, 1.0 if tracking else profile.damping, delta)
    height = clampf(h.x, profile.minimum_height, profile.maximum_height)
    height_velocity = h.y
    if (height <= profile.minimum_height and height_velocity < 0) or (height >= profile.maximum_height and height_velocity > 0):
        height_velocity = -height_velocity * 0.15
    var lean_target := -pull_direction * pull_strength * 0.14 if held else Vector2.ZERO
    for axis in range(2):
        var l := Spring.advance(lean[axis], lean_velocity[axis], lean_target[axis], profile.pull_frequency if tracking else profile.lean_frequency, 1.0 if tracking else profile.lean_damping, delta)
        lean[axis] = clampf(l.x, -0.20, 0.20)
        lean_velocity[axis] = l.y
        if absf(lean[axis]) >= 0.20 and signf(lean_velocity[axis]) == signf(lean[axis]):
            lean_velocity[axis] *= -0.15
        var crest_target: float = -lean[axis] * 1.4 + ((1.0 - height) * 0.34 if axis == 1 else 0.0)
        var c := Spring.advance(crest[axis], crest_velocity[axis], crest_target, profile.crest_frequency, 0.65 if _returning else profile.crest_damping, delta)
        crest[axis] = clampf(c.x, -0.25, 0.25)
        crest_velocity[axis] = c.y
        if absf(crest[axis]) >= 0.25 and signf(crest_velocity[axis]) == signf(crest[axis]):
            crest_velocity[axis] *= -0.15
        var limb_target: float = (height - 1.0) * 0.85 + height_velocity * 0.025 if axis == 0 else lean.y * 0.8
        var limb := Spring.advance(limb_swing[axis], limb_velocity[axis], limb_target, profile.limb_frequency, 0.65 if _returning else profile.limb_damping, delta)
        limb_swing[axis] = clampf(limb.x, -0.24, 0.24)
        limb_velocity[axis] = limb.y
    var width := Spring.advance(squeeze, squeeze_velocity, -pull_direction.x * pull_strength * 0.035 if held else 0.0, 5.0, 0.6 if tracking else 0.32, delta)
    squeeze = clampf(width.x, -profile.maximum_squeeze, profile.maximum_squeeze)
    squeeze_velocity = width.y
    if absf(squeeze) >= profile.maximum_squeeze and signf(squeeze_velocity) == signf(squeeze):
        squeeze_velocity *= -0.15
    if _returning and absf(height - 1.0) < 0.001 and absf(height_velocity) < 0.01 and lean.length() < 0.001:
        _returning = false
