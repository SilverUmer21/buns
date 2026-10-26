extends Control
## An asset inspector, separate from gameplay physics and collision shapes.

const CREAM := Color("fff9eb")
const INK := Color("245d56")
const MUTED := Color("66877e")
const GOLD := Color("ffd56c")
const ASSETS := {
    "pip": {"title": "Pip", "note": "Cream dough · folded crest · tier 01"},
    "berry": {"title": "Berry", "note": "Strawberry pink · petal crest · tier 02"},
    "mango": {"title": "Mango", "note": "Golden dough · rounded crown · tier 03"},
    "tray": {"title": "The turquoise tray", "note": "Glazed ceramic · soft vanilla rim"},
    "wafer_gate": {"title": "Wafer gate", "note": "Strawberry wafer · embossed biscuit supports"},
    "jelly_bumper": {"title": "Jelly bumper", "note": "Eight glossy lobes · vanilla saucer"},
    "reward_star": {"title": "A little sunshine", "note": "Golden reward · cream star inlay"},
    "exit_plate": {"title": "The escape plate", "note": "Turquoise glaze · embossed bun emblem"},
    "board": {"title": "Sunshine kitchen", "note": "A composed board · planar game layout"},
}
const CLIPS := ["idle", "blink", "pull", "release", "impact", "merge", "hop", "escape"]
var viewport: SubViewport
var camera: Camera3D
var stage: Node3D
var model: Node3D
var player: AnimationPlayer
var selected := "pip"
var asset_title: Label
var asset_note: Label
var status: Label
var clip_picker: OptionButton
var play_button: Button
var grid: GridContainer
var stage_card: VBoxContainer
var sidebar: VBoxContainer
var view_container: SubViewportContainer
var dragging := false
var last_pointer := Vector2.ZERO
var autoplay := true
var intro_label: Label


func _ready() -> void:
    _make_theme()
    _build_ui()
    _build_world()
    _select_asset("pip")
    resized.connect(_responsive)
    _responsive()


func _make_theme() -> void:
    var t := Theme.new()
    t.default_font_size = 17
    t.set_color("font_color", "Label", INK)
    t.set_color("font_color", "Button", INK)
    t.set_color("font_hover_color", "Button", INK)
    t.set_color("font_pressed_color", "Button", INK)
    t.set_color("font_color", "OptionButton", INK)
    for state in ["normal", "hover", "pressed", "focus"]:
        var box := StyleBoxFlat.new()
        box.bg_color = CREAM if state == "normal" else Color("f8df9e")
        box.corner_radius_top_left = 14
        box.corner_radius_top_right = 14
        box.corner_radius_bottom_left = 14
        box.corner_radius_bottom_right = 14
        box.content_margin_left = 16
        box.content_margin_right = 16
        box.content_margin_top = 12
        box.content_margin_bottom = 12
        if state == "focus":
            box.bg_color = Color(0, 0, 0, 0)
            box.set_border_width_all(2)
            box.border_color = INK
        t.set_stylebox(state, "Button", box)
        t.set_stylebox(state, "OptionButton", box)
    theme = t


func label(text: String, font_size: int, color: Color = INK) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", color)
    return l


func button(text: String, callback: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size.y = 48
    b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    b.pressed.connect(callback)
    return b


func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color("edf3e9")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)
    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    var margin := MarginContainer.new()
    margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 28)
    scroll.add_child(margin)
    var page := VBoxContainer.new()
    page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    page.add_theme_constant_override("separation", 16)
    margin.add_child(page)
    page.add_child(label("BUNBREAK / SUNSHINE KITCHEN", 16))
    intro_label = label("Little buns. Big personalities.", 34)
    intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    page.add_child(intro_label)
    var description := label("Explore the characters, their expressions, and a kitchen full of possibilities.", 16, MUTED)
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    page.add_child(description)
    grid = GridContainer.new()
    grid.columns = 2
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 24)
    grid.add_theme_constant_override("v_separation", 24)
    page.add_child(grid)
    stage_card = VBoxContainer.new()
    stage_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stage_card.add_theme_constant_override("separation", 8)
    grid.add_child(stage_card)
    asset_title = label("Pip", 28)
    stage_card.add_child(asset_title)
    asset_note = label("", 15, MUTED)
    asset_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stage_card.add_child(asset_note)
    view_container = SubViewportContainer.new()
    view_container.stretch = true
    view_container.custom_minimum_size = Vector2(260, 490)
    view_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    view_container.mouse_filter = Control.MOUSE_FILTER_STOP
    view_container.gui_input.connect(_view_input)
    stage_card.add_child(view_container)
    viewport = SubViewport.new()
    viewport.size = Vector2i(800, 600)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.own_world_3d = true
    view_container.add_child(viewport)
    status = label("", 14, MUTED)
    stage_card.add_child(status)
    var under := HBoxContainer.new()
    under.add_theme_constant_override("separation", 12)
    under.add_child(button("Reset view", _reset_view))
    var hint := label("Drag to turn · scroll to zoom", 14, MUTED)
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    under.add_child(hint)
    stage_card.add_child(under)
    sidebar = VBoxContainer.new()
    sidebar.custom_minimum_size.x = 280
    sidebar.add_theme_constant_override("separation", 12)
    grid.add_child(sidebar)
    sidebar.add_child(label("MEET THE BUNS", 13, MUTED))
    for key in ["pip", "berry", "mango"]:
        sidebar.add_child(button(ASSETS[key]["title"], _select_asset.bind(key)))
    sidebar.add_child(HSeparator.new())
    sidebar.add_child(label("IN THE KITCHEN", 13, MUTED))
    var props := OptionButton.new()
    props.custom_minimum_size.y = 48
    props.add_item("Choose a prop…")
    var keys := ["tray", "wafer_gate", "jelly_bumper", "reward_star", "exit_plate"]
    for key in keys:
        props.add_item(ASSETS[key]["title"])
    props.item_selected.connect(func(index: int):
        if index > 0:
            _select_asset(keys[index - 1]))
    sidebar.add_child(props)
    sidebar.add_child(button("View the whole board", _select_asset.bind("board")))
    sidebar.add_child(HSeparator.new())
    sidebar.add_child(label("A LITTLE MOVEMENT", 13, MUTED))
    clip_picker = OptionButton.new()
    clip_picker.custom_minimum_size.y = 48
    for clip in CLIPS:
        clip_picker.add_item(clip.capitalize())
    clip_picker.item_selected.connect(_select_clip)
    sidebar.add_child(clip_picker)
    play_button = button("Pause animation", _toggle_play)
    sidebar.add_child(play_button)
    var note := label("Soft dough. Happy faces.\nMade to bounce, merge, and escape.", 16, MUTED)
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    sidebar.add_child(note)
    var footer := label("ASSET ATELIER · ORIGINAL 3D MODELS · BLENDER → GODOT", 12, MUTED)
    footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    page.add_child(footer)


func _build_world() -> void:
    stage = Node3D.new()
    viewport.add_child(stage)
    var env := WorldEnvironment.new()
    env.environment = Environment.new()
    env.environment.background_mode = Environment.BG_COLOR
    env.environment.background_color = Color("d9ece1")
    env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color = Color("fff0d1")
    env.environment.ambient_light_energy = 0.65
    env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
    stage.add_child(env)
    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-45, -35, 0)
    key.light_color = Color("fff1da")
    key.light_energy = 1.2
    key.shadow_enabled = true
    key.directional_shadow_max_distance = 40
    stage.add_child(key)
    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-25, 145, 0)
    fill.light_color = Color("d0edff")
    fill.light_energy = 0.45
    stage.add_child(fill)
    var plane := MeshInstance3D.new()
    var plane_mesh := PlaneMesh.new()
    plane_mesh.size = Vector2(200, 200)
    plane.mesh = plane_mesh
    var plane_mat := StandardMaterial3D.new()
    plane_mat.albedo_color = Color("d9ece1")
    plane_mat.roughness = 0.85
    plane.material_override = plane_mat
    plane.position.y = -0.015
    stage.add_child(plane)
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.near = 0.05
    camera.far = 250
    stage.add_child(camera)
    camera.current = true


func _instance(key: String) -> Node3D:
    var resource := load("res://assets/" + key + ".glb") as PackedScene
    if resource == null:
        push_error("Cannot load asset: " + key)
        return Node3D.new()
    return resource.instantiate() as Node3D


func _select_asset(key: String) -> void:
    selected = key
    if is_instance_valid(model):
        stage.remove_child(model)
        model.queue_free()
    player = null
    if key == "board":
        model = Node3D.new()
        stage.add_child(model)
        _board_part("tray", Vector3.ZERO)
        _board_part("wafer_gate", Vector3(0, 0.215, -3.65))
        _board_part("exit_plate", Vector3(0, 0.215, -4.50), 0.65)
        _board_part("pip", Vector3(-1.75, 0.215, 2.80))
        _board_part("pip", Vector3(1.65, 0.215, 2.50))
        _board_part("berry", Vector3(-1.60, 0.215, -0.10), 1.05)
        _board_part("mango", Vector3(1.35, 0.215, -1.30), 1.08)
        _board_part("jelly_bumper", Vector3(0.70, 0.215, 1.0), 1.12)
    else:
        model = _instance(key)
        stage.add_child(model)
        player = find_player(model)
    asset_title.text = ASSETS[key]["title"]
    asset_note.text = ASSETS[key]["note"]
    clip_picker.disabled = player == null
    play_button.disabled = player == null
    autoplay = true
    play_button.text = "Pause animation"
    _reset_view()
    _select_clip(clip_picker.selected)


func _board_part(key: String, pos: Vector3, scale_factor: float = 1.0) -> void:
    var part := _instance(key)
    model.add_child(part)
    part.position = pos
    part.scale = Vector3.ONE * scale_factor
    if key in ["pip", "berry", "mango"]:
        part.rotation.x = -0.35
    var anim := find_player(part)
    if anim:
        var clip := resolve_clip(anim, "idle")
        if not clip.is_empty():
            anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
            anim.play(clip)


static func find_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var found := find_player(child)
        if found:
            return found
    return null


static func resolve_clip(anim: AnimationPlayer, clip: String) -> String:
    for candidate in anim.get_animation_list():
        if candidate == clip or candidate.ends_with("/" + clip):
            return candidate
    return ""


func _select_clip(index: int) -> void:
    if player == null:
        status.text = "Drag to inspect the form and materials."
        return
    var clip := resolve_clip(player, CLIPS[index])
    if clip.is_empty():
        status.text = "This animation is unavailable."
        return
    player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if CLIPS[index] == "idle" else Animation.LOOP_NONE
    player.play(clip)
    if not autoplay:
        player.pause()
    status.text = "%s · %0.2f seconds · 60 fps" % [CLIPS[index].capitalize(), player.get_animation(clip).length]


func _toggle_play() -> void:
    if player == null:
        return
    autoplay = not autoplay
    if autoplay:
        player.play()
    else:
        player.pause()
    play_button.text = "Pause animation" if autoplay else "Play animation"


func _reset_view() -> void:
    if not is_instance_valid(model):
        return
    model.rotation = Vector3.ZERO
    if selected in ["board", "tray"]:
        camera.position = Vector3(0, 17, 10)
        camera.size = 13.2
        camera.look_at(Vector3(0, 0.2, 0))
    elif selected == "wafer_gate":
        camera.position = Vector3(2.8, 2.5, 6)
        camera.size = 7.6
        camera.look_at(Vector3(0, 0.4, 0))
    else:
        camera.position = Vector3(2.1, 2.25, 5)
        camera.size = 2.65 if selected in ["pip", "berry", "mango"] else 2.7
        camera.look_at(Vector3(0, 0.78 if selected in ["pip", "berry", "mango"] else 0.3, 0))


func _view_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            dragging = event.pressed
            last_pointer = event.position
        if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            camera.size = max(1.5, camera.size * 0.9)
        if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            camera.size = min(24.0, camera.size * 1.1)
    elif event is InputEventMouseMotion and dragging:
        model.rotation.y += event.relative.x * 0.01
    elif event is InputEventScreenTouch:
        dragging = event.pressed
        last_pointer = event.position
    elif event is InputEventScreenDrag:
        model.rotation.y += event.relative.x * 0.01


func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_R:
        _reset_view()


func _responsive() -> void:
    if grid == null:
        return
    var compact := size.x < 820
    grid.columns = 1 if compact else 2
    view_container.custom_minimum_size.y = 380 if compact else 490
    intro_label.add_theme_font_size_override("font_size", 26 if compact else 34)
