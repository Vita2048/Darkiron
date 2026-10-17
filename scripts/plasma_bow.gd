@tool
extends Node2D
## Layered, deformable recurve bow. Geometry is shared with the rig's wrist anchors.
var fighter: CharacterBody2D
var hands: Node2D
var atlas: Texture2D
var limb_mesh: ArrayMesh
var mesh_charge := -1.0
# 1.0 keeps the debug-range size; the game hero carries a 25% smaller bow.
@export_range(0.1, 2.0) var visual_scale: float = 1.0
const ORIGIN := Vector2(0,-126)

func aim_angle() -> float:
	return 0.12 + get_parent()._run_angle("bow_cover_angle_degrees") + get_parent().bow_body_transform().get_rotation() if fighter.in_cover else fighter.bow_angle

func left_shoulder() -> Vector2:
	return get_parent().bow_body_transform() * (Vector2(8,-126) + get_parent()._run_vector("bow_left_shoulder_offset")) + get_parent().arm_offset("LeftShoulder")

func right_shoulder() -> Vector2:
	return get_parent().bow_body_transform() * (Vector2(-11,-126) + get_parent()._run_vector("bow_right_shoulder_offset")) + get_parent().arm_offset("RightShoulder")

func left_elbow() -> Vector2:
	var wrist := grip() + Vector2(-6,2).rotated(aim_angle())
	return get_parent().weapon_elbow(left_shoulder(), wrist) + get_parent().arm_offset("LeftForearm")

func right_elbow() -> Vector2:
	if fighter.in_cover:
		return get_parent().weapon_elbow(right_shoulder(), right_hand()) + get_parent().arm_offset("RightForearm")
	return draw_elbow()

func right_hand() -> Vector2:
	return grip()+Vector2(-2,16) if fighter.in_cover else nock()

func grip() -> Vector2:
	if fighter.in_cover: return get_parent().bow_body_transform() * (Vector2(15,-103) + get_parent()._run_vector("bow_grip_offset"))
	# Aim is led by the left hand sweeping around its shoulder.
	return left_shoulder() + Vector2.from_angle(aim_angle())*65 + get_parent()._run_vector("bow_grip_offset")

func draw_elbow() -> Vector2:
	# Anatomical draw: upper arm rotates backwards continuously as energy rises.
	var angle: float = lerpf(0.85,3.05,fighter.bow_charge)+aim_angle()+get_parent()._run_angle("bow_draw_elbow_degrees")
	return right_shoulder()+Vector2.from_angle(angle)*33 + get_parent().arm_offset("RightForearm")

func nock() -> Vector2:
	if fighter.in_cover: return grip()-Vector2.from_angle(aim_angle())*25
	# Intersect the arrow line with a fixed-length forearm around the elbow.
	var axis := Vector2.from_angle(aim_angle())
	var delta := draw_elbow()-grip()
	var along := delta.dot(axis)
	var perpendicular := delta.dot(Vector2(-axis.y,axis.x))
	return grip()+axis*(along+sqrt(maxf(0,44*44-perpendicular*perpendicular)))

func _ready() -> void:
	atlas = load("res://assets/plasma-bow-hybrid.png")
	z_index = 60
	hands = Node2D.new()
	hands.z_index = 20
	hands.draw.connect(_draw_hands)
	add_child(hands)

func _process(_dt: float) -> void:
	# Debug ranges keep the bow permanent; the game hero only shows his drawn bow.
	visible = fighter.health > 0 and not fighter.climbing
	if get_parent().has_method("armed_with_bow"):
		visible = visible and get_parent().armed_with_bow()
	queue_redraw()
	hands.queue_redraw()

func limb_point(t: float, side: float) -> Vector2:
	return Vector2(-10.7+limb_bend(t),side*(20+67*t-8*fighter.bow_charge*t*t))

func limb_bend(t: float) -> float:
	# A strung bow is already curved at rest; drawing adds further flex.
	return 7*sin(PI*t)-23*t*t-22*fighter.bow_charge*t*t

func rebuild_limb() -> void:
	if is_equal_approx(mesh_charge,fighter.bow_charge): return
	mesh_charge = fighter.bow_charge
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in 49:
		var t := i/48.0
		for x in [240.0,430.0]:
			vertices.append(Vector3((x-310)*0.10-10+limb_bend(t),-20-67*t+8*mesh_charge*t*t,0))
			uv.append(Vector2(x/1280.0,(1238-1224*t)/1280.0))
		if i < 48:
			var k := i*2
			indices.append_array(PackedInt32Array([k,k+1,k+2,k+1,k+3,k+2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	limb_mesh = ArrayMesh.new()
	limb_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)

func _draw() -> void:
	draw_set_transform(grip(),aim_angle(),Vector2.ONE*visual_scale)
	rebuild_limb()
	for side in [1.0,-1.0]:
		draw_set_transform(grip(),aim_angle(),Vector2(visual_scale,side*visual_scale))
		draw_mesh(limb_mesh,atlas)
	draw_set_transform(grip(),aim_angle(),Vector2.ONE*visual_scale)
	draw_texture_rect_region(atlas,Rect2(-12.6,-24.5,22.4,49),Rect2(825,260,225,850))
	# Scale the raster limbs and riser, preserving the authored hand/arrow pose.
	var pull := (nock()-grip()).rotated(-aim_angle()) / visual_scale
	var string := PackedVector2Array([limb_point(1,-1),pull,limb_point(1,1)])
	draw_polyline(string,Color(0.1,0.65,1,0.13),4,true)
	draw_polyline(string,Color("a3eaff"),1,true)
	if fighter.in_cover:
		draw_set_transform(Vector2.ZERO)
		return
	draw_set_transform(grip(),aim_angle())
	pull = (nock()-grip()).rotated(-aim_angle())
	# Nocked arrow runs directly through the drawing fingers, above the torso.
	var tip := pull+Vector2(110,0)
	draw_line(pull,tip-Vector2(12,0),Color("7c9eaf"),2,true)
	draw_line(pull,tip-Vector2(12,0),Color("d4e8f1"),0.6,true)
	preload("res://scripts/arrow_feathers.gd").draw_feathers(self,pull)
	var world_glow: Texture2D = fighter.world.get("glow") if fighter.world != null else null
	if world_glow:
		draw_texture_rect(world_glow,Rect2(tip-Vector2(27,24),Vector2(48,48)),false)
	draw_colored_polygon(PackedVector2Array([tip+Vector2(3,0),tip+Vector2(-14,-5),tip+Vector2(-10,0),tip+Vector2(-14,5)]),Color("85eaff"))
	draw_line(tip-Vector2(11,0),tip+Vector2(2,0),Color.WHITE,1.5,true)
	draw_set_transform(Vector2.ZERO)

func _grip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101723")
	style.border_color = Color("7592a6")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style

func _draw_hands() -> void:
	for anchor in [grip(),right_hand()]:
		hands.draw_set_transform(anchor,aim_angle())
		# Closed gauntlet, with fingers curled around the riser / pinching the string.
		var outline := PackedVector2Array([Vector2(-9,-5),Vector2(-3,-8),Vector2(4,-6),Vector2(5,4),Vector2(0,8),Vector2(-8,5)])
		hands.draw_colored_polygon(outline,Color("0b121c"))
		hands.draw_polyline(outline,Color("668194"),1,true)
		for y in [-4,0,4]:
			hands.draw_line(Vector2(-4,y),Vector2(3,y+1),Color("738a99"),2.3,true)
			hands.draw_line(Vector2(-4,y+1),Vector2(2,y+2),Color("1b2939"),1,true)
		hands.draw_line(Vector2(-8,-3),Vector2(-2,3),Color("c1905d"),2,true)
		hands.draw_set_transform(Vector2.ZERO)
