extends Control
const Solver = preload("res://scripts/bun_solver.gd")
const Motion = preload("res://scripts/bun_motion_driver.gd")
const Overlay = preload("res://scripts/aim_overlay.gd")
const INK := Color("235b53")
const CREAM := Color("fff8e7")
const GOLD := Color("ffd057")
enum Flow { TITLE, PLAY, PAUSE, RESULT, TRAIL }
const MASTERY_SHOTS := 4 # Verified solution, not a claim of an optimal par.
const GENTLE_SHOTS := 6 # Provisional generous target: verified route plus two tries.

class WaferStars extends Control:
    var earned := 0
    var age := 0.0
    var reduced := false
    func _process(delta: float) -> void:
        if is_visible_in_tree():
            age += delta
            queue_redraw()
    func _draw() -> void:
        for index in range(3):
            var progress := 1.0 if reduced else clampf((age - index * 0.12) / 0.28, 0.0, 1.0)
            var radius := 25.0 * (1.0 + sin(progress * PI) * 0.12) * progress
            var center := Vector2(size.x * (index + 1) / 4.0, size.y / 2.0)
            var points := PackedVector2Array()
            for corner in range(10):
                var angle := -PI / 2.0 + corner * PI / 5.0
                points.append(center + Vector2(cos(angle), sin(angle)) * radius * (1.0 if corner % 2 == 0 else 0.55))
            draw_colored_polygon(points, Color("ffd057") if index < earned else Color("dedfc7"))
            points.append(points[0])
            draw_polyline(points, Color("d69a38") if index < earned else Color("bac5b2"), 2.0, true)

var flow := Flow.TITLE
var reduced_motion := false
var tutorial_dismissed := false
var win_age := 0.0
var result_stars := 0
var modal_layer: Control
var modal_shade: ColorRect
var title_card: Panel
var pause_card: Panel
var result_card: Panel
var trail_card: Panel
var play_button: Button
var resume_button: Button
var title_trail_button: Button
var pause_trail_button: Button
var replay_button: Button
var result_trail_button: Button
var trail_back_button: Button
var motion_button: Button
var result_title: Label
var result_note: Label
var reward_stars: WaferStars
var trail_scroll: ScrollContainer
var trail_rows: VBoxContainer
var trail_buttons: Array[Button] = []
var _card_tween: Tween
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
    _set_flow(Flow.TITLE, false)

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

func _label(text: String, font_size: int, alignment := HORIZONTAL_ALIGNMENT_CENTER, parent: Control = null) -> Label:
    var node := Label.new()
    node.text = text
    node.horizontal_alignment = alignment
    node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    node.add_theme_font_size_override("font_size", font_size)
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    (self if parent == null else parent).add_child(node)
    return node

func _button(text: String, callback: Callable, parent: Control = null, primary := false) -> Button:
    var node := Button.new()
    node.text = text
    node.custom_minimum_size = Vector2(52, 48)
    node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    node.pressed.connect(callback)
    (self if parent == null else parent).add_child(node)
    if primary:
        var style := theme.get_stylebox("normal", "Button").duplicate()
        style.bg_color = GOLD
        style.shadow_color = Color("dca13d")
        style.shadow_size = 2
        style.shadow_offset = Vector2(0, 4)
        node.add_theme_stylebox_override("normal", style)
        node.add_theme_font_size_override("font_size", 21)
    node.button_down.connect(func():
        node.pivot_offset = node.size / 2
        create_tween().tween_property(node, "scale", Vector2.ONE * 0.95, 0.07))
    node.button_up.connect(func():
        create_tween().tween_property(node, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
    return node

func _build_ui() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
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
    eyebrow = _label("THE BIG ESCAPE", 14)
    stats = _label("SHOT 00", 14)
    instruction = _label("Pull back… then release!", 16)
    undo_button = _button("Undo", _undo)
    pause_button = _button("Ⅱ", _toggle_pause)
    pause_button.tooltip_text = "Pause"
    modal_layer = Control.new()
    modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(modal_layer)
    modal_shade = ColorRect.new()
    modal_shade.color = Color(0.08, 0.26, 0.21, 0.19)
    modal_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    modal_layer.add_child(modal_shade)
    title_card = _card()
    var kitchen := _label("SUNSHINE KITCHEN", 13, HORIZONTAL_ALIGNMENT_CENTER, title_card)
    _place(kitchen, 16, 14, 348, 24)
    title_label = _label("Bunbreak", 43, HORIZONTAL_ALIGNMENT_CENTER, title_card)
    if ResourceLoader.exists("res://fonts/title.ttf"):
        title_label.add_theme_font_override("font", load("res://fonts/title.ttf"))
    _place(title_label, 10, 38, 360, 62)
    var welcome := _label("Four little buns. One big escape.", 15, HORIZONTAL_ALIGNMENT_CENTER, title_card)
    _place(welcome, 10, 105, 360, 30)
    play_button = _button("Play", _start_play, title_card, true)
    title_trail_button = _button("Kitchen trail", _show_trail, title_card)
    pause_card = _card()
    var pause_title := _label("A little breather", 28, HORIZONTAL_ALIGNMENT_CENTER, pause_card)
    _place(pause_title, 12, 18, 356, 46)
    resume_button = _button("Keep playing", _toggle_pause, pause_card, true)
    retry_button = _button("Retry", _retry, pause_card)
    hint_button = _button("Show me", _show_me, pause_card)
    mute_button = _button("Sound: on", _toggle_mute, pause_card)
    motion_button = _button("Motion: full", _toggle_reduced_motion, pause_card)
    pause_trail_button = _button("Kitchen trail", _show_trail, pause_card)
    var reassurance := _label("Unlimited tries. Take your time.", 14, HORIZONTAL_ALIGNMENT_CENTER, pause_card)
    _place(reassurance, 12, 345, 356, 28)
    result_card = _card()
    result_title = _label("Sweet freedom!", 31, HORIZONTAL_ALIGNMENT_CENTER, result_card)
    _place(result_title, 10, 19, 360, 51)
    reward_stars = WaferStars.new()
    result_card.add_child(reward_stars)
    _place(reward_stars, 28, 78, 324, 74)
    result_note = _label("", 16, HORIZONTAL_ALIGNMENT_CENTER, result_card)
    _place(result_note, 12, 164, 356, 72)
    replay_button = _button("Play again", _start_play, result_card, true)
    result_trail_button = _button("Kitchen trail", _show_trail, result_card)
    trail_card = _card()
    var trail_title := _label("The kitchen trail", 27, HORIZONTAL_ALIGNMENT_CENTER, trail_card)
    _place(trail_title, 10, 14, 360, 47)
    var trail_note := _label("One escape to play. More buns to come.", 14, HORIZONTAL_ALIGNMENT_CENTER, trail_card)
    _place(trail_note, 10, 62, 360, 32)
    trail_scroll = ScrollContainer.new()
    trail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    trail_card.add_child(trail_scroll)
    trail_rows = VBoxContainer.new()
    trail_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    trail_rows.add_theme_constant_override("separation", 10)
    trail_scroll.add_child(trail_rows)
    var names := ["Hello bun", "Better together", "Jelly belly", "Mango magic", "The big escape", "One happy family"]
    for index in range(names.size()):
        var row := _button("", _start_play, trail_rows)
        row.custom_minimum_size.y = 66
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.alignment = HORIZONTAL_ALIGNMENT_LEFT
        row.add_theme_font_size_override("font_size", 15)
        for state in ["normal", "hover", "pressed", "disabled"]:
            var cookie := theme.get_stylebox(state, "Button").duplicate()
            cookie.bg_color = Color("ffe9b9") if index == 4 else Color("ece9d5")
            cookie.border_color = Color("d8ba7d") if index == 4 else Color("d0d1bd")
            cookie.set_border_width_all(2)
            cookie.set_corner_radius_all(24)
            cookie.content_margin_left = 61
            row.add_theme_stylebox_override(state, cookie)
        row.draw.connect(_draw_trail_cookie.bind(row, index))
        row.disabled = index != 4
        trail_buttons.append(row)
        row.text = "%s  ·  Coming soon" % names[index] if index != 4 else "The big escape  ·  Play"
    trail_back_button = _button("Back", func(): _set_flow(Flow.TITLE), trail_card)

func _card() -> Panel:
    var card := Panel.new()
    var style := StyleBoxFlat.new()
    style.bg_color = CREAM
    style.set_corner_radius_all(28)
    style.set_border_width_all(3)
    style.border_color = Color("efcf83")
    style.shadow_color = Color(0.08, 0.24, 0.18, 0.22)
    style.shadow_size = 14
    style.shadow_offset = Vector2(0, 8)
    card.add_theme_stylebox_override("panel", style)
    modal_layer.add_child(card)
    return card

func _draw_trail_cookie(button: Button, index: int) -> void:
    var center := Vector2(30, button.size.y / 2)
    button.draw_circle(center, 18, Color("ffd057") if index == 4 else Color("ded7bb"), true, -1.0, true)
    button.draw_arc(center, 18, 0, TAU, 32, Color("b69861"), 1.5, true)
    var font := button.get_theme_font("font")
    button.draw_string(font, center + Vector2(-5, 6), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK if index == 4 else Color("8e8b74"))

func _place(node: Control, x: float, y: float, width: float, height: float) -> void:
    node.position = Vector2(x, y)
    node.size = Vector2(width, height)

func _layout() -> void:
    if not is_instance_valid(board_texture):
        return
    var board_height := minf(size.y - 132, (size.x - 16) / 0.70)
    var board_width := board_height * 0.70
    board_rect = Rect2((size.x - board_width) / 2.0, 72, board_width, board_height)
    board_texture.position = board_rect.position
    board_texture.size = board_rect.size
    if world_view:
        world_view.size = Vector2i(board_rect.size.round())
    _place(eyebrow, size.x / 2 - 100, 13, 200, 24)
    _place(stats, size.x / 2 - 90, 38, 180, 21)
    _place(instruction, board_rect.position.x, board_rect.end.y + 4, board_rect.size.x, 38)
    _place(undo_button, board_rect.position.x + 6, 17, 68, 48)
    _place(pause_button, board_rect.end.x - 66, 17, 60, 48)
    # Cards use a compact toy-like layout, with touch regions at least 48 canvas px.
    var card_width := minf(380, size.x - 28)
    var inset := (380 - card_width) / 2.0
    for card in [title_card, pause_card, result_card, trail_card]:
        card.size.x = card_width
        card.position.x = (size.x - card_width) / 2.0
        # Fixed-width card content remains centered on narrow phone layouts.
        for child in card.get_children():
            if child is Label:
                child.position.x = 10
                child.size.x = card_width - 20
                child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title_card.size.y = 294
    title_card.position.y = maxf(30, minf(size.y - 324, board_rect.position.y + board_rect.size.y * 0.54))
    _place(play_button, 26, 151, card_width - 52, 62)
    _place(title_trail_button, 70 - inset, 229, card_width - 140 + inset * 2, 48)
    pause_card.size.y = 390
    pause_card.position.y = maxf(18, (size.y - pause_card.size.y) / 2)
    _place(resume_button, 24, 82, card_width - 48, 62)
    _place(retry_button, 24, 159, (card_width - 60) / 2, 50)
    _place(hint_button, card_width / 2 + 6, 159, (card_width - 60) / 2, 50)
    _place(mute_button, 24, 223, (card_width - 60) / 2, 50)
    _place(motion_button, card_width / 2 + 6, 223, (card_width - 60) / 2, 50)
    motion_button.add_theme_font_size_override("font_size", 14)
    _place(pause_trail_button, 58 - inset, 289, card_width - 116 + inset * 2, 48)
    result_card.size.y = 396
    result_card.position.y = maxf(18, (size.y - result_card.size.y) / 2)
    _place(reward_stars, 28, 78, card_width - 56, 74)
    _place(replay_button, 26, 251, card_width - 52, 62)
    _place(result_trail_button, 70 - inset, 330, card_width - 140 + inset * 2, 48)
    trail_card.size.y = minf(680, size.y - 36)
    trail_card.position.y = (size.y - trail_card.size.y) / 2
    _place(trail_scroll, 18, 107, card_width - 36, maxf(60, trail_card.size.y - 187))
    _place(trail_back_button, 58 - inset, trail_card.size.y - 66, card_width - 116 + inset * 2, 48)
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("c6f2df"))
    draw_circle(Vector2(size.x * 0.86, size.y * 0.18), 90, Color("e9f6bb"), true, -1, true)
    draw_circle(Vector2(size.x * 0.10, size.y * 1.36), size.y * 0.46, Color("b3e8ce"), true, -1, true)
    draw_circle(Vector2(size.x * 0.92, size.y * 1.42), size.y * 0.55, Color("addfc6"), true, -1, true)

func _set_flow(next: Flow, animate := true) -> void:
    if _card_tween and _card_tween.is_valid():
        _card_tween.kill()
    if next != Flow.PLAY:
        _cancel_pull()
    flow = next
    paused = flow == Flow.PAUSE
    if stage:
        stage.process_mode = Node.PROCESS_MODE_DISABLED if flow in [Flow.PAUSE, Flow.TRAIL] else Node.PROCESS_MODE_INHERIT
    if audio:
        audio.stream_paused = flow in [Flow.PAUSE, Flow.TRAIL]
    var playing := flow == Flow.PLAY
    for control in [eyebrow, stats, instruction, undo_button, pause_button]:
        control.visible = playing
    modal_layer.visible = not playing
    title_card.visible = flow == Flow.TITLE
    pause_card.visible = flow == Flow.PAUSE
    result_card.visible = flow == Flow.RESULT
    trail_card.visible = flow == Flow.TRAIL
    for card in [title_card, pause_card, result_card, trail_card]:
        card.scale = Vector2.ONE
        card.modulate.a = 1.0
    if flow == Flow.RESULT:
        result_stars = 0 if demo_active else stars_for_shots(solver.shots)
        result_title.text = "Your turn!" if demo_active else "Sweet freedom!"
        result_note.text = "A practice escape. Try your own shot!" if demo_active else "%d shots · %s\nEscape · 6 shots · 4 shots" % [solver.shots, "New best!" if solver.shots == best_shots else "Happy little escape"]
        reward_stars.earned = result_stars
        reward_stars.age = 0
        reward_stars.reduced = reduced_motion
    if flow == Flow.TRAIL:
        trail_buttons[4].text = "The big escape  ·  %s" % ("★".repeat(stars_for_shots(best_shots)) if best_shots > 0 else "Play")
    _layout()
    _update_labels()
    if animate and not reduced_motion and not playing:
        var card: Control = {Flow.TITLE: title_card, Flow.PAUSE: pause_card, Flow.RESULT: result_card, Flow.TRAIL: trail_card}[flow]
        card.pivot_offset = card.size / 2
        card.scale = Vector2.ONE * 0.94
        card.modulate.a = 0.0
        _card_tween = create_tween().set_parallel(true)
        _card_tween.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        _card_tween.tween_property(card, "modulate:a", 1.0, 0.12)

func _start_play() -> void:
    _retry()

func _show_trail() -> void:
    _set_flow(Flow.TRAIL)

static func stars_for_shots(shots: int) -> int:
    if shots <= 0:
        return 0
    return 1 + int(shots <= GENTLE_SHOTS) + int(shots <= MASTERY_SHOTS)

func _toggle_reduced_motion() -> void:
    reduced_motion = not reduced_motion
    for node in bun_nodes.values():
        node.wobble_enabled = not reduced_motion
    if reduced_motion:
        sparkles.clear()
        jelly_bounce = 0
        jelly.scale = Vector3.ONE
    _write_progress()
    _update_labels()

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
            node.wobble_enabled = not reduced_motion
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
    if flow == Flow.PLAY:
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
    if flow == Flow.PLAY:
        _advance_demo(delta)
        if solver.won:
            win_age += delta
            if win_age >= (0.15 if reduced_motion else 0.70):
                _set_flow(Flow.RESULT)
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
                if bun_nodes.has(event.id) and not reduced_motion:
                    bun_nodes[event.id].impact(event.normal, event.strength)
                _sound(220, 0.09)
            "merge":
                if bun_nodes.has(event.id):
                    if reduced_motion:
                        bun_nodes[event.id].reset_motion(true)
                    else:
                        bun_nodes[event.id].merge()
                    _sparkle(solver.find_bun(event.id).position)
                _sound(740, 0.22)
            "jelly":
                jelly_bounce = 0.0 if reduced_motion else 1.0
                _sound(320, 0.15)
            "gate":
                gate_break_age = 0
                _sparkle(Vector2(0, solver.level.gate_y))
                _sound(980, 0.22)
            "escape":
                if bun_nodes.has(event.id) and not reduced_motion:
                    bun_nodes[event.id].play_clip("escape")
                _sparkle(solver.level.exit)
                _sound(1040, 0.4)
                _save_progress()
    solver.events.clear()

func _sparkle(pos: Vector2) -> void:
    if reduced_motion:
        return
    for i in range(8):
        var angle := i * TAU / 8
        sparkles.append({"position": pos, "offset": Vector2.ZERO, "velocity": Vector2(cos(angle), sin(angle)) * 65, "age": 0.0})

func _update_labels() -> void:
    undo_button.disabled = undo_history.is_empty() or flow != Flow.PLAY
    hint_button.disabled = demo_moves.is_empty()
    mute_button.text = "Sound: off" if muted else "Sound: on"
    motion_button.text = "Motion: reduced" if reduced_motion else "Motion: full"
    stats.text = "SHOT  %02d" % solver.shots
    instruction.text = "Pull back… then release!" if not tutorial_dismissed else "Make a Mango. Crack the wafer."
    if demo_active:
        instruction.text = "Watch the buns… then try your own shot."
    elif selected_id >= 0:
        instruction.text = "Hold… %d%% · release!" % roundi(pull_amount * 100)
    elif solver.is_moving():
        instruction.text = "Boing!"
    elif solver.won:
        instruction.text = "Sweet freedom!"

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
        _go_back()
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
    if flow != Flow.PLAY or paused or solver.won or solver.is_moving() or selected_id >= 0 or not board_rect.has_point(point):
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
    if flow == Flow.PLAY and not canceled and board_rect.has_point(point) and pull_amount >= 0.045:
        undo_history.append(solver.snapshot())
        solver.shoot(selected_id, launch_velocity)
        tutorial_dismissed = true
        _write_progress()
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
        if world_view and flow == Flow.PLAY:
            _toggle_pause()
    elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
        _go_back()

func _go_back() -> void:
    if flow in [Flow.PLAY, Flow.PAUSE]:
        _toggle_pause()
    elif flow == Flow.RESULT:
        _show_trail()
    elif flow == Flow.TRAIL:
        _set_flow(Flow.TITLE)

func _toggle_pause() -> void:
    if flow == Flow.PLAY:
        _set_flow(Flow.PAUSE)
    elif flow == Flow.PAUSE:
        _set_flow(Flow.PLAY)

func _toggle_mute() -> void:
    muted = not muted
    if muted:
        audio.stop()
    _write_progress()
    _update_labels()

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
    win_age = 0
    _sync_buns()

func _retry() -> void:
    _cancel_pull()
    demo_active = false
    solver.reset()
    undo_history.clear()
    _clear_visuals()
    _set_flow(Flow.PLAY)
    _update_labels()

func _undo() -> void:
    if undo_history.is_empty() or flow not in [Flow.PLAY, Flow.RESULT]:
        return
    _cancel_pull()
    demo_active = false
    solver.restore(undo_history.pop_back())
    _clear_visuals()
    _set_flow(Flow.PLAY)
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
        tutorial_dismissed = config.get_value("progress", "tutorial_dismissed", false)
        muted = config.get_value("settings", "muted", false)
        reduced_motion = config.get_value("settings", "reduced_motion", false)

func _save_progress() -> void:
    if demo_active:
        return
    if best_shots == 0 or solver.shots < best_shots:
        best_shots = solver.shots
        _write_progress()

func _write_progress() -> void:
    var config := ConfigFile.new()
    config.set_value("progress", "best_shots", best_shots)
    config.set_value("progress", "tutorial_dismissed", tutorial_dismissed)
    config.set_value("settings", "muted", muted)
    config.set_value("settings", "reduced_motion", reduced_motion)
    config.save("user://progress.cfg")
