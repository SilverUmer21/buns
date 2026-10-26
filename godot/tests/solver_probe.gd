extends SceneTree
const Solver = preload("res://scripts/bun_solver.gd")

func _initialize() -> void:
    var solver = Solver.new()
    var moves := [
        [1, Vector2(0, 5.4)], [2, Vector2(0, 5.4)],
        [5, Vector2(7.0, 0)], [7, Vector2(-2.0, 11.0)]]
    for move in moves:
        print("SHOT ", move)
        print(solver.shoot(move[0], move[1]))
        for t in range(1000):
            solver.step()
            if not solver.is_moving():
                break
        print("BUNS ", solver.buns, " GATE ", solver.gate_open, " WON ", solver.won)
        solver.events.clear()
    quit()
