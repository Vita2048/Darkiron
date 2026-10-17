@tool
extends "res://scripts/rig.gd"
## Hero rig: carries the plasma bow in place of the rifle while all body states
## (walk/run/crouch climb death) still come from the shared procedural rig.
var drawing_bow_arms := false
var bow: Node2D

func arm_offset(bone_name: String) -> Vector2:
	if run_bone_layer == null or run_edit_weight == 0: return Vector2.ZERO
	return run_bone_layer.bones[bone_name].position * run_edit_weight

func _sync_arm_handle(bone_name: String, at: Vector2, end: Vector2) -> void:
	if run_bone_layer == null: return
	var bone: Bone2D = run_bone_layer.bones[bone_name]
	var pose: Bone2D = run_bone_layer.poses[bone_name]
	var parent_transform: Transform2D = run_bone_layer.global_transform.affine_inverse() * pose.get_parent().global_transform
	pose.transform = parent_transform.affine_inverse() * Transform2D(0, at) * bone.transform.affine_inverse()
	bone.length = at.distance_to(end)
	bone.bone_angle = (end - at).angle()

func bow_body_transform() -> Transform2D:
	var result := Transform2D.IDENTITY
	if run_bone_layer != null and run_edit_weight > 0 and run_bone_layer.base_transforms.has("Torso"):
		var hip: Transform2D = run_bone_layer.base_transforms.Hip
		var torso: Transform2D = run_bone_layer.base_transforms.Torso
		result = hip * run_bone_layer.bones.Hip.transform * hip.affine_inverse() * torso * run_bone_layer.bones.Torso.transform * torso.affine_inverse()
	result.origin += _run_vector("hip_offset") + _run_vector("torso_offset")
	return result

func _ready() -> void:
	super._ready()
	if not fighter.enemy:
		bow = preload("res://scripts/plasma_bow.gd").new()
		bow.fighter = fighter
		bow.visual_scale = 0.75
		add_child(bow)

func _edit_state() -> String:
	if armed_with_bow():
		return "bow_cover" if fighter.in_cover else "bow_draw"
	return super._edit_state()

func _update_run_edits(dt: float = 0.0) -> void:
	super._update_run_edits(dt)
	if run_edit_player != null and edit_clip == "bow_draw":
		run_edit_player.seek(clampf(fighter.bow_charge, 0, 1) * run_edit_player.get_animation("bow_draw").length, true)

func armed_with_bow() -> bool:
	return not fighter.enemy and not editor_preview \
		and fighter.weapon_kind == "BOW" and fighter.weapon_blend >= 0.5 \
		and fighter.health > 0 and not fighter.climbing

func part(index: int, at: Vector2, size: Vector2, angle := 0.0, tint := Color.WHITE) -> void:
	if not fighter.enemy and fighter.weapon_kind == "BOW" and index in [2,9,10,11]: return
	if armed_with_bow():
		if not drawing_bow_arms and index in [3,4,13,14]: return
	super.part(index, at, size, angle, tint)
	if drawing_bow_arms: parts[part_cursor-1].z_index = 1

func _slung_bow_visible() -> bool:
	# Sheathed bow rides the back instead of the slung rifle.
	return not fighter.enemy and not editor_preview \
		and fighter.weapon_kind == "BOW" and fighter.health > 0 \
		and (fighter.climbing or fighter.weapon_blend < 0.5)

# Static limb string: the held bow's limb mesh baked with zero draw, textured
# straight from the plasma-bow-hybrid.png raster limb strip.
var slung_mesh: ArrayMesh
func _build_slung_mesh() -> void:
	if slung_mesh != null:
		return
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in 49:
		var t := i/48.0
		# Curving as it would sit idle in the hand (no draw flex).
		var bend := 7.0*sin(PI*t)-23.0*t*t
		for x in [240.0,430.0]:
			vertices.append(Vector3((x-310)*0.10-10+bend,-20-67*t,0))
			uv.append(Vector2(x/1280.0,(1238-1224*t)/1280.0))
		if i < 48:
			var k := i*2
			indices.append_array(PackedInt32Array([k,k+1,k+2,k+1,k+3,k+2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	slung_mesh = ArrayMesh.new()
	slung_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)

func _draw_slung_bow() -> void:
	# Mirrors the base rig's slung rifle anchor; drawn with the rig's own item,
	# so it renders behind every body part like the holstered weapon does.
	var atlas: Texture2D = preload("res://assets/plasma-bow-hybrid.png")
	_build_slung_mesh()
	# Follow the rendered torso, including authored locomotion and climb keys.
	var body := Transform2D.IDENTITY
	for record in run_bone_records:
		if record.index == 1:
			body = Transform2D(record.node.rotation, record.node.position)
			break
	var back := body * Vector2(-20,18)
	var angle := body.get_rotation() + 0.30
	for side in [1.0,-1.0]:
		draw_set_transform(back,angle,Vector2(0.75,side*0.75))
		draw_mesh(slung_mesh,atlas)
	draw_set_transform(back,angle,Vector2(0.75,0.75))
	# The riser/grip raster art sits between the two limbs.
	draw_texture_rect_region(atlas,Rect2(-12.6,-24.5,22.4,49),Rect2(825,260,225,850))
	# Idle string closes the drawn silhouette.
	var top := Vector2(-33.7,-87)
	var bottom := Vector2(-33.7,87)
	draw_polyline(PackedVector2Array([top,bottom]),Color(0.1,0.65,1,0.16),4,true)
	draw_polyline(PackedVector2Array([top,bottom]),Color("a3eaff"),1,true)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	super._draw()
	if editor_preview or Engine.is_editor_hint(): return
	if _slung_bow_visible():
		_draw_slung_bow()
		return
	if not armed_with_bow():
		return
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
