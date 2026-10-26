extends RefCounted
## Gameplay coordinates are X / forward; height belongs only to the art.

static func big_escape() -> Dictionary:
    return {
        "title": "The big escape", "required_tier": 3,
        "bounds": Rect2(-3.28, -5.10, 6.56, 10.20),
        "gate_y": 3.45, "gate_half_depth": 0.26,
        "exit": Vector2(0, 4.43), "exit_radius": 0.88,
        "spawns": [
            {"tier": 1, "position": Vector2(-1.48, -3.15)},
            {"tier": 1, "position": Vector2(1.48, -3.15)},
            {"tier": 1, "position": Vector2(-1.48, -0.70)},
            {"tier": 1, "position": Vector2(1.48, -0.70)}],
        "bumpers": [{"position": Vector2(0, 1.38), "radius": 0.72}]
    }
