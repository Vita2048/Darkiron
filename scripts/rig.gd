extends Node2D

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
	visible = fighter.position.x > fighter.world.camera_x-180 and fighter.position.x < fighter.world.camera_x+1620
	if not visible or fighter.world.paused:
		return
	clock += dt
	run_weight = move_toward(run_weight, 1.0 if fighter.running and fighter.is_on_floor() and fighter.health > 0 else 0.0, dt * 7)
	cover_weight = move_toward(cover_weight, 1.0 if fighter.in_cover else 0.0, dt * 9)
	var standing: bool = fighter.is_on_floor() and absf(fighter.velocity.x) < 12 and not fighter.climbing and not fighter.crouching and not fighter.in_cover and fighter.health > 0
	stand_weight = move_toward(stand_weight, 1.0 if standing else 0.0, dt * 8)
	var locomotion: bool = fighter.is_on_floor() and not fighter.climbing and not fighter.crouching and not fighter.in_cover and fighter.health > 0
	move_weight = move_toward(move_weight, 1.0 if locomotion and absf(fighter.velocity.x)>12 else 0.0, dt*8)
	queue_redraw()

func part(index: int, at: Vector2, size: Vector2, angle := 0.0, tint := Color.WHITE) -> void:
	if part_cursor == parts.size():
		var node := VectorPart.new()
		add_child(node)
		parts.append(node)
	var node := parts[part_cursor]
	node.configure(index,fighter.drake)
	node.position = at
	node.rotation = angle
	# Keep limb lengths and joint positions stable while balancing the silhouette.
	var breadth := 1.0
	match index:
		0: breadth = 0.80
		1: breadth = 0.80
		3: breadth = 0.83
		4: breadth = 1.18
		6: breadth = 0.87
		7: breadth = 0.90
	if fighter.drake:
		match index:
			0: breadth = 1.0
			1: breadth = 1.30
			3: breadth = 1.48
			4: breadth = 1.32
			6: breadth = 1.18
			7: breadth = 1.18
			8: breadth = 1.15
	node.scale = size*Vector2(breadth,1.0)/100.0
	node.modulate = tint
	node.z_index = part_cursor
	node.visible = true
	part_cursor += 1

func segment(index: int, a: Vector2, b: Vector2, width: float, tint := Color.WHITE) -> void:
	part(index, a, Vector2(width, a.distance_to(b) + 7), (b-a).angle() - PI/2, tint)

func knee(hip: Vector2, foot: Vector2, bend: float) -> Vector2:
	var delta := foot - hip
	var distance := minf(delta.length(), 79.5)
	var mid := (hip + foot) * 0.5
	return mid + Vector2(delta.y, -delta.x).normalized() * sqrt(maxf(0, 40*40-distance*distance/4)) * bend

func leg(hip: Vector2, foot: Vector2, tint: Color) -> void:
	var k := knee(hip, foot, 1)
	segment(6, hip, k, 29, tint)
	segment(7, k, foot, 24, tint)
	part(8, foot + Vector2(8,-9), Vector2(34,19), 0, tint)

# Adapted from Prince PS.stand / skeleton: explicit mild leg angles and hip
# height derived from their vertical reach, not a lowered hip with bent IK knees.
func standing_points(front_leg: bool) -> Array[Vector2]:
	var a := deg_to_rad(3.0 if front_leg else 0.0)
	var b := deg_to_rad(0.0 if front_leg else -1.0)
	var root := Vector2.ZERO
	var k := root + Vector2(sin(a),cos(a))*40
	var ankle := k + Vector2(sin(b),cos(b))*40
	return [root,k,ankle]

func standing_height() -> float:
	return maxf(standing_points(true)[2].y,standing_points(false)[2].y)+10.0

func grounded_leg(hip: Vector2,foot: Vector2,front_leg: bool,tint: Color) -> void:
	var standing := standing_points(front_leg)
	var base := Vector2(-4,-standing_height())
	var root := hip.lerp(base+standing[0],stand_weight)
	var k := knee(hip,foot,1).lerp(base+standing[1],stand_weight)
	var ankle := foot.lerp(base+standing[2],stand_weight)
	segment(6,root,k,38 if front_leg else 33,tint)
	segment(7,k,ankle,31 if front_leg else 27,tint)
	part(8,ankle+Vector2(8,-9),Vector2(34,19),0,tint)

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

func gait_height(phase: float) -> float:
	var f := gait_angles(phase,true)
	var b := gait_angles(phase+PI,false)
	var front_reach := 40*(cos(f.x)+cos(f.y))+sole_depth(foot_angle(phase))
	var back_reach := 40*(cos(b.x)+cos(b.y))+sole_depth(foot_angle(phase+PI))
	return lerpf(maxf(front_reach,back_reach)+flight_height(phase),run_pelvis_height(phase),run_weight*move_weight)

func gait_leg_points(hip: Vector2,phase: float,front_leg: bool) -> Array[Vector2]:
	var angles := gait_angles(phase,front_leg)
	var k := hip+Vector2(sin(angles.x),cos(angles.x))*40
	var ankle := k+Vector2(sin(angles.y),cos(angles.y))*40
	var run_target := run_ankle(phase)+Vector2(hip.x,0)
	var weight := run_weight*move_weight
	ankle = ankle.lerp(run_target,weight)
	k = k.lerp(knee(hip,run_target,1),weight)
	return [hip,k,ankle]

func gait_leg(hip: Vector2,phase: float,front_leg: bool,tint: Color) -> void:
	var pose := gait_leg_points(hip,phase,front_leg)
	segment(6,pose[0],pose[1],38 if front_leg else 33,tint)
	segment(7,pose[1],pose[2],31 if front_leg else 27,tint)
	var toe := lerpf(foot_angle(phase),run_foot_angle(phase),run_weight*move_weight)
	part(8,pose[2]-Vector2(-5,8).rotated(toe),Vector2(34,19),toe,tint)

func free_arm(shoulder: Vector2,phase: float,tint: Color) -> void:
	var swing := -walk_angles(phase).lerp(run_angles(phase),run_weight).x * lerpf(0.7,0.9,run_weight)*move_weight
	var elbow := shoulder + Vector2(sin(swing),cos(swing))*29
	var bend := lerpf(0.12,1.85,run_weight)
	var hand := elbow + Vector2(sin(swing+bend),cos(swing+bend))*27
	segment(3,shoulder,elbow,28,tint)
	segment(4,elbow,hand,19,tint)

func _draw() -> void:
	part_cursor = 0
	scale.x = fighter.facing * lerpf(1.0,0.83,cover_weight)
	scale.y = lerpf(1.0,0.96,cover_weight)
	modulate = Color.WHITE.lerp(Color(0.58,0.68,0.82),cover_weight)
	var moving: bool = absf(fighter.velocity.x) > 12 and fighter.is_on_floor()
	var cycle: float = fighter.gait
	var bob: float = absf(sin(cycle)) * 3 if moving else sin(clock*2.8)*1.1
	var hip := Vector2(-4, -76 + bob)
	hip.y += sin(cycle*2)*3*run_weight
	hip.y = lerpf(hip.y,-standing_height(),stand_weight)
	var locomotion: bool = fighter.is_on_floor() and not fighter.climbing and not fighter.crouching and not fighter.in_cover and fighter.health>0
	if locomotion:
		hip.y = -gait_height(cycle)
	var front := Vector2(9, -3)
	var back := Vector2(-12, -3)
	if moving:
		front += Vector2(sin(cycle)*25, -maxf(0,cos(cycle))*15)
		back += Vector2(sin(cycle+PI)*25, -maxf(0,cos(cycle+PI))*15)
	if not fighter.is_on_floor():
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
	if fighter.health <= 0:
		rotation = -fighter.facing * minf(fighter.dead_time * 4, PI/2)
		position.y = -12
		modulate.a = maxf(0.35, 1 - fighter.dead_time * 0.12)
	var dark := Color(0.46,0.53,0.64)
	var torso := hip + Vector2(2 + run_weight*13 - cover_weight*5,-47)
	# Breathing moves the chest only; planted legs do not repeatedly buckle.
	torso.y += sin(clock*2.8)*0.7*stand_weight
	var lean := 0.17*run_weight - 0.11*cover_weight
	var equipped: float = fighter.weapon_blend
	var holstered: float = 1.0-equipped
	if fighter.climbing:
		holstered = 1
		equipped = 0
	if fighter.health <= 0:
		equipped = 0
	if fighter.drake:
		part(12,hip+Vector2(-8,3),Vector2(65,65),sin(clock*2.8)*0.07+run_weight*0.15,Color(0.85,0.82,0.91))
	# The coat is intentionally removed. The slung shotgun sits close to the back.
	if holstered > 0 and fighter.health > 0:
		part(2,torso+Vector2(-22,4),Vector2(89,26),-1.18,Color(0.8,0.85,0.95,holstered))
	if locomotion:
		gait_leg(hip,cycle+PI,false,dark)
	else:
		grounded_leg(hip,back,false,dark)
	if equipped < 0.5 and not fighter.climbing and not fighter.in_cover:
		free_arm(torso+Vector2(6,11),cycle+PI,dark)
	elif equipped >= 0.5 and not fighter.climbing and not fighter.in_cover:
		# Rear arm supports the fore-end while the near hand holds the trigger grip.
		segment(3,torso+Vector2(10,9),torso+Vector2(34,38),27,dark)
		segment(4,torso+Vector2(34,38),torso+Vector2(59,24),18,dark)
	if locomotion:
		gait_leg(hip,cycle,true,Color.WHITE)
	else:
		grounded_leg(hip,front,true,Color.WHITE)
	# Flexible abdomen follows both chest lean and hip motion as one silhouette.
	segment(5,torso+Vector2(0,37).rotated(lean),hip+Vector2(0,9),25)
	part(1,torso,Vector2(56,58),lean)
	if fighter.drake:
		part(0,torso+Vector2(-5+run_weight*6,-47),Vector2(52,54),lean-0.04)
	else:
		part(0,torso+Vector2(4+run_weight*6,-34),Vector2(40,43),lean-0.04)
	var shoulder := torso+Vector2(-9,9)
	var elbow := torso+Vector2(12,33)
	var hand := torso+Vector2(36,24)
	if fighter.climbing:
		segment(3,torso+Vector2(8,9),torso+Vector2(18,-8),24,dark)
		segment(4,torso+Vector2(18,-8),torso+Vector2(18,-33-sin(cycle)*16),18,dark)
		elbow = torso + Vector2(9,-8)
		hand = torso + Vector2(15,-33 + sin(cycle)*16)
		segment(3,shoulder,elbow,24)
		segment(4,elbow,hand,18)
	elif fighter.in_cover:
		# Compressed silhouette, shoulder against the background, barrel upright.
		elbow = torso+Vector2(-17,36)
		hand = torso+Vector2(3,24)
		if equipped > 0:
			part(2,torso+Vector2(18,7),Vector2(94,27),-1.4,Color(1,1,1,equipped))
		segment(3,shoulder,elbow,31)
		segment(4,elbow,hand,19)
	elif equipped < 0.5:
		free_arm(shoulder,cycle,Color.WHITE)
	else:
		var kick: float = fighter.recoil*6
		var reach := (1.0-equipped)*34
		var gun_at := torso+Vector2(32-kick-reach,13-reach)
		var gun_angle: float = -fighter.recoil*0.055-(1.0-equipped)
		var grip := gun_at+(Vector2(-24,79)*Vector2(0.99,0.29)).rotated(gun_angle)
		elbow = torso+Vector2(-3,34)
		part(11 if fighter.recoil>0.35 else 2,gun_at,Vector2(99,29),gun_angle,Color(1,1,1,equipped))
		segment(3,shoulder,elbow,31)
		segment(4,elbow,grip,19)
		part(10 if fighter.recoil>0.35 else 9,gun_at,Vector2(99,29),gun_angle,Color(1,1,1,equipped))
		if fighter.recoil > 0.65:
			var flash := torso+Vector2(85,24)
			draw_colored_polygon(PackedVector2Array([flash+Vector2(0,-9),flash+Vector2(33,-3),flash+Vector2(16,0),flash+Vector2(39,8),flash+Vector2(0,7)]),Color(1,0.78,0.34,fighter.recoil))
	if fighter.enemy and fighter.health > 0:
		draw_rect(Rect2(torso.x-24,torso.y-(67 if fighter.drake else 54),48,4),Color("243243"))
		draw_rect(Rect2(torso.x-24,torso.y-(67 if fighter.drake else 54),48*fighter.health/75,4),Color("f07855"))



	for i in range(part_cursor,parts.size()):
		parts[i].visible = false
