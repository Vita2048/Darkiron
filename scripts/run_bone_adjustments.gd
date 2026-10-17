@tool
extends Skeleton2D
## Pose bones carry the procedural transform; their children are authored offsets.
## Never write an editable bone's transform here: editor gizmos and AnimationPlayer own it.
const PARENTS := {
	"Hip": "", "Torso": "Hip", "Head": "Torso",
	"LeftShoulder": "Torso", "LeftForearm": "LeftShoulder", "LeftHand": "LeftForearm",
	"RightShoulder": "Torso", "RightForearm": "RightShoulder", "RightHand": "RightForearm",
	"Weapon": "Torso", "LeftThigh": "Hip", "LeftShin": "LeftThigh", "LeftFoot": "LeftShin",
	"RightThigh": "Hip", "RightShin": "RightThigh", "RightFoot": "RightShin",
}
var bones: Dictionary = {}
var poses: Dictionary = {}
var base_transforms: Dictionary = {}
var final_transforms: Dictionary = {}

func _ready() -> void:
	for bone_name in PARENTS:
		bones[bone_name] = find_child(bone_name, true, false)
		poses[bone_name] = bones[bone_name].get_parent()

func apply_parts(records: Array, hip: Vector2, weight: float) -> void:
	if bones.is_empty(): return
	var base := {"Hip": Transform2D(0, hip)}
	var assignments: Array = []
	var counts := {}
	for record in records:
		var index: int = record.index
		var count: int = counts.get(index, 0)
		counts[index] = count + 1
		var bone_name := ""
		match index:
			0: bone_name = "Head"
			1: bone_name = "Torso"
			2:
				if count == 0: bone_name = "Weapon"
			3: bone_name = "LeftShoulder" if count == 0 else "RightShoulder"
			4: bone_name = "LeftForearm" if count == 0 else "RightForearm"
			6: bone_name = "LeftThigh" if count == 0 else "RightThigh"
			7: bone_name = "LeftShin" if count == 0 else "RightShin"
			8: bone_name = "LeftFoot" if count == 0 else "RightFoot"
			13: bone_name = "RightHand"
			14: bone_name = "LeftHand"
		if bone_name.is_empty(): continue
		var origin: Vector2 = record.at
		if index == 8:
			# The boot artwork has an offset from its ankle pivot.
			origin -= Vector2(5, -8).rotated(record.angle)
		base[bone_name] = Transform2D(record.angle, origin)
		assignments.append([record.node, bone_name, record.transform])
	base_transforms = base
	final_transforms = {}
	for bone_name in PARENTS:
		var parent_name: String = PARENTS[bone_name]
		var parent_base: Transform2D = base.get(parent_name, Transform2D.IDENTITY)
		var current_base: Transform2D = base.get(bone_name, parent_base)
		var local_pose := parent_base.affine_inverse() * current_base
		poses[bone_name].transform = local_pose
		var bone: Bone2D = bones[bone_name]
		var adjustment := Transform2D(
			bone.rotation * weight, Vector2.ONE.lerp(bone.scale, weight),
			bone.skew * weight, bone.position * weight)
		var parent_final: Transform2D = final_transforms.get(parent_name, Transform2D.IDENTITY)
		final_transforms[bone_name] = parent_final * local_pose * adjustment
	# Use the exact same retained artwork, dimensions, color and draw ordering.
	# Only the final transform changes; no IK runs after this step.
	for assignment in assignments:
		var bone_name: String = assignment[1]
		var delta: Transform2D = final_transforms[bone_name] * base[bone_name].affine_inverse()
		assignment[0].transform = delta * assignment[2]
