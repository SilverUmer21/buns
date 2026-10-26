extends SceneTree
## Exercise actual scene state, controls, rewards and persistence.
var checks: Array[String] = []
var failures: Array[String] = []
var had_progress := false
var previous_progress := PackedByteArray()

func check(condition: bool, text: String) -> void:
    (checks if condition else failures).append(text)
    if not condition:
        push_error(text)

func complete(game, demo := false) -> void:
    if demo:
        game._show_me()
        for frame in range(60 * 50):
            game._process(1.0 / 60)
            if game.flow == game.Flow.RESULT:
                break
        return
    game._start_play()
    for move in game.demo_moves:
        game.undo_history.append(game.solver.snapshot())
        game.solver.shoot(int(move.id), Vector2(move.vx, move.vy))
        for frame in range(60 * 12):
            game._process(1.0 / 60)
            if not game.solver.is_moving() or game.solver.won:
                break
        for frame in range(36):
            game._process(1.0 / 60)
    for frame in range(90):
        game._process(1.0 / 60)
        if game.flow == game.Flow.RESULT:
            break

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    had_progress = FileAccess.file_exists("user://progress.cfg")
    if had_progress:
        previous_progress = FileAccess.get_file_as_bytes("user://progress.cfg")
    var game = load("res://main.tscn").instantiate()
    root.add_child(game)
    game.set_process(false)
    await process_frame
    game.best_shots = 0
    game.muted = false
    game.reduced_motion = false
    game.tutorial_dismissed = false
    game._write_progress()
    check(game.flow == game.Flow.TITLE and game.title_card.is_visible_in_tree(), "Game opens on a single Play title card")
    check(not game.pause_button.is_visible_in_tree() and not game.undo_button.is_visible_in_tree(), "Title hides the in-play HUD")
    var ticks: int = game.solver.ticks
    game._process(0.2)
    check(game.solver.ticks == ticks, "Title world idles without advancing puzzle simulation")
    var point: Vector2 = game.screen_point(game.solver.find_bun(1).position)
    game._begin_pull(point, 0)
    check(game.selected_id == -1, "Title cannot select or launch a bun behind the card")
    game.play_button.pressed.emit()
    check(game.flow == game.Flow.PLAY and not game.modal_layer.visible, "Play starts the actual puzzle and dismisses the card")
    check(game.pause_button.is_visible_in_tree() and game.undo_button.is_visible_in_tree(), "Play retains compact recovery controls")
    check(not game.title_label.is_visible_in_tree() and not game.retry_button.is_visible_in_tree() and not game.hint_button.is_visible_in_tree(), "Play has no marketing heading or persistent menu actions")
    game._begin_pull(point, 0)
    game._drag_pull(point + Vector2(0, 70))
    check(game.selected_id == 1 and game.bun_nodes[1].held, "Play allows held touch aiming")
    game._toggle_pause()
    check(game.flow == game.Flow.PAUSE and game.paused and game.pause_card.is_visible_in_tree(), "Pause presents a focused kitchen sheet")
    check(game.selected_id == -1 and game.solver.shots == 0 and not game.bun_nodes[1].held, "Opening pause cancels a held shot")
    var paused_state: Dictionary = game.solver.snapshot()
    game._process(0.2)
    check(game.solver.snapshot() == paused_state and game.stage.process_mode == Node.PROCESS_MODE_DISABLED, "Paused simulation and character animation remain frozen")
    game._toggle_mute()
    game._toggle_reduced_motion()
    check(game.muted and game.reduced_motion, "Pause settings independently toggle sound and reduced motion")
    var reduced := true
    for node in game.bun_nodes.values():
        reduced = reduced and not node.wobble_enabled
    check(reduced, "Reduced motion propagates to every current bun")
    game.resume_button.pressed.emit()
    check(game.flow == game.Flow.PLAY and not game.paused and game.stage.process_mode == Node.PROCESS_MODE_INHERIT, "Keep playing resumes puzzle and animation")
    game._show_trail()
    check(game.flow == game.Flow.TRAIL and game.trail_card.is_visible_in_tree(), "Kitchen trail is a distinct game state")
    var enabled := 0
    var upcoming := 0
    for index in range(game.trail_buttons.size()):
        var button: Button = game.trail_buttons[index]
        enabled += int(not button.disabled)
        upcoming += int(button.disabled and button.text.contains("Coming soon"))
    check(enabled == 1 and upcoming == 5 and not game.trail_buttons[4].disabled, "Trail exposes exactly one real stage and five explicitly upcoming stages")
    ticks = game.solver.ticks
    game._process(0.2)
    check(game.solver.ticks == ticks, "Trail does not keep the puzzle moving in the background")
    game.trail_buttons[4].pressed.emit()
    check(game.flow == game.Flow.PLAY and game.solver.buns.size() == 4 and game.solver.shots == 0, "Available trail cookie starts the verified Big Escape layout")
    game._show_trail()
    game.trail_back_button.pressed.emit()
    check(game.flow == game.Flow.TITLE, "Trail Back returns to the title without inventing progression")
    complete(game, true)
    check(game.flow == game.Flow.RESULT and game.solver.won and game.demo_active, "Show me uses real physics and reaches the result state")
    check(game.best_shots == 0 and game.result_stars == 0, "A demonstration never awards completion or mastery progress")
    game.replay_button.pressed.emit()
    check(game.flow == game.Flow.PLAY and not game.demo_active and not game.solver.won, "Play again starts a clean player attempt")
    complete(game)
    check(game.flow == game.Flow.RESULT and game.solver.won and game.solver.shots == 4, "A real four-shot escape reaches completion reveal")
    check(game.result_stars == 3 and game.reward_stars.earned == 3 and game.best_shots == 4, "Verified player solution earns completion and both optional shot targets")
    check(game.stars_for_shots(9) == 1 and game.stars_for_shots(6) == 2 and game.stars_for_shots(4) == 3, "Any clear earns a star; optional targets never block completion")
    game._show_trail()
    check(game.trail_buttons[4].text.contains("★★★"), "Completed trail cookie reflects earned mastery")
    game._set_flow(game.Flow.RESULT, false)
    game._undo()
    check(game.flow == game.Flow.PLAY and not game.solver.won and not game.solver.gate_open, "Undo from a completed puzzle restores the pre-winning shot and gameplay")
    check(game.best_shots == 4, "Undo does not erase an already earned best result")
    for viewport_size in [Vector2(390, 844), Vector2(1280, 800)]:
        game.size = viewport_size
        game._layout()
        check(game.board_rect.position.x >= 0 and game.board_rect.end.x <= viewport_size.x and game.board_rect.end.y <= viewport_size.y, "Board fits %s viewport" % viewport_size)
        check(not game.undo_button.get_rect().intersects(game.board_rect) and not game.pause_button.get_rect().intersects(game.board_rect), "Compact HUD clears the board at %s" % viewport_size)
        game._set_flow(game.Flow.PAUSE, false)
        var in_bounds := true
        for button in [game.resume_button, game.retry_button, game.hint_button, game.mute_button, game.motion_button]:
            var rect: Rect2 = button.get_global_rect()
            in_bounds = in_bounds and rect.position.x >= 0 and rect.end.x <= viewport_size.x and rect.position.y >= 0 and rect.end.y <= viewport_size.y and rect.size.y >= 48
        check(in_bounds, "Pause buttons remain reachable at %s" % viewport_size)
        game._set_flow(game.Flow.PLAY, false)
    var reloaded = load("res://main.tscn").instantiate()
    root.add_child(reloaded)
    reloaded.set_process(false)
    await process_frame
    check(reloaded.best_shots == 4 and reloaded.muted and reloaded.reduced_motion, "Earned best and accessibility settings survive a fresh scene")
    reloaded.queue_free()
    game.queue_free()
    await process_frame
    await process_frame
    if had_progress:
        var saved := FileAccess.open("user://progress.cfg", FileAccess.WRITE)
        saved.store_buffer(previous_progress)
    else:
        DirAccess.remove_absolute(ProjectSettings.globalize_path("user://progress.cfg"))
    var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures,
        "states": ["title", "play", "pause", "result", "trail"], "implemented_stages": 1, "upcoming_stages": 5,
        "star_targets": {"completion": "Any successful player escape", "gentle": 6, "mastery": 4,
        "tuning_status": "Provisional: four-shot route verified, six allows two extra shots; human difficulty tuning pending"},
        "scope": "Headless scene/input/progression verification; rendered visual and real-device review remain separate"}
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../reports"))
    var file := FileAccess.open("res://../reports/flow-validation.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(report, "  "))
    print("FLOW VALIDATION ", "PASS" if failures.is_empty() else "FAIL", ": ", checks.size(), " checks; ", failures)
    quit(0 if failures.is_empty() else 1)
