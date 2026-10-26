extends Node
var game: Control
var elapsed := 0.0
var captured := false
var win_age := 0.0
var mode := "play"

func _ready() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--mode="):
            mode = arg.trim_prefix("--mode=")
    game = load("res://main.tscn").instantiate()
    add_child(game)
    game.muted = false
    game.reduced_motion = false
    for visual in game.bun_nodes.values():
        visual.wobble_enabled = true
    if mode == "desktop":
        get_window().size = Vector2i(1280, 800)
    elif mode != "play":
        get_window().size = Vector2i(720, 1120)
    if mode == "play":
        game._show_me()
    elif mode != "title":
        game._start_play()
        if mode == "pause":
            game._toggle_pause()

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed > 0.5 and not captured:
        captured = true
        await RenderingServer.frame_post_draw
        var screenshot := get_viewport().get_texture().get_image()
        screenshot.save_png("res://../renders/game-" + mode + ".png")
        if mode != "play":
            get_tree().quit()
    if game.solver.won:
        win_age += delta
        if win_age > 1.2:
            await RenderingServer.frame_post_draw
            get_viewport().get_texture().get_image().save_png("res://../renders/game-win.png")
            get_tree().quit()
    if elapsed > 40:
        push_error("Review replay did not finish within forty simulated seconds")
        get_tree().quit(1)
