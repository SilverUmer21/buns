extends Control
const Solver = preload("res://scripts/bun_solver.gd")
const Motion = preload("res://scripts/bun_motion_driver.gd")
const Overlay = preload("res://scripts/aim_overlay.gd")
const INK := Color("235b53")
const CREAM := Color("fff8e7")
const GOLD := Color("ffd057")
var solver = Solver.new()
var world_view: SubViewport
var board_texture: TextureRect
var camera: Camera3D
var stage: Node3D
var bun_nodes: Dictionary = {}
var gate: Node3D
var wafer: Node3D
var jelly: Node3D
var overlay: Control
var title_label: Label
var eyebrow: Label
var instruction: Label
var stats: Label
var recipe: Label
var left_note: Label
var undo_button: Button
var retry_button: Button
var pause_button: Button
var mute_button: Button
var hint_button: Button
var board_rect := Rect2()
var selected_id := -1
var selected_origin := Vector2.ZERO
var launch_velocity := Vector2.ZERO
var pull_amount := 0.0
var pointer_id := -2
var prediction: Array[Vector2] = []
var undo_history: Array[Dictionary] = []
var accumulator := 0.0
var paused := false
var muted := false
var sparkles: Array[Dictionary] = []
var elapsed := 0.0
var gate_break_age := 0.0
var jelly_bounce := 0.0
var audio: AudioStreamPlayer
var last_sound := -1.0
var demo_active := false
var demo_index := 0
var demo_wait := 0.0
var demo_moves: Array = []
var best_shots := 0

func _ready() -> void:
    _make_theme()
    _build_ui()
    _build_world()
    _load_progress()
    _sync_buns()
    resized.connect(_layout)
    _layout()
    audio = AudioStreamPlayer.new()
    add_child(audio)
    if FileAccess.file_exists("res://data/solution.json"):
        demo_moves = JSON.parse_string(FileAccess.get_file_as_string("res://data/solution.json"))
    _update_labels()

func _make_theme() -> void:
    var t := Theme.new()
    t.default_font_size = 17
    if ResourceLoader.exists("res://fonts/body.ttf"):
        t.default_font = load("res://fonts/body.ttf")
    t.set_color("font_color", "Label", INK)
    for state in ["normal", "hover", "pressed", "disabled", "focus"]:
        var box := StyleBoxFlat.new()
        box.bg_color = CREAM if state == "normal" else Color("ffe5a1")
        if state == "disabled":
            box.bg_color = Color("e3eee0")
        if state == "focus":
            box.bg_color = Color.TRANSPARENT
            box.set_border_width_all(2)
            box.border_color = INK
        box.set_corner_radius_all(18)
        box.content_margin_left = 16
        box.content_margin_right = 16
        box.content_margin_top = 12
        box.content_margin_bottom = 12
        t.set_stylebox(state, "Button", box)
    for key in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
        t.set_color(key, "Button", INK if key != "font_disabled_color" else Color("8ca69a"))
    theme = t

func _label(text: String, font_size: int, alignment := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
    var node := Label.new()
    node.text = text
    node.horizontal_alignment = alignment
    node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    node.add_theme_font_size_override("font_size", font_size)
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(node)
    return node

func _button(text: String, callback: Callable) -> Button:
    var node := Button.new()
    node.text = text
    node.custom_minimum_size = Vector2(52, 48)
    node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    node.pressed.connect(callback)
    add_child(node)
    return node

func _build_ui() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    eyebrow = _label("SUNSHINE KITCHEN", 12)
    title_label = _label("Bunbreak", 38)
    if ResourceLoader.exists("res://fonts/title.ttf"):
        title_label.add_theme_font_override("font", load("res://fonts/title.ttf"))
    instruction = _label("Pull back a bun. Let the happy happen.", 16)
    stats = _label("", 15)
    recipe = _label("THE HAPPY RECIPE\n\nPip + Pip  =  Berry\nBerry + Berry  =  Mango\n\nMake a Mango.\nBreak the wafer gate.\nHop onto the escape plate.", 17)
    left_note = _label("A little wobble.\nA big adventure.\n\nSame bun?\nBetter together.\n\nUnlimited tries.\nTake your time.", 20)
    undo_button = _button("Undo", _undo)
    retry_button = _button("Retry", _retry)
    pause_button = _button("Ⅱ", _toggle_pause)
    mute_button = _button("♪", _toggle_mute)
    hint_button = _button("Show me", _show_me)
    board_texture = TextureRect.new()
    board_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
    board_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    board_texture.stretch_mode = TextureRect.STRETCH_SCALE
    add_child(board_texture)
    # Keep the overlay above the board while all buttons stay outside it.
    overlay = Overlay.new()
    overlay.game = self
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(overlay)

func _layout() -> void:
    if not is_instance_valid(board_texture):
        return
    var desktop := size.x >= 1020
    var board_height := minf(size.y - 236, (size.x - 24) / 0.70)
    var board_width := board_height * 0.70
    board_rect = Rect2((size.x - board_width) / 2.0, 120, board_width, board_height)
    if desktop:
        board_rect.position.y = 98
        board_rect.size = Vector2((size.y - 194) * 0.70, size.y - 194)
        board_rect.position.x = (size.x - board_rect.size.x) / 2
    board_texture.position = board_rect.position
    board_texture.size = board_rect.size
    if world_view:
        world_view.size = Vector2i(board_rect.size.round())
    title_label.position = Vector2(0, 8)
    title_label.size = Vector2(size.x, 52)
    eyebrow.position = Vector2(0, 58)
    eyebrow.size = Vector2(size.x, 20)
    instruction.position = Vector2(12, 84)
    instruction.size = Vector2(size.x - 24, 28)
    var bottom: float = board_rect.end.y + 6
    stats.position = Vector2(0, bottom)
    stats.size = Vector2(size.x, 24)
    var controls_width := minf(size.x - 24, 470)
    var start := (size.x - controls_width) / 2
    var button_y := bottom + 37
    undo_button.position = Vector2(start, button_y)
    undo_button.size = Vector2(86, 50)
    hint_button.position = Vector2(size.x / 2 - 63, button_y)
    hint_button.size = Vector2(126, 50)
    retry_button.position = Vector2(start + controls_width - 86, button_y)
    retry_button.size = Vector2(86, 50)
    pause_button.position = Vector2(size.x - 66, 24)
    pause_button.size = Vector2(50, 48)
    mute_button.position = Vector2(16, 24)
    mute_button.size = Vector2(50, 48)
    left_note.visible = desktop
    recipe.visible = desktop
    if desktop:
        left_note.position = Vector2(25, size.y * 0.30)
        left_note.size = Vector2(board_rect.position.x - 35, 300)
        recipe.position = Vector2(board_rect.end.x + 15, size.y * 0.27)
        recipe.size = Vector2(size.x - board_rect.end.x - 30, 330)
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("c6f2df"))
    draw_circle(Vector2(size.x * 0.86, size.y * 0.18), 90, Color("e9f6bb"), true, -1, true)
    draw_circle(Vector2(size.x * 0.10, size.y * 1.36), size.y * 0.46, Color("b3e8ce"), true, -1, true)
    draw_circle(Vector2(size.x * 0.92, size.y * 1.42), size.y * 0.55, Color("addfc6"), true, -1, true)

func _asset(key: String, pos := Vector3.ZERO) -> Node3D:
    var node: Node3D = load("res://assets/" + key + ".glb").instantiate()
    stage.add_child(node)
    node.position = pos
    return node

func _build_world() -> void:
    world_view = SubViewport.new()
    world_view.own_world_3d = true
    world_view.transparent_bg = true
    world_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    world_view.msaa_3d = Viewport.MSAA_2X
    add_child(world_view)
    board_texture.texture = world_view.get_texture()
    stage = Node3D.new()
    world_view.add_child(stage)
    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("c6f2df")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("fff3da")
    env.ambient_light_energy = 0.62
    env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
    environment.environment = env
    stage.add_child(environment)
    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-58, -27, 0)
    key.light_color = Color("fff5e0")
    key.light_energy = 1.2
    key.shadow_enabled = true
    key.directional_shadow_max_distance = 30.0
    key.shadow_bias = 0.025
    stage.add_child(key)
    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-30, 150, 0)
    fill.light_energy = 0.24
    fill.light_color = Color("e1f6ff")
    stage.add_child(fill)
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 12.5
    stage.add_child(camera)
    camera.position = Vector3(0, 16.4, 10.2)
    camera.look_at(Vector3(0, 0.25, 0))
    camera.current = true
    _asset("tray")
    gate = _asset("wafer_gate", Vector3(0, 0.215, -solver.level.gate_y))
    wafer = gate.find_child("WaferBar", true, false)
    _asset("exit_plate", Vector3(0, 0.215, -solver.level.exit.y)).scale = Vector3.ONE * 0.70
    jelly = _asset("jelly_bumper", Vector3(0, 0.215, -solver.level.bumpers[0].position.y))

func _sync_buns() -> void:
    var present: Dictionary = {}
    for bun in solver.buns:
        present[bun.id] = true
        if not bun_nodes.has(bun.id):
            var node = Motion.new()
            stage.add_child(node)
            node.setup(bun.tier, bun.id)
            bun_nodes[bun.id] = node
            node.position = Vector3(bun.position.x, 0.215, -bun.position.y)
    for id in bun_nodes.keys():
        if not present.has(id):
            bun_nodes[id].queue_free()
            bun_nodes.erase(id)

func _process(delta: float) -> void:
    if not world_view:
        return
    if paused:
        return
    elapsed += delta
    accumulator += minf(delta, 0.20)
    while accumulator >= Solver.STEP:
        solver.step()
        accumulator -= Solver.STEP
    _sync_buns()
    _consume_events()
    for bun in solver.buns:
        var smooth: Vector2 = bun.previous.lerp(bun.position, accumulator / Solver.STEP)
        bun_nodes[bun.id].position = Vector3(smooth.x, 0.215, -smooth.y)
    if solver.gate_open and is_instance_valid(wafer):
        gate_break_age += delta
        wafer.position.y = -minf(1.1, gate_break_age * 3.5)
        wafer.rotation.z = sin(gate_break_age * 14) * 0.12
        wafer.visible = gate_break_age < 0.34
    if jelly_bounce > 0:
        jelly_bounce = maxf(0, jelly_bounce - delta * 2.5)
        var h := 1.0 - sin(jelly_bounce * PI * 4) * jelly_bounce * 0.14
        jelly.scale = Vector3(1 / sqrt(h), h, 1 / sqrt(h))
    for sparkle in sparkles:
        sparkle.age += delta
        sparkle.offset += sparkle.velocity * delta
        sparkle.velocity.y += 90 * delta
    sparkles = sparkles.filter(func(s): return s.age < 0.6)
    _advance_demo(delta)
    _update_labels()
    overlay.queue_redraw()

func _consume_events() -> void:
    for event in solver.events:
        match event.type:
            "release":
                if bun_nodes.has(event.id):
                    bun_nodes[event.id].release(event.velocity)
                _sound(460, 0.12)
            "impact":
                if bun_nodes.has(event.id):
                    bun_nodes[event.id].impact(event.normal, event.strength)
                _sound(220, 0.09)
            "merge":
                if bun_nodes.has(event.id):
                    bun_nodes[event.id].merge()
                    _sparkle(solver.find_bun(event.id).position)
                _sound(740, 0.22)
            "jelly":
                jelly_bounce = 1.0
                _sound(320, 0.15)
            "gate":
                gate_break_age = 0
                _sparkle(Vector2(0, solver.level.gate_y))
                _sound(980, 0.22)
            "escape":
                if bun_nodes.has(event.id):
                    bun_nodes[event.id].play_clip("escape")
                _sparkle(solver.level.exit)
                _sound(1040, 0.4)
                _save_progress()
    solver.events.clear()

func _sparkle(pos: Vector2) -> void:
    for i in range(8):
        var angle := i * TAU / 8
        sparkles.append({"position": pos, "offset": Vector2.ZERO, "velocity": Vector2(cos(angle), sin(angle)) * 65, "age": 0.0})

func _update_labels() -> void:
    undo_button.disabled = undo_history.is_empty() or paused
    hint_button.disabled = paused or demo_moves.is_empty()
    if solver.won:
        instruction.text = "Sweet freedom! Your Mango made it."
        stats.text = "%d shots · Happy little escape!" % solver.shots
    elif paused:
        instruction.text = "A little breather. Tap play when you’re ready."
    elif demo_active:
        instruction.text = "Watch the buns: pull, merge, wobble, escape."
        stats.text = "The big escape · %d shots" % solver.shots
    else:
        instruction.text = "Pull back a bun. Let the happy happen."
        if selected_id >= 0:
            instruction.text = "Hold… %d%% · release to flick!" % roundi(pull_amount * 100)
        elif solver.is_moving():
            instruction.text = "Boing! Let the buns settle."
        stats.text = "The big escape · %d shot%s" % [solver.shots, "" if solver.shots == 1 else "s"]

func screen_point(point: Vector2) -> Vector2:
    return board_rect.position + camera.unproject_position(Vector3(point.x, 0.40, -point.y))

func _world_point(point: Vector2) -> Vector2:
    var local := point - board_rect.position
    var origin := camera.project_ray_origin(local)
    var direction := camera.project_ray_normal(local)
    var hit = Plane(Vector3.UP, 0.215).intersects_ray(origin, direction)
    if hit == null:
        return Vector2.ZERO
    return Vector2(hit.x, -hit.z)

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        _toggle_pause()
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _begin_pull(event.position, -1)
        elif pointer_id == -1:
            _end_pull(event.position, false)
    elif event is InputEventMouseMotion and pointer_id == -1:
        _drag_pull(event.position)
    elif event is InputEventScreenTouch:
        if event.pressed:
            _begin_pull(event.position, event.index)
        elif pointer_id == event.index:
            _end_pull(event.position, event.canceled)
    elif event is InputEventScreenDrag and pointer_id == event.index:
        _drag_pull(event.position)

func _begin_pull(point: Vector2, id: int) -> void:
    if paused or solver.won or solver.is_moving() or selected_id >= 0 or not board_rect.has_point(point):
        return
    if demo_active:
        for node in bun_nodes.values():
            if node.held:
                node.reset_motion()
    demo_active = false
    var pos := _world_point(point)
    var nearest := 100.0
    for bun in solver.buns:
        var distance := pos.distance_to(bun.position)
        if distance < Solver.RADII[bun.tier] + 0.28 and distance < nearest:
            selected_id = bun.id
            nearest = distance
    if selected_id < 0:
        return
    pointer_id = id
    selected_origin = pos
    launch_velocity = Vector2.ZERO
    pull_amount = 0.0
    bun_nodes[selected_id].pull(Vector2.ZERO, 0)

func _drag_pull(point: Vector2) -> void:
    if selected_id < 0:
        return
    var drag := selected_origin - _world_point(point)
    pull_amount = clampf(drag.length() / 2.2, 0.0, 1.0)
    launch_velocity = drag.normalized() * Solver.MAX_SPEED * pull_amount
    bun_nodes[selected_id].pull(drag.normalized(), pull_amount)
    prediction.clear()
    if pull_amount > 0.04:
        var preview = Solver.new()
        preview.restore(solver.snapshot())
        preview.shoot(selected_id, launch_velocity)
        for tick in range(90):
            preview.step()
            var bun: Dictionary = preview.find_bun(selected_id)
            if bun.is_empty():
                break
            if tick % 5 == 0:
                prediction.append(bun.position)
    overlay.queue_redraw()

func _end_pull(point: Vector2, canceled: bool) -> void:
    if selected_id < 0:
        return
    if not canceled and board_rect.has_point(point) and pull_amount >= 0.045:
        undo_history.append(solver.snapshot())
        solver.shoot(selected_id, launch_velocity)
    else:
        bun_nodes[selected_id].reset_motion()
    selected_id = -1
    pointer_id = -2
    prediction.clear()
    pull_amount = 0.0
    overlay.queue_redraw()

func _cancel_pull() -> void:
    _end_pull(Vector2.ZERO, true)

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _cancel_pull()
        if world_view and not paused:
            _toggle_pause()

func _toggle_pause() -> void:
    _cancel_pull()
    paused = not paused
    stage.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
    pause_button.text = "▶" if paused else "Ⅱ"
    audio.stream_paused = paused
    _update_labels()

func _toggle_mute() -> void:
    muted = not muted
    mute_button.text = "×♪" if muted else "♪"
    if muted:
        audio.stop()

func _clear_visuals() -> void:
    for node in bun_nodes.values():
        node.queue_free()
    bun_nodes.clear()
    sparkles.clear()
    gate_break_age = 0
    wafer.visible = not solver.gate_open
    wafer.position = Vector3.ZERO
    wafer.rotation = Vector3.ZERO
    jelly.scale = Vector3.ONE
    jelly_bounce = 0
    accumulator = 0
    _sync_buns()

func _retry() -> void:
    _cancel_pull()
    if paused:
        _toggle_pause()
    demo_active = false
    solver.reset()
    undo_history.clear()
    _clear_visuals()
    _update_labels()

func _undo() -> void:
    if undo_history.is_empty() or paused:
        return
    _cancel_pull()
    demo_active = false
    solver.restore(undo_history.pop_back())
    _clear_visuals()
    _update_labels()

func _show_me() -> void:
    _retry()
    demo_active = true
    demo_index = 0
    demo_wait = 0.7

func _advance_demo(delta: float) -> void:
    if not demo_active or solver.won:
        return
    if solver.is_moving():
        demo_wait = 0.75
        return
    demo_wait -= delta
    if demo_wait > 0:
        if demo_index < demo_moves.size():
            var next: Dictionary = demo_moves[demo_index]
            if bun_nodes.has(int(next.id)):
                var velocity := Vector2(next.vx, next.vy)
                bun_nodes[int(next.id)].pull(velocity.normalized(), velocity.length() / 12.0 * smoothstep(0.75, 0.15, demo_wait))
        return
    if demo_index >= demo_moves.size():
        demo_active = false
        return
    var move: Dictionary = demo_moves[demo_index]
    undo_history.append(solver.snapshot())
    solver.shoot(move.id, Vector2(move.vx, move.vy))
    demo_index += 1
    demo_wait = 0.55

func _sound(frequency: float, duration: float) -> void:
    if muted or elapsed - last_sound < 0.06 or not audio:
        return
    last_sound = elapsed
    var sample := AudioStreamWAV.new()
    sample.format = AudioStreamWAV.FORMAT_16_BITS
    sample.mix_rate = 22050
    var data := PackedByteArray()
    data.resize(int(duration * 22050) * 2)
    for i in range(data.size() / 2):
        var t := float(i) / 22050.0
        var envelope := minf(1.0, t / 0.006) * exp(-t * 5.0 / duration)
        var tone := sin(TAU * frequency * (t + 0.10 * t * t)) + 0.20 * sin(TAU * frequency * 2 * t)
        data.encode_s16(i * 2, int(tone * envelope * 4600))
    sample.data = data
    audio.stream = sample
    audio.play()

func _load_progress() -> void:
    var config := ConfigFile.new()
    if config.load("user://progress.cfg") == OK:
        best_shots = config.get_value("progress", "best_shots", 0)

func _save_progress() -> void:
    if demo_active:
        return
    if best_shots == 0 or solver.shots < best_shots:
        best_shots = solver.shots
        var config := ConfigFile.new()
        config.set_value("progress", "best_shots", best_shots)
        config.save("user://progress.cfg")
