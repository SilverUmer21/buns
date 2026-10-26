extends SkeletonModifier3D
## Runs after AnimationMixer. One owner for bulk deformation and crest follow-through.
var driver: Node
var body := -1
var crest := -1

func _process_modification() -> void:
    if not is_instance_valid(driver):
        return
    var skeleton := get_skeleton()
    if body < 0:
        body = skeleton.find_bone("Body")
        crest = skeleton.find_bone("Crest")
    if body < 0:
        return
    var h: float = clampf(driver.height, 0.72, 1.20)
    var lateral := 1.0 / sqrt(h)
    skeleton.set_bone_pose_scale(body, Vector3(lateral, h, lateral))
    skeleton.set_bone_pose_rotation(body, Quaternion.from_euler(Vector3(driver.lean.y, 0, -driver.lean.x)))
    if crest >= 0:
        skeleton.set_bone_pose_rotation(crest, Quaternion.from_euler(Vector3(driver.crest.y, 0, -driver.crest.x)))
