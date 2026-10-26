extends Control
var game: Control

func _draw() -> void:
    if not is_instance_valid(game):
        return
    if game.selected_id >= 0:
        var bun: Dictionary = game.solver.find_bun(game.selected_id)
        if not bun.is_empty():
            var center: Vector2 = game.screen_point(bun.position)
            draw_arc(center, 32.0, 0, TAU, 48, Color("fff0aa"), 3.0, true)
            for i in range(game.prediction.size()):
                var point: Vector2 = game.screen_point(game.prediction[i])
                draw_circle(point, maxf(2.0, 4.3 - i * 0.09), Color(1, 0.98, 0.78, 0.90 - i * 0.018), true, -1.0, true)
            if game.pull_amount > 0.04:
                var direction: Vector2 = game.screen_point(bun.position + game.launch_velocity.normalized()) - center
                direction = direction.normalized()
                var tip := center + direction * 48.0
                draw_line(center + direction * 22.0, tip, Color("fff3b0"), 4.0, true)
                draw_colored_polygon(PackedVector2Array([tip + direction * 10, tip - direction * 7 + direction.orthogonal() * 7, tip - direction * 7 - direction.orthogonal() * 7]), Color("fff3b0"))
    for sparkle in game.sparkles:
        var point: Vector2 = game.screen_point(sparkle.position) + sparkle.offset
        var alpha: float = 1.0 - sparkle.age / 0.6
        var radius: float = 6 * alpha
        var color := Color("ffcf46")
        color.a = alpha
        draw_line(point - Vector2(radius, 0), point + Vector2(radius, 0), color, 2.0, true)
        draw_line(point - Vector2(0, radius), point + Vector2(0, radius), color, 2.0, true)
