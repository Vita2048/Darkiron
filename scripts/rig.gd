@tool
extends Node2D

var editor_preview := false
var preview_grounded := false
var run_controls: Node2D
var run_edit_player: AnimationPlayer
var run_edit_weight := 0.0
var run_bone_records: Array = []
var run_bone_layer: Skeleton2D

func _grounded() -> bool:
	return (editor_preview and preview_grounded) or fighter.is_on_floor()

func _run_vector(property: String) -> Vector2:
	return Vector2.ZERO if run_controls == null or run_edit_weight == 0.0 else (run_controls.get(property) as Vector2) * run_edit_weight

func _run_angle(property: String) -> float:
	return 0.0 if run_controls == null or run_edit_weight == 0.0 else deg_to_rad(float(run_controls.get(property))) * run_edit_weight

func _update_run_edits() -> void:
	run_edit_weight = 0.0
	if run_edit_player == null: return
	if fighter.health > 0 and _grounded() and not fighter.climbing and not fighter.crouching and not fighter.in_cover:
		run_edit_weight = run_weight * move_weight * (1.0 - fighter.weapon_blend)
		if run_edit_weight > 0.0 and run_edit_player.has_animation("run_sheathed"):
			var clip := run_edit_player.get_animation("run_sheathed")
			run_edit_player.seek(_gait_phase() * clip.length, true)
	elif fighter.health > 0 and fighter.climbing:
		run_edit_weight = 1.0 - fighter.weapon_blend
		if run_edit_weight > 0.0:
			var anim_name := "climb_sheathed" if run_edit_player.has_animation("climb_sheathed") else "climb"
			if run_edit_player.has_animation(anim_name):
				var clip := run_edit_player.get_animation(anim_name)
				run_edit_player.seek(_gait_phase() * clip.length, true)

var cover_pose: Node2D
var cover_player: AnimationPlayer

# Native authored scene: no procedural bone writes while editing.
const SkeletonCharacter = preload("res://characters/darkiron.tscn")
var skeleton_character: Node2D
var skeleton_animation: AnimationPlayer
var skeleton_active := false
var procedural_override := false
var cover_time := 0.0
var skel_clip := ""
var air_time := 0.0
var crouch_time := 0.0
var crouch_active := false
var cover_active := false
var skeleton_weapon: Node2D
# Clip resources are authoritative. Locomotion remains distance-driven so
# changing speed or direction does not slide planted feet.
func _clip_length(state: String) -> float:
	return skeleton_animation.get_animation(state).length

# Cover and crouch are enter / hold-at-midpoint / exit timelines.
func _held_clip_time(time: float, held: bool, dt: float, length: float) -> float:
	var midpoint := length * 0.5
	if held:
		if time > midpoint:
			time = length - time
		return minf(midpoint, time + dt)
	if time < midpoint:
		time = length - time
	return minf(length, time + dt)

func _ready() -> void:
	if editor_preview or Engine.is_editor_hint():
		return
	if not fighter.enemy and not fighter.drake and not fighter.azure:
		var edit_scene: Node = load("res://characters/run_sheathed.tscn").instantiate()
		run_controls = edit_scene.get_node("Controls")
		edit_scene.remove_child(run_controls)
		edit_scene.free()
		add_child(run_controls)
		run_bone_layer = run_controls.get_node_or_null("Skeleton2D")
		run_edit_player = run_controls.get_node("AnimationPlayer")
		run_edit_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		run_edit_player.play("run_sheathed")
		run_edit_player.advance(0)
		if skeleton_character == null:
			skeleton_character = SkeletonCharacter.instantiate()
			add_child(skeleton_character)
		else:
			skeleton_character.reparent(self, false)
		skeleton_character.position = Vector2.ZERO
		skeleton_character.process_mode = Node.PROCESS_MODE_INHERIT
		skeleton_animation = skeleton_character.get_node("AnimationPlayer")
		skeleton_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		skeleton_weapon = skeleton_character.get_node_or_null("Skeleton2D/Hip/Torso/RightShoulder/RightForearm/RightHand/Weapon") as Node2D
		skeleton_character.hide()
		_clean_skeleton(skeleton_character)

func _clean_skeleton(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if node is Polygon2D:
		(node as Polygon2D).antialiased = true
	for child in node.get_children():
		_clean_skeleton(child)

func _gait_phase() -> float:
	return fposmod(fighter.gait, TAU) / TAU

func _skeleton_state() -> String:
	if fighter.climbing:
		return "climb"
	if not _grounded():
		return "air"
	if cover_active:
		return "cover"
	if crouch_active:
		return "crouch"
	if absf(fighter.velocity.x) > 12:
		return "run" if fighter.running else "walk"
	return "idle"

func _enter_skeleton_state(state: String) -> void:
	skel_clip = state
	air_time = 0.0
	skeleton_animation.play(state)
	skeleton_animation.advance(0)

func _update_skeleton(dt: float) -> void:
	if skeleton_character == null:
		return
	if procedural_override:
		skeleton_active = false
		skeleton_character.hide()
		skel_clip = ""
		return
	if fighter.health <= 0 or fighter.weapon_blend < 0.999 or fighter.climbing:
		skeleton_active = false
		skeleton_character.hide()
		skel_clip = ""
		cover_active = false
		crouch_active = false
		cover_time = 0.0
		crouch_time = 0.0
		return
	var cover_length := _clip_length("cover")
	if fighter.in_cover or cover_active:
		cover_time = _held_clip_time(cover_time, fighter.in_cover, dt, cover_length)
		cover_active = fighter.in_cover or cover_time < cover_length
	var crouch_length := _clip_length("crouch")
	var crouch_held: bool = fighter.crouching and _grounded()
	if crouch_held or crouch_active:
		crouch_time = _held_clip_time(crouch_time, crouch_held, dt, crouch_length)
		crouch_active = crouch_held or crouch_time < crouch_length
	var state := _skeleton_state()
	if state != skel_clip:
		_enter_skeleton_state(state)
	var time := 0.0
	match state:
		"idle": time = fposmod(clock, _clip_length("idle"))
		"walk": time = _gait_phase() * _clip_length("walk")
		"run": time = _gait_phase() * _clip_length("run")
		"climb": time = _gait_phase() * _clip_length("climb")
		"air":
			air_time = minf(air_time + dt, _clip_length("air"))
			time = air_time
		"crouch": time = crouch_time
		"cover": time = cover_time
	skeleton_animation.seek(time, true)
	skeleton_active = true
	skeleton_character.show()

var fighter: CharacterBody2D
const Armor = preload("res://scripts/vector_armor.gd")
const VectorPart = preload("res://scripts/vector_part.gd")
var parts: Array[Node2D] = []
var part_cursor := 0
var clock := 0.0
var run_weight := 0.0
var cover_weight := 0.0
var stand_weight := 1.0
var move_weight := 0.0

func _process(dt: float) -> void:
	if editor_preview or Engine.is_editor_hint():
		if is_instance_valid(fighter):
			queue_redraw()
		return
	visible = fighter.position.x > fighter.world.camera_x-180 and fighter.position.x < fighter.world.camera_x+1620
	if not visible or fighter.world.paused:
		return
	clock += dt
	run_weight = move_toward(run_weight, 1.0 if fighter.running and _grounded() and fighter.health > 0 else 0.0, dt * 7)
	cover_weight = move_toward(cover_weight, 1.0 if fighter.in_cover else 0.0, dt * 9)
	var standing: bool = _grounded() and absf(fighter.velocity.x) < 12 and not fighter.climbing and not fighter.crouching and not fighter.in_cover and fighter.health > 0
	stand_weight = move_toward(stand_weight, 1.0 if standing else 0.0, dt * 8)
	var locomotion: bool = _grounded() and not fighter.climbing and not fighter.crouching and not fighter.in_cover and fighter.health > 0
	move_weight = move_toward(move_weight, 1.0 if locomotion and absf(fighter.velocity.x)>12 else 0.0, dt*8)
	_update_skeleton(dt)
	_update_run_edits()
	queue_redraw()

func part(index: int, at: Vector2, size: Vector2, angle := 0.0, tint := Color.WHITE) -> void:
	if part_cursor == parts.size():
		var node := VectorPart.new()
		add_child(node)
		parts.append(node)
	var node := parts[part_cursor]
	node.configure(index,fighter.drake,not fighter.enemy,(fighter.hybrid_body and not fighter.enemy) or fighter.azure,fighter.azure)
	node.position = at
	node.rotation = angle
	node.skew = 0.0
	# Keep limb lengths and joint positions stable while balancing the silhouette.
	var breadth := 1.0
	match index:
		0: breadth = 0.80
		1: breadth = 0.80
		3: breadth = 0.83
		4: breadth = 1.18
		6: breadth = 0.87
		7: breadth = 0.90
	if (not fighter.enemy or fighter.azure) and index==0: breadth = 1.0
	if fighter.drake:
		match index:
			0: breadth = 1.0
			1: breadth = 1.18
			3: breadth = 1.30
			4: breadth = 1.15
			6: breadth = 1.18
			7: breadth = 1.18
			8: breadth = 1.0
	node.scale = size*Vector2(breadth,1.0)/100.0
	node.modulate = tint
	node.z_index = part_cursor
	node.visible = true
	if run_bone_layer != null and run_edit_weight > 0.0:
		run_bone_records.append({"index": index, "at": at, "angle": angle, "transform": node.transform, "node": node})
	part_cursor += 1

func segment(index: int, a: Vector2, b: Vector2, width: float, tint := Color.WHITE,glove := true) -> void:
	var hybrid: bool = fighter.drake or fighter.azure or (not fighter.enemy and fighter.hybrid_body)
	var length := a.distance_to(b)
	var angle := (b-a).angle()-PI/2
	part(index,a,Vector2(width,length if hybrid and index in [3,4,6,7] else length+7),angle,tint)
	if hybrid and index==4 and glove:
		part(13,b,Vector2(12,16),angle,tint)

func knee(hip: Vector2, foot: Vector2, bend: float) -> Vector2:
	var delta := foot - hip
	var distance := minf(delta.length(), 79.5)
	var mid := (hip + foot) * 0.5
	return mid + Vector2(delta.y, -delta.x).normalized() * sqrt(maxf(0, 40*40-distance*distance/4)) * bend

func leg(hip: Vector2, foot: Vector2, tint: Color) -> void:
	var k := knee(hip, foot, 1)
	segment(6, hip, k, 29, tint)
	segment(7, k, foot, 24, tint)
	part(8, foot + (Vector2(5,-8) if fighter.drake or fighter.azure or (not fighter.enemy and fighter.hybrid_body) else Vector2(8,-9)), Vector2(34,19), 0, tint)

# Adapted from Prince PS.stand / skeleton: explicit mild leg angles and hip
# height derived from their vertical reach, not a lowered hip with bent IK knees.
func standing_points(front_leg: bool) -> Array[Vector2]:
	var a := deg_to_rad(3.0 if front_leg else 0.0)
	var b := deg_to_rad(0.0 if front_leg else -1.0)
	var root := Vector2.ZERO
	var k := root + Vector2(sin(a),cos(a))*40
	var ankle := k + Vector2(sin(b),cos(b))*40
	if (not fighter.enemy or fighter.azure) and not front_leg:
		root.x += 10.0
		k.x += 10.0
		ankle.x += 6.0
	return [root,k,ankle]

func standing_height() -> float:
	return maxf(standing_points(true)[2].y,standing_points(false)[2].y)+10.0

func grounded_leg(hip: Vector2,foot: Vector2,front_leg: bool,tint: Color) -> void:
	var standing := standing_points(front_leg)
	var base := Vector2(-4,-standing_height())
	var root := hip.lerp(base+standing[0],stand_weight)
	var k := knee(hip,foot,1).lerp(base+standing[1],stand_weight)
	var ankle := foot.lerp(base+standing[2],stand_weight)
	if run_edit_weight > 0.0:
		ankle += _run_vector("front_foot_offset" if front_leg else "back_foot_offset")
		k = knee(root, ankle, 1)
	segment(6,root,k,38 if front_leg else 33,tint)
	segment(7,k,ankle,31 if front_leg else 27,tint)
	var toe := _run_angle("front_foot_pitch_degrees" if front_leg else "back_foot_pitch_degrees")
	part(8,ankle+(Vector2(5,-8) if fighter.drake or fighter.azure or (not fighter.enemy and fighter.hybrid_body) else Vector2(8,-9)).rotated(toe),Vector2(34,19),toe,tint)

# Contact, weight-bearing, push-off, heel recovery, knee drive, extension.
# Explicit joint poses keep the rear knee folded instead of bicycling both feet.
func run_angles(phase: float) -> Vector2:
	# The first four keys are the extended weight-bearing leg, the last four
	# recover the heel and drive the knee. Both knees no longer stay compressed.
	return sample_angles([Vector2(38,35),Vector2(12,8),Vector2(-12,-18),Vector2(-35,-38),Vector2(-45,-105),Vector2(-10,-150),Vector2(55,-75),Vector2(55,5)],phase)

func walk_angles(phase: float) -> Vector2:
	return sample_angles([Vector2(25,23),Vector2(14,12),Vector2(0,-2),Vector2(-13,-16),Vector2(-25,-29),Vector2(-6,-68),Vector2(24,-58),Vector2(33,-10)],phase)

func sample_angles(keys: Array,phase: float) -> Vector2:
	var frame := fposmod(phase / TAU, 1.0) * keys.size()
	var index := int(frame)
	# Prince-style periodic cubic interpolation avoids stopping at every pose key.
	var weight := frame-index
	var pose: Vector2 = keys[index].cubic_interpolate(keys[(index+1)%keys.size()],keys[(index+keys.size()-1)%keys.size()],keys[(index+2)%keys.size()],weight)
	return pose * PI / 180.0

func gait_angles(phase: float,front_leg: bool) -> Vector2:
	var rest := Vector2(3,0) if front_leg else Vector2(0,-1)
	return (rest*PI/180.0).lerp(walk_angles(phase).lerp(run_angles(phase),run_weight),move_weight)

# Foot pitch is authored separately from the shin: heel contact, flat support,
# toe-off, then relaxed recovery. Rotate around the ankle, never the boot corner.
func foot_angle(phase: float) -> float:
	var walk := sample_angles([Vector2(-8,0),Vector2(0,0),Vector2(0,0),Vector2(12,0),Vector2(30,0),Vector2(18,0),Vector2(2,0),Vector2(-8,0)],phase).x
	var run := sample_angles([Vector2(-10,0),Vector2(0,0),Vector2(10,0),Vector2(30,0),Vector2(65,0),Vector2(75,0),Vector2(20,0),Vector2(-10,0)],phase).x
	return lerpf(walk,run,run_weight)*move_weight

func sole_depth(angle: float) -> float:
	var depth := -100.0
	for point in [Vector2(-46,83),Vector2(44,83),Vector2(41,95),Vector2(-39,100),Vector2(-46,94)]:
		var local: Vector2 = point*Vector2(0.34,0.19)-Vector2(-5,8)
		depth = maxf(depth,local.rotated(angle).y)
	return depth

func flight_height(phase: float) -> float:
	var half_phase := fposmod(phase/TAU,0.5)
	var t := clampf((half_phase-0.31)/0.19,0,1)
	return sin(t*PI)*sin(t*PI)*17*run_weight*move_weight

const WALK_DISTANCE_PER_RADIAN := 18.0
const WALK_CONTACT := 0.55
const RUN_DISTANCE_PER_RADIAN := 24.5
const RUN_CONTACT := 0.31

func run_ankle(phase: float) -> Vector2:
	var t := fposmod(phase/TAU,1.0)
	var release_x := 30.0-RUN_CONTACT*TAU*RUN_DISTANCE_PER_RADIAN
	if t <= RUN_CONTACT:
		# Exactly cancel actual forward travel throughout the flat planted phase.
		return Vector2(30.0-t*TAU*RUN_DISTANCE_PER_RADIAN,-11)
	var times := [RUN_CONTACT,0.50,0.68,0.85,1.0]
	var keys := [Vector2(release_x,-11),Vector2(-43,-50),Vector2(-2,-67),Vector2(42,-32),Vector2(30,-11)]
	for i in 4:
		if t <= times[i+1]:
			var weight: float = (t-times[i])/(times[i+1]-times[i])
			return keys[i].lerp(keys[i+1],smoothstep(0,1,weight))+Vector2(0,-sin((t-RUN_CONTACT)/(1.0-RUN_CONTACT)*PI)*12)
	return keys[4]

func run_foot_angle(phase: float) -> float:
	var t := fposmod(phase/TAU,1.0)
	if t <= RUN_CONTACT:
		return 0
	return sample_angles([Vector2(0,0),Vector2(0,0),Vector2(0,0),Vector2(35,0),Vector2(65,0),Vector2(60,0),Vector2(15,0),Vector2(-8,0)],phase).x * smoothstep(RUN_CONTACT,0.40,t) * (1.0-smoothstep(0.90,1.0,t))

func run_pelvis_height(phase: float) -> float:
	var t := fposmod(phase/TAU,0.5)
	if t <= RUN_CONTACT:
		var x := 30.0-t*TAU*RUN_DISTANCE_PER_RADIAN
		return sqrt(79.0*79.0-x*x)+11.0-sin(t/RUN_CONTACT*PI)*7.0
	var end_x := 30.0-RUN_CONTACT*TAU*RUN_DISTANCE_PER_RADIAN
	var start := sqrt(79.0*79.0-end_x*end_x)+11.0
	var finish := sqrt(79.0*79.0-30.0*30.0)+11.0
	var u := (t-RUN_CONTACT)/(0.5-RUN_CONTACT)
	return lerpf(start,finish,smoothstep(0,1,u))+sin(u*PI)*9

func walk_ankle(phase: float) -> Vector2:
	var t := fposmod(phase/TAU,1.0)
	var release := 28.0-WALK_CONTACT*TAU*WALK_DISTANCE_PER_RADIAN
	if t <= WALK_CONTACT:
		return Vector2(28.0-t*TAU*WALK_DISTANCE_PER_RADIAN,-11)
	var u := (t-WALK_CONTACT)/(1.0-WALK_CONTACT)
	return Vector2(lerpf(release,28.0,smoothstep(0,1,u)),-11-sin(u*PI)*25)

func walk_foot_angle(phase: float) -> float:
	var t := fposmod(phase/TAU,1.0)
	if t <= WALK_CONTACT: return 0.0
	return sin((t-WALK_CONTACT)/(1.0-WALK_CONTACT)*TAU)*0.28

func gait_height(phase: float) -> float:
	var height := 90.0
	for offset in [0.0,PI]:
		if fposmod((phase+offset)/TAU,1.0)<=WALK_CONTACT:
			var x := walk_ankle(phase+offset).x
			height = minf(height,sqrt(79.0*79.0-x*x)+11.0)
	return lerpf(standing_height(),lerpf(height,run_pelvis_height(phase),run_weight),move_weight)

func gait_leg_points(hip: Vector2,phase: float,front_leg: bool) -> Array[Vector2]:
	var rest := standing_points(front_leg)
	var rest_ankle := Vector2(-4+rest[2].x,-11)
	var target := walk_ankle(phase).lerp(run_ankle(phase),run_weight)+Vector2(hip.x,0)
	var ankle := rest_ankle.lerp(target,move_weight) + _run_vector("front_foot_offset" if front_leg else "back_foot_offset")
	var root := hip+rest[0]*(1.0-move_weight)
	return [root,knee(root,ankle,1),ankle]

func gait_leg(hip: Vector2,phase: float,front_leg: bool,tint: Color) -> void:
	var pose := gait_leg_points(hip,phase,front_leg)
	segment(6,pose[0],pose[1],38 if front_leg else 33,tint)
	segment(7,pose[1],pose[2],31 if front_leg else 27,tint)
	var toe := lerpf(walk_foot_angle(phase),run_foot_angle(phase),run_weight)*move_weight
	toe += _run_angle("front_foot_pitch_degrees" if front_leg else "back_foot_pitch_degrees")
	part(8,pose[2]-Vector2(-5,8).rotated(toe),Vector2(34,19),toe,tint)

# Solve the rear elbow branch with fixed bone lengths, keeping the wrist
# on the grip through recoil and cover instead of compressing the forearm.
func weapon_elbow(shoulder: Vector2,wrist: Vector2) -> Vector2:
	var delta := wrist-shoulder
	var d := clampf(delta.length(),0.01,65.9)
	var axis := delta.normalized()
	var along := (36.0*36.0-30.0*30.0+d*d)/(2*d)
	var height := sqrt(maxf(0,36.0*36.0-along*along))
	return shoulder+axis*along+Vector2(-axis.y,axis.x)*height

func free_arm(shoulder: Vector2,phase: float,tint: Color,far := false) -> void:
	var swing := -walk_angles(phase).lerp(run_angles(phase),run_weight).x * lerpf(0.7,0.9,run_weight)*move_weight
	swing += _run_angle("back_arm_swing_degrees" if far else "front_arm_swing_degrees")
	var elbow := shoulder + Vector2(sin(swing),cos(swing))*29
	var bend := lerpf(0.12,1.85,run_weight)
	bend += _run_angle("back_elbow_bend_degrees" if far else "front_elbow_bend_degrees")
	var hand := elbow + Vector2(sin(swing+bend),cos(swing+bend))*27
	segment(3,shoulder,elbow,28,tint)
	segment(4,elbow,hand,19,tint,false)
	if fighter.drake or fighter.azure or (not fighter.enemy and fighter.hybrid_body):
		var wrist_angle := (hand-elbow).angle()-PI/2
		part(14 if far else 13,hand,Vector2(10,12) if far else Vector2(12,13),wrist_angle-0.10,tint)

func _draw() -> void:
	if not is_instance_valid(fighter):
		return
	if skeleton_active and not procedural_override:
		for node in parts:
			node.visible = false
		scale = Vector2(fighter.facing, 1)
		modulate = Color.WHITE
		if fighter.recoil > 0.65 and is_instance_valid(skeleton_weapon):
			var tip := to_local(skeleton_weapon.to_global(Vector2(46, 17)))
			var dir := (to_local(skeleton_weapon.to_global(Vector2(60, 17))) - tip).angle()
			draw_set_transform(tip, dir, Vector2.ONE)
			draw_colored_polygon(PackedVector2Array([Vector2(0,-9), Vector2(33,-3), Vector2(16,0), Vector2(39,8), Vector2(0,7)]), Color(1,0.78,0.34,fighter.recoil))
			draw_set_transform(Vector2.ZERO)
		return
	part_cursor = 0
	run_bone_records.clear()
	scale.x = fighter.facing * lerpf(1.0,0.83,cover_weight)
	scale.y = lerpf(1.0,0.96,cover_weight)
	modulate = Color.WHITE.lerp(Color(0.58,0.68,0.82),cover_weight)
	var moving: bool = absf(fighter.velocity.x) > 12 and _grounded()
	var cycle: float = fighter.gait
	var bob: float = absf(sin(cycle)) * 3 if moving else sin(clock*2.8)*1.1
	var hip := Vector2(-4, -76 + bob)
	hip.y += sin(cycle*2)*3*run_weight
	hip.y = lerpf(hip.y,-standing_height(),stand_weight)
	var locomotion: bool = _grounded() and not fighter.climbing and not fighter.crouching and not fighter.in_cover and fighter.health>0
	if locomotion:
		hip.y = -gait_height(cycle)
	var front := Vector2(9, -3)
	var back := Vector2(-12, -3)
	if moving:
		front += Vector2(sin(cycle)*25, -maxf(0,cos(cycle))*15)
		back += Vector2(sin(cycle+PI)*25, -maxf(0,cos(cycle+PI))*15)
	if not _grounded():
		front = Vector2(17,-22)
		back = Vector2(-22,-12)
	if fighter.climbing:
		hip = Vector2(-5,-77)
		front = Vector2(17,-17 + sin(cycle)*19)
		back = Vector2(-12,-17 - sin(cycle)*19)
	if fighter.crouching:
		hip.y += 27
		front.x = 27
		back.x = -24
	if fighter.in_cover:
		hip.x = -9
		front = Vector2(14,-3)
		back = Vector2(-17,-3)
	var authored_cover: bool = editor_preview and is_instance_valid(cover_pose) and fighter.in_cover and not fighter.enemy and not fighter.climbing
	if authored_cover:
		hip = cover_pose.get_node("Hip").position
		front = cover_pose.get_node("FrontFoot").position
		back = cover_pose.get_node("BackFoot").position
	if fighter.health <= 0:
		rotation = -fighter.facing * minf(fighter.dead_time * 4, PI/2)
		position.y = -12
		modulate.a = maxf(0.35, 1 - fighter.dead_time * 0.12)
	var dark := Color(0.62,0.65,0.70) if (not fighter.enemy or fighter.drake or fighter.azure) else Color(0.46,0.53,0.64)
	hip += _run_vector("hip_offset")
	var torso := hip + Vector2(2 + run_weight*13 - cover_weight*5,-47) + _run_vector("torso_offset")
	# Breathing moves the chest only; planted legs do not repeatedly buckle.
	torso.y += sin(clock*2.8)*0.7*stand_weight
	var lean := 0.17*run_weight - 0.11*cover_weight + _run_angle("torso_lean_degrees")
	if authored_cover:
		torso = hip + cover_pose.get_node("Torso").position
		lean = cover_pose.get_node("Torso").rotation
	var equipped: float = fighter.weapon_blend
	var holstered: float = 1.0-equipped
	if fighter.climbing:
		holstered = 1
		equipped = 0
	if fighter.health <= 0:
		equipped = 0
	if fighter.drake:
		var tail_at := hip+Vector2(-10,5)
		for i in 4:
			var length: float = [36.0,30.0,24.0,23.0][i]
			var height: float = [24.0,19.0,15.0,27.0][i]
			var tilt: float = [0.12,-0.06,-0.22,-0.20][i]+sin(clock*2.8-i*0.5)*0.05
			part(12 if i==0 else 14+i,tail_at,Vector2(length,height),-tilt,Color(0.85,0.82,0.91))
			var source_slope: float = [60.0/445.0,50.0/315.0,45.0/265.0,0.0][i]
			tail_at += Vector2(-length+2,source_slope*height).rotated(-tilt)

	# The coat is intentionally removed. The slung shotgun sits close to the back.
	if holstered > 0 and fighter.health > 0:
		part(2,torso+Vector2(-22,4)+_run_vector("weapon_offset"),Vector2(89,26),-1.18+_run_angle("weapon_tilt_degrees"),Color(0.8,0.85,0.95,holstered))
	if locomotion:
		gait_leg(hip,cycle+PI,false,dark)
	else:
		grounded_leg(hip,back,false,dark)
	if equipped < 0.5 and not fighter.climbing and not fighter.in_cover:
		free_arm(torso+Vector2(6,11),cycle+PI,dark,true)
	elif equipped >= 0.5 and not fighter.climbing and not fighter.in_cover:
		# Rear arm supports the fore-end while the near hand holds the trigger grip.
		segment(3,torso+Vector2(10,9),torso+Vector2(34,38),27,dark)
		var support := torso+Vector2(59,24)
		if fighter.drake or fighter.azure or not fighter.enemy:
			support = torso+Vector2(32,13)+preload("res://scripts/hybrid_sprites.gd").support_grip(fighter.drake)*Vector2(0.99,0.29)
		segment(4,torso+Vector2(34,38),support,18,dark)
	if locomotion:
		gait_leg(hip,cycle,true,Color.WHITE)
	else:
		grounded_leg(hip,front,true,Color.WHITE)
	# Flexible abdomen follows both chest lean and hip motion as one silhouette.
	# The painted abdomen already overlaps the hip sockets. Adding the old
	# vector pelvis here would leave a flat gray plate outside the silhouette.
	if not fighter.drake and not fighter.azure and (fighter.enemy or not fighter.hybrid_body):
		segment(5,torso+Vector2(0,37).rotated(lean),hip+Vector2(0,9),25)
	part(1,torso,Vector2(56,58),lean)
	if fighter.drake:
		part(0,torso+Vector2(-5+run_weight*6,-47),Vector2(52,54),lean-0.04)
	else:
		var head_size := Vector2(34,37) if (not fighter.enemy or fighter.azure) else Vector2(40,43)
		var head_top := -29.0 if (not fighter.enemy or fighter.azure) else -34.0
		part(0,torso+Vector2(4+run_weight*6,head_top),head_size,lean-0.04+_run_angle("head_tilt_degrees"))
	var shoulder := torso+Vector2(-9,9)
	if authored_cover:
		shoulder = torso + cover_pose.get_node("Torso/RightShoulder").position
	var elbow := torso+Vector2(12,33)
	var hand := torso+Vector2(36,24)
	if fighter.climbing:
		var far_shoulder := torso + Vector2(8, 9)
		var far_elbow := torso + Vector2(18, -8)
		var far_hand := torso + Vector2(18, -33 - sin(cycle) * 16)
		segment(3, far_shoulder, far_elbow, 24, dark)
		segment(4, far_elbow, far_hand, 18, dark, false)
		if fighter.drake or fighter.azure or (not fighter.enemy and fighter.hybrid_body):
			var far_wrist_angle := (far_hand - far_elbow).angle() - PI / 2
			part(14, far_hand, Vector2(10, 12), far_wrist_angle - 0.10, dark)
		elbow = torso + Vector2(9, -8)
		hand = torso + Vector2(15, -33 + sin(cycle) * 16)
		segment(3, shoulder, elbow, 24)
		segment(4, elbow, hand, 18, Color.WHITE, false)
		if fighter.drake or fighter.azure or (not fighter.enemy and fighter.hybrid_body):
			var wrist_angle := (hand - elbow).angle() - PI / 2
			part(13, hand, Vector2(12, 13), wrist_angle - 0.10, Color.WHITE)
	elif fighter.in_cover:
		# Keep the hand anchored to the actual pistol grip while the rifle rotates upright.
		elbow = torso+Vector2(-17,36)
		hand = torso+Vector2(3,24)
		var hybrid: bool = fighter.drake or fighter.azure or not fighter.enemy
		var cover_gun := torso+Vector2(0 if hybrid else 18,7)
		var cover_angle := -1.4
		if authored_cover:
			cover_gun = torso + cover_pose.get_node("Torso/Weapon").position
			cover_angle = cover_pose.get_node("Torso/Weapon").rotation
		if hybrid:
			hand = cover_gun+(Vector2(-24,79)*Vector2(0.94,0.27)).rotated(cover_angle)
		if not fighter.enemy or fighter.azure:
			elbow = weapon_elbow(shoulder,hand)
		if equipped > 0:
			part(2,cover_gun,Vector2(94,27),cover_angle,Color(1,1,1,equipped))
		segment(3,shoulder,elbow,31)
		segment(4,elbow,hand,19,Color.WHITE,false)
		if hybrid and equipped>0:
			part(9,cover_gun,Vector2(94,27),cover_angle,Color(1,1,1,equipped))
	elif equipped < 0.5:
		free_arm(shoulder,cycle,Color.WHITE)
	else:
		var kick: float = fighter.recoil*6
		var reach := (1.0-equipped)*34
		var gun_at := torso+Vector2(32-kick-reach,13-reach)
		var gun_angle: float = -fighter.recoil*0.055-(1.0-equipped)
		var grip := gun_at+(Vector2(-24,79)*Vector2(0.99,0.29)).rotated(gun_angle)
		elbow = weapon_elbow(shoulder,grip) if (not fighter.enemy or fighter.azure) else torso+Vector2(-3,34)
		part(11 if fighter.recoil>0.35 else 2,gun_at,Vector2(99,29),gun_angle,Color(1,1,1,equipped))
		segment(3,shoulder,elbow,31)
		segment(4,elbow,grip,19,Color.WHITE,false)
		part(10 if fighter.recoil>0.35 else 9,gun_at,Vector2(99,29),gun_angle,Color(1,1,1,equipped))
		if fighter.recoil > 0.65:
			var flash := torso+Vector2(85,24)
			if fighter.drake or fighter.azure or not fighter.enemy:
				flash = gun_at+(Vector2(46,38)*Vector2(0.99,0.29)).rotated(gun_angle)
			draw_colored_polygon(PackedVector2Array([flash+Vector2(0,-9),flash+Vector2(33,-3),flash+Vector2(16,0),flash+Vector2(39,8),flash+Vector2(0,7)]),Color(1,0.78,0.34,fighter.recoil))
	if fighter.enemy and fighter.health > 0:
		draw_rect(Rect2(torso.x-24,torso.y-(67 if fighter.drake else 54),48,4),Color("243243"))
		draw_rect(Rect2(torso.x-24,torso.y-(67 if fighter.drake else 54),48*fighter.health/75,4),Color("f07855"))



	if run_bone_layer != null and run_edit_weight > 0.0:
		run_bone_layer.apply_parts(run_bone_records, hip, run_edit_weight)
	for i in range(part_cursor,parts.size()):
		parts[i].visible = false
