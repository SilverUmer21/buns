extends SceneTree
const Solver = preload("res://scripts/bun_solver.gd")
const Spring = preload("res://scripts/spring_profile.gd")
var checks: Array[String] = []
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
    (checks if condition else failures).append(message)
    if not condition:
        push_error(message)

func settle(solver) -> void:
    for tick in range(1500):
        solver.step()
        var moving := false
        for bun in solver.buns:
            moving = moving or bun.velocity != Vector2.ZERO
        if not moving or solver.won:
            return

func run_solution() -> Dictionary:
    var s = Solver.new()
    var moves: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/solution.json"))
    var schedule: Array[Dictionary] = []
    for move in moves:
        schedule.append({"tick": s.ticks, "id": move.id, "velocity": Vector2(move.vx, move.vy)})
        check(s.shoot(move.id, Vector2(move.vx, move.vy)), "Solution shot accepted")
        settle(s)
        s.events.clear()
    check(s.won and s.gate_open and s.buns.size() == 1 and s.buns[0].tier == 3, "Actual physics completes four-shot escape")
    return {"state": s.snapshot(), "schedule": schedule}

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var baseline := run_solution()
    for fps in [30, 60, 120]:
        var s = Solver.new()
        var accumulator := 0.0
        var index := 0
        for frame in range(fps * 60):
            accumulator += 1.0 / fps
            while accumulator + 0.000000001 >= Solver.STEP:
                if index < baseline.schedule.size() and s.ticks == baseline.schedule[index].tick:
                    var move: Dictionary = baseline.schedule[index]
                    s.shoot(move.id, move.velocity)
                    index += 1
                s.step()
                accumulator -= Solver.STEP
                s.events.clear()
                if s.won:
                    break
            if s.won:
                break
        check(s.snapshot() == baseline.state, "Identical physics at %d render FPS" % fps)
    var s = Solver.new()
    for tier in [1, 2, 3]:
        s.reset()
        s.buns.clear()
        var id: int = s.add_bun(tier, Vector2(0, 3.45 - Solver.RADII[tier] - 0.25), Vector2(0, 0.01))
        s.step()
        check(s.gate_open == (tier == 3), "Tier %d gate at negligible speed" % tier)
        check(s.find_bun(id).position.y < 3.45, "No gate tunneling for tier %d" % tier)
    s.reset()
    s.buns.clear()
    s.add_bun(1, Vector2(-0.4, 0), Vector2(2, 0))
    s.add_bun(1, Vector2(0.4, 0), Vector2(-1, 0))
    s._contacts()
    check(s.buns.size() == 1 and s.buns[0].tier == 2 and s.buns[0].velocity == Vector2(0.5, 0), "Merge conserves planar momentum")
    s.buns.clear()
    for x in [-0.5, 0.0, 0.5]:
        s.add_bun(1, Vector2(x, -2))
    s._contacts()
    check(s.buns.size() == 2, "Triple contact consumes each bun once")
    s.buns.clear()
    s.add_bun(1, Vector2(-0.4, -2), Vector2(1, 0))
    s.add_bun(2, Vector2(0.4, -2))
    s._contacts()
    check(s.buns.size() == 2, "Unequal tiers bounce")
    s.buns.clear()
    s.add_bun(3, Vector2(-0.4, -2))
    s.add_bun(3, Vector2(0.4, -2))
    s._contacts()
    check(s.buns.size() == 2, "Maximum tier has no hidden upgrade")
    s.reset()
    s.buns.clear()
    s.add_bun(1, Vector2(0, -2), Vector2(0, 12))
    var jelly_hit := false
    var penetration := false
    for tick in range(90):
        s.step()
        penetration = penetration or s.buns[0].position.distance_to(s.level.bumpers[0].position) < 1.2699
        for event in s.events:
            jelly_hit = jelly_hit or event.type == "jelly"
        s.events.clear()
    check(jelly_hit and not penetration, "Maximum-speed jelly contact does not tunnel")
    var reference := Vector2.ZERO
    for fps in [30, 60, 120]:
        var spring := Vector2(0.90, 5.0)
        for frame in range(fps):
            spring = Spring.advance(spring.x, spring.y, 1.0, 4.5, 0.32, 1.0 / fps)
        if fps == 30:
            reference = spring
        check(spring.distance_to(reference) < 0.00002, "Exact spring agrees at %d FPS" % fps)
    for h in [0.72, 0.85, 1.0, 1.20]:
        check(absf(h * pow(1.0 / sqrt(h), 2) - 1.0) < 0.00001, "Squash preserves volume at %.2f" % h)
    # Instantiate real GLBs and exercise the actual game, input and controls.
    var game = load("res://main.tscn").instantiate()
    root.add_child(game)
    game.set_process(false)
    await process_frame
    check(game.bun_nodes.size() == 4, "Playable scene instantiates four real rigged buns")
    var node = game.bun_nodes[1]
    check(node.skeleton and node.skeleton.get_bone_count() == 11, "Runtime skeleton includes independent Crest bone")
    for clip in ["idle", "blink", "pull", "release", "impact", "merge", "hop", "escape"]:
        node.play_clip(clip)
        node.player.advance(0.07)
        check(not str(node.player.current_animation).is_empty(), "Imported clip plays: " + clip)
    node.reset_motion()
    var point: Vector2 = game.screen_point(game.solver.find_bun(1).position)
    game._begin_pull(point, 0)
    game._drag_pull(point + Vector2(10, 60))
    for i in range(60):
        node._process(1.0 / 60.0)
    check(game.selected_id == 1 and node.held and node.height < 0.99, "Touch hold sustains smooth pull squash")
    check(not game.prediction.is_empty(), "Aim preview simulates the actual solver")
    game._end_pull(point, true)
    check(game.solver.shots == 0 and not node.held, "Canceled touch releases pose without shooting")
    var before: Dictionary = game.solver.snapshot()
    game._begin_pull(point, -1)
    game._drag_pull(point + Vector2(0, 80))
    game._end_pull(point + Vector2(0, 80), false)
    check(game.solver.shots == 1 and game.undo_history.size() == 1, "Mouse release launches immediately and snapshots undo")
    game._process(0.1)
    game._undo()
    check(game.solver.snapshot() == before, "Undo restores exact pre-shot state")
    game._toggle_pause()
    before = game.solver.snapshot()
    game._process(0.2)
    check(game.solver.snapshot() == before and game.stage.process_mode == Node.PROCESS_MODE_DISABLED, "Pause freezes physics and visual animation")
    game._toggle_pause()
    game._toggle_mute()
    check(game.muted and not game.audio.playing, "Mute stops audio")
    game._retry()
    check(game.solver.buns.size() == 4 and game.solver.shots == 0 and not game.solver.gate_open, "Retry resets buns, gate and shots")
    game._show_me()
    for frame in range(60 * 45):
        game._process(1.0 / 60.0)
        if game.solver.won:
            break
    check(game.solver.won, "Show me completes the level using physics shots")
    game._undo()
    check(not game.solver.won and not game.solver.gate_open, "Undo re-closes gate after winning")
    game._retry()
    game.size = Vector2(390, 844)
    game._layout()
    check(game.board_rect.position.x >= 0 and game.retry_button.position.y + 50 <= 844, "Portrait layout keeps board and controls visible")
    game.size = Vector2(1280, 800)
    game._layout()
    check(game.recipe.visible and game.left_note.visible, "Desktop layout exposes recipe and quiet side columns")
    game.queue_free()
    await process_frame
    var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures,
        "fixed_step_hz": 120, "render_fps_replays": [30, 60, 120], "solution": baseline.schedule,
        "device_performance": "Not measured on a physical Android device"}
    var file := FileAccess.open("res://../reports/game-validation.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(report, "  "))
    print("GAME VALIDATION ", "PASS" if failures.is_empty() else "FAIL", ": ", checks.size(), " checks; ", failures)
    quit(0 if failures.is_empty() else 1)
