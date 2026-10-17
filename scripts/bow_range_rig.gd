@tool
extends "res://scripts/rig.gd"
var drawing_bow_arms := false
var bow: Node2D

func arm_offset(bone_name: String) -> Vector2:
	if run_bone_layer == null or run_edit_weight == 0: return Vector2.ZERO
	return run_bone_layer.bones[bone_name].position * run_edit_weight

func _sync_arm_handle(bone_name: String, at: Vector2, end: Vector2) -> void:
	if run_bone_layer == null: return
	var bone: Bone2D = run_bone_layer.bones[bone_name]
	var pose: Bone2D = run_bone_layer.poses[bone_name]
	# Position keys use character-facing axes, even when the torso is rotated.
	# Only the locked procedural parent changes; never overwrite keyed transforms.
	var parent_transform: Transform2D = run_bone_layer.global_transform.affine_inverse() * pose.get_parent().global_transform
	pose.transform = parent_transform.affine_inverse() * Transform2D(0, at) * bone.transform.affine_inverse()
	bone.length = at.distance_to(end)
	bone.bone_angle = (end - at).angle()

func _ready() -> void:
	super._ready()
	if not fighter.enemy:
		bow = preload("res://scripts/plasma_bow.gd").new()
		bow.fighter = fighter
		add_child(bow)

func _edit_state() -> String:
	if fighter.health <= 0: return "death"
	return "bow_cover" if fighter.in_cover else "bow_draw"

func _update_run_edits(dt: float = 0.0) -> void:
	super._update_run_edits(dt)
	if run_edit_player != null and edit_clip == "bow_draw":
		run_edit_player.seek(clampf(fighter.bow_charge, 0, 1) * run_edit_player.get_animation("bow_draw").length, true)

func bow_body_transform() -> Transform2D:
	var result := Transform2D.IDENTITY
	if run_bone_layer != null and run_edit_weight > 0 and run_bone_layer.base_transforms.has("Torso"):
		# Read the current keyed transforms, including input updates before drawing.
		var hip: Transform2D = run_bone_layer.base_transforms.Hip
		var torso: Transform2D = run_bone_layer.base_transforms.Torso
		result = hip * run_bone_layer.bones.Hip.transform * hip.affine_inverse() * torso * run_bone_layer.bones.Torso.transform * torso.affine_inverse()
	result.origin += _run_vector("hip_offset") + _run_vector("torso_offset")
	return result

func part(index: int, at: Vector2, size: Vector2, angle := 0.0, tint := Color.WHITE) -> void:
	if index in [2,9,10,11]: return
	if not fighter.enemy and not drawing_bow_arms and index in [3,4,13,14]: return
	super.part(index, at, size, angle, tint)
	# Far arm stays behind the torso; the near arm is raised explicitly below.
	if drawing_bow_arms: parts[part_cursor-1].z_index = 1

func _draw() -> void:
	super._draw()
	if fighter.enemy or fighter.health <= 0 or not is_instance_valid(bow): return
	drawing_bow_arms = true
	# The extended left arm ends at the riser, not beyond it.
	var shoulder: Vector2 = bow.left_shoulder()
	var wrist: Vector2 = bow.grip()+Vector2(-6,2).rotated(bow.aim_angle())
	var elbow: Vector2 = bow.left_elbow()
	_sync_arm_handle("LeftShoulder", shoulder, elbow)
	_sync_arm_handle("LeftForearm", elbow, wrist)
	segment(3,shoulder,elbow,25,Color(0.75,0.83,0.9))
	segment(4,elbow,wrist,18,Color(0.75,0.83,0.9),false)
	# Near right arm draws back; string overlays chest but passes behind fingers.
	shoulder = bow.right_shoulder()
	wrist = bow.right_hand()
	elbow = bow.right_elbow()
	_sync_arm_handle("RightShoulder", shoulder, elbow)
	_sync_arm_handle("RightForearm", elbow, wrist)
	var first := part_cursor
	segment(3,shoulder,elbow,27)
	segment(4,elbow,wrist,19,Color.WHITE,false)
	for i in range(first,part_cursor): parts[i].z_index = 70
	drawing_bow_arms = false
