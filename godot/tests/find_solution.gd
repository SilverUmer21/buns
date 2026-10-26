extends SceneTree
const Solver = preload("res://scripts/bun_solver.gd")

func settle(solver) -> void:
    for tick in range(1500):
        solver.step()
        if not solver.is_moving():
            break
    # Always settle fully, including velocities below the input lock threshold.
    for tick in range(30):
        solver.step()
    solver.events.clear()

func _initialize() -> void:
    var s = Solver.new()
    var moves: Array = []
    for move in [[1, Vector2(0, 5.4)], [2, Vector2(0, 5.4)], [5, Vector2(7, 0)]]:
        s.shoot(move[0], move[1])
        settle(s)
        moves.append({"id": move[0], "vx": move[1].x, "vy": move[1].y})
    var state: Dictionary = s.snapshot()
    print("FINAL SEARCH FROM ", s.buns)
    for velocity in [Vector2(-4, 9), Vector2(-4.2, 9.5), Vector2(-4.3, 10), Vector2(-4.5, 10)]:
        s.restore(state)
        s.shoot(7, velocity)
        settle(s)
        if s.won:
            moves.append({"id": 7, "vx": velocity.x, "vy": velocity.y})
            var file := FileAccess.open("res://data/solution.json", FileAccess.WRITE)
            file.store_string(JSON.stringify(moves, "  "))
            print("SOLUTION ", moves)
            quit()
            return
    for vx in range(-70, 11):
        for vy in range(65, 121, 2):
            s.restore(state)
            var velocity := Vector2(vx / 10.0, vy / 10.0).limit_length(12)
            s.shoot(7, velocity)
            settle(s)
            if s.won:
                moves.append({"id": 7, "vx": velocity.x, "vy": velocity.y})
                var file := FileAccess.open("res://data/solution.json", FileAccess.WRITE)
                file.store_string(JSON.stringify(moves, "  "))
                print("SOLUTION ", moves)
                quit()
                return
    push_error("No four-shot solution found")
    quit(1)
