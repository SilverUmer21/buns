extends SkeletonModifier3D
## Runs after AnimationMixer. One owner for bulk deformation and crest follow-through.
var driver: Node
var body := -1
var crest := -1
var arms: Array[int] = []
var feet: Array[int] = []

func _process_modification() -> void:
    if not is_instance_valid(driver):
        return
    var skeleton := get_skeleton()
    if body < 0:
        body = skeleton.find_bone("Body")
        crest = skeleton.find_bone("Crest")
        for side in ["L", "R"]:
            arms.append(skeleton.find_bone("Arm." + side))
            feet.append(skeleton.find_bone("Foot." + side))
    if body < 0:
        return
    var h: float = clampf(driver.height, 0.72, 1.20)
    var lateral := 1.0 / sqrt(h)
    # Anisotropic sideways jiggle still has determinant 1, keeping the dough
    # solid-looking. Face meshes share this bone, so cheeks/eyes stay attached.
    var sideways: float = exp(driver.squeeze)
    skeleton.set_bone_pose_scale(body, Vector3(lateral * sideways, h, lateral / sideways))
    skeleton.set_bone_pose_rotation(body, Quaternion.from_euler(Vector3(driver.lean.y, 0, -driver.lean.x)))
    if crest >= 0:
        skeleton.set_bone_pose_rotation(crest, Quaternion.from_euler(Vector3(driver.crest.y, 0, -driver.crest.x)))
    # Add a delayed soft layer after the authored limb tracks. SkeletonModifier3D
    # restores the animation base between evaluations, so this does not accumulate.
    for side in range(2):
        var direction := -1.0 if side == 0 else 1.0
        if arms[side] >= 0:
            var base := skeleton.get_bone_pose_rotation(arms[side])
            skeleton.set_bone_pose_rotation(arms[side], base * Quaternion.from_euler(Vector3(driver.limb_swing.y, 0, direction * driver.limb_swing.x)))
        if feet[side] >= 0:
            var base := skeleton.get_bone_pose_rotation(feet[side])
            skeleton.set_bone_pose_rotation(feet[side], base * Quaternion(Vector3.RIGHT, -driver.limb_swing.x * 0.5))
