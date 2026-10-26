extends Node3D
const Spring = preload("res://scripts/spring_profile.gd")
const Modifier = preload("res://scripts/bun_modifier.gd")
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
var held := false
var pull_strength := 0.0
var pull_direction := Vector2.ZERO
var elapsed := 0.0
var next_blink := 3.2
var wobble_enabled := true

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
    pull_direction = direction
    pull_strength = clampf(strength, 0, 1)

func release(velocity: Vector2) -> void:
    held = false
    height_velocity += 6.5 * clampf(velocity.length() / 12.0, 0.15, 1.0)
    lean_velocity += velocity.normalized() * 3.0
    play_clip("release")

func impact(normal: Vector2, intensity: float) -> void:
    height_velocity -= 6.0 * intensity
    lean_velocity += normal * 4.0 * intensity

func merge() -> void:
    height = 0.76
    height_velocity = 4.8
    play_clip("merge")

func reset_motion() -> void:
    held = false
    height = 1.0
    height_velocity = 0.0
    lean = Vector2.ZERO
    lean_velocity = Vector2.ZERO
    crest = Vector2.ZERO
    crest_velocity = Vector2.ZERO
    play_clip("idle")

func _process(delta: float) -> void:
    if not wobble_enabled:
        height = 1.0
        lean = Vector2.ZERO
        crest = Vector2.ZERO
        return
    elapsed += delta
    if player and not held and not player.is_playing():
        play_clip("idle")
    if elapsed > next_blink and not held and player and str(player.current_animation).ends_with("idle"):
        play_clip("blink")
        next_blink = elapsed + 3.0 + fmod(next_blink * 1.37, 2.0)
    var target := 1.0 - 0.28 * pull_strength if held else 1.0 + 0.008 * sin(elapsed * 2.6)
    var h := Spring.advance(height, height_velocity, target, profile.pull_frequency if held else profile.frequency, 1.0 if held else profile.damping, delta)
    height = clampf(h.x, profile.minimum_height, profile.maximum_height)
    height_velocity = h.y
    if height != h.x:
        height_velocity *= 0.35
    var lean_target := -pull_direction * pull_strength * 0.14 if held else Vector2.ZERO
    for axis in range(2):
        var l := Spring.advance(lean[axis], lean_velocity[axis], lean_target[axis], 4.5, 0.42, delta)
        lean[axis] = clampf(l.x, -0.20, 0.20)
        lean_velocity[axis] = l.y
        var c := Spring.advance(crest[axis], crest_velocity[axis], -lean[axis] * 1.4, 5.6, 0.30, delta)
        crest[axis] = clampf(c.x, -0.25, 0.25)
        crest_velocity[axis] = c.y
