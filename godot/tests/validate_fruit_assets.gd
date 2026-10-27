extends SceneTree
## Checks real imported revised GLBs, their rig hierarchy and all named clips.
const Driver = preload("res://scripts/bun_motion_driver.gd")
var failures: Array[String] = []
var checked := 0

func verify(ok: bool, message: String) -> void:
    checked += 1
    if not ok:
        failures.append(message)
        push_error(message)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    for name in ["berry", "mango"]:
        var model: Node = load("res://assets/" + name + ".glb").instantiate()
        root.add_child(model)
        await process_frame
        var skeleton := Driver.find_skeleton(model)
        var player := Driver.find_player(model)
        verify(skeleton != null and player != null, name + " has a usable rig and animation player")
        if not skeleton or not player:
            model.queue_free()
            continue
        verify(skeleton.get_bone_count() == 11, name + " retains the 11-bone rig")
        var body := skeleton.find_bone("Body")
        verify(body >= 0 and skeleton.get_bone_parent(skeleton.find_bone("Eye.L")) == body and skeleton.get_bone_parent(skeleton.find_bone("Eye.R")) == body, name + " eyes share the animated body")
        for clip in ["idle", "blink", "pull", "release", "impact", "merge", "hop", "escape"]:
            var match_name := ""
            for candidate in player.get_animation_list():
                if candidate == clip or candidate.ends_with("/" + clip):
                    match_name = candidate
                    break
            verify(not match_name.is_empty(), name + " exports " + clip)
            if match_name.is_empty():
                continue
            player.play(match_name)
            var duration := player.get_animation(match_name).length
            for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
                player.seek(duration * fraction, true)
                var pose := skeleton.get_bone_global_pose(body)
                verify(pose.is_finite(), name + " " + clip + " finite at " + str(fraction))
            player.stop()
        model.queue_free()
    await process_frame
    print("FRUIT ASSET RUNTIME ", "PASS" if failures.is_empty() else "FAIL", ": ", checked, " checks; ", failures)
    quit(0 if failures.is_empty() else 1)
