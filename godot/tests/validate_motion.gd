extends SceneTree
## Tests actual runtime drivers and GLB skeletons, not only the spring helper.
const Motion = preload("res://scripts/bun_motion_driver.gd")
const Solver = preload("res://scripts/bun_solver.gd")
var checks: Array[String] = []
var failures: Array[String] = []
var metrics: Dictionary = {}

func check(condition: bool, text: String) -> void:
    (checks if condition else failures).append(text)
    if not condition:
        push_error(text)

func driver(tier := 1):
    var node = Motion.new()
    root.add_child(node)
    node.setup(tier, 42)
    node.set_process(false)
    node.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    return node

func advance(node, delta: float) -> void:
    node._process(delta)
    node.player.advance(delta)

func state(node) -> Array:
    return [node.height, node.height_velocity, node.lean, node.lean_velocity,
        node.crest, node.crest_velocity, node.limb_swing, node.limb_velocity,
        node.squeeze, node.squeeze_velocity]

func timeline(fps: int) -> Array:
    var node = driver()
    var samples: Array = []
    for frame in range(fps * 3):
        if frame == 0:
            node.pull(Vector2(0.6, 0.8), 1.0)
        elif frame == fps / 2:
            node.release(Vector2(7.2, 9.6))
        elif frame == fps:
            node.impact(Vector2.LEFT, 0.85)
        elif frame == fps * 3 / 2:
            node.pull(Vector2.RIGHT, 0.7)
        elif frame == fps * 2:
            node.reset_motion()
        advance(node, 1.0 / fps)
        if (frame + 1) % (fps / 10) == 0:
            samples.append(state(node))
    node.queue_free()
    return samples

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var baseline := timeline(30)
    for fps in [60, 120]:
        var result := timeline(fps)
        check(result == baseline, "Actual driver states match at 30 and %d FPS throughout events" % fps)
    var node = driver()
    node.pull(Vector2(100, 0), 5)
    advance(node, 1.0 / 60)
    check(node.height < 1 and node.height > 0.90, "Pull begins smoothly without snapping to full squash")
    for frame in range(120):
        advance(node, 1.0 / 60)
    check(absf(node.height - 0.72) < 0.0001 and node.lean.length() <= 0.201, "Long hold reaches stable clamped squash despite oversized input")
    var held_height: float = node.height
    node.reset_motion()
    check(node.height == held_height and not node.held, "Touch cancellation preserves pose at the instant of cancellation")
    for frame in range(90):
        advance(node, 1.0 / 60)
    check(absf(node.height - 1.0) < 0.01 and node.lean.length() < 0.001, "Canceled pull relaxes smoothly to rest")
    node.pull(Vector2(0.6, 0.8), 1.0)
    for frame in range(60):
        advance(node, 1.0 / 60)
    node.release(Vector2(7.2, 9.6))
    var peak := 0.0
    var low := 10.0
    var zero_crossings := 0
    var last: float = node.height - 1.0
    var crest_peak := 0.0
    var limb_peak := 0.0
    var volume_error := 0.0
    for frame in range(120):
        advance(node, 1.0 / 120)
        peak = maxf(peak, node.height)
        low = minf(low, node.height)
        var current: float = node.height - 1.0
        if current * last < 0:
            zero_crossings += 1
        last = current
        crest_peak = maxf(crest_peak, node.crest.length())
        limb_peak = maxf(limb_peak, node.limb_swing.length())
        var modifier = node.skeleton.get_child(node.skeleton.get_child_count() - 1)
        modifier._process_modification()
        var body: int = node.skeleton.find_bone("Body")
        var scale: Vector3 = node.skeleton.get_bone_pose_scale(body)
        volume_error = maxf(volume_error, absf(scale.x * scale.y * scale.z - 1.0))
    metrics = {"release_peak_height": peak, "release_low_height": low, "release_crossings": zero_crossings,
        "crest_peak_radians": crest_peak, "limb_peak_radians": limb_peak,
        "largest_volume_error": volume_error}
    check(peak > 1.07 and low >= 0.72 and peak <= 1.20 and zero_crossings >= 3, "Release produces visible, bounded diminishing wobble")
    check(crest_peak > 0.04 and limb_peak > 0.03, "Crest and limbs have visible delayed follow-through")
    check(volume_error < 0.00001, "Actual SkeletonModifier3D bulk scale preserves volume during directional jiggle")
    node.impact(Vector2.RIGHT, 1.0)
    for frame in range(120):
        advance(node, 1.0 / 60)
    check(absf(node.height - 1) < 0.01 and node.lean.length() < 0.001 and absf(node.squeeze) < 0.001, "Collision wobble settles without permanent drift")
    for event in range(40):
        node.impact(Vector2(1, 1), 4.0)
        node.release(Vector2(100, 0))
        advance(node, 1.0 / 60)
        var valid: bool = is_finite(node.height) and node.height >= 0.72 and node.height <= 1.2 and node.lean.length() <= 0.284 and absf(node.squeeze) <= node.profile.maximum_squeeze
        check(valid, "Repeated event burst remains bounded %d" % event)
    node.wobble_enabled = false
    advance(node, 1.0 / 30)
    check(node.height == 1 and node.height_velocity == 0 and node.lean == Vector2.ZERO and node.limb_swing == Vector2.ZERO, "Disabled wobble clears stored impulses")
    node.wobble_enabled = true
    advance(node, 1.0 / 60)
    check(absf(node.height - 1) < 0.001 and node.lean.length() < 0.001, "Re-enabling wobble has no stale kick")
    # Visual motion is isolated from solver snapshots, even during event bursts.
    var plain = Solver.new()
    var jiggly = Solver.new()
    plain.shoot(1, Vector2(0, 5.4))
    jiggly.shoot(1, Vector2(0, 5.4))
    for tick in range(600):
        plain.step()
        jiggly.step()
        node.impact(Vector2.RIGHT, 0.25)
        advance(node, Solver.STEP)
        plain.events.clear()
        jiggly.events.clear()
    check(plain.snapshot() == jiggly.snapshot(), "Wobble event bursts do not change fixed collision/merge outcomes")
    node.queue_free()
    for tier in [1, 2, 3]:
        var character = driver(tier)
        character.pull(Vector2.RIGHT, 1.0)
        for frame in range(30):
            advance(character, 1.0 / 60)
        var modifier = character.skeleton.get_child(character.skeleton.get_child_count() - 1)
        modifier._process_modification()
        var body_index: int = character.skeleton.find_bone("Body")
        var body_pose: Transform3D = character.skeleton.get_bone_global_pose(body_index)
        var eye_index: int = character.skeleton.find_bone("Eye.L")
        check(character.skeleton.get_bone_parent(eye_index) == body_index and body_pose.is_finite(), "Tier %d keeps facial bones attached through maximum squash" % tier)
        character.queue_free()
    await process_frame
    await process_frame
    var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures,
        "metrics": metrics, "motion_step_hz": 240, "render_fps": [30, 60, 120],
        "scope": "Headless actual driver and skeleton checks; visual capture and physical Android tuning remain separate."}
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../reports"))
    var file := FileAccess.open("res://../reports/motion-validation.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(report, "  "))
    print("MOTION VALIDATION ", "PASS" if failures.is_empty() else "FAIL", ": ", checks.size(), " checks; ", failures)
    print("MOTION METRICS ", metrics)
    quit(0 if failures.is_empty() else 1)
