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
	node.configure(index)
	node.position = at
	node.rotation = angle
	node.scale = size/100.0
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
	var a := deg_to_rad(4.0 if front_leg else -4.0)
	var b := deg_to_rad(0.0 if front_leg else -3.0)
	var root := Vector2(5 if front_leg else -6,0)
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
	segment(6,root,k,29,tint)
	segment(7,k,ankle,24,tint)
	part(8,ankle+Vector2(8,-9),Vector2(34,19),0,tint)

func fitted_waist(at: Vector2) -> void:
	part(5,at,Vector2(100,100))

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
	var rest := Vector2(4,0) if front_leg else Vector2(-4,-3)
	return (rest*PI/180.0).lerp(walk_angles(phase).lerp(run_angles(phase),run_weight),move_weight)

func gait_height(phase: float) -> float:
	var f := gait_angles(phase,true)
	var b := gait_angles(phase+PI,false)
	var reach := maxf(40*(cos(f.x)+cos(f.y)),40*(cos(b.x)+cos(b.y)))
	var half_phase := fposmod(phase/TAU,0.5)
	var flight := sin(clampf((half_phase-0.33)/0.17,0,1)*PI)*8*run_weight*move_weight
	return reach+10+flight

func gait_leg(hip: Vector2,phase: float,front_leg: bool,tint: Color) -> void:
	var angles := gait_angles(phase,front_leg)
	var k := hip+Vector2(sin(angles.x),cos(angles.x))*40
	var ankle := k+Vector2(sin(angles.y),cos(angles.y))*40
	segment(6,hip,k,29,tint)
	segment(7,k,ankle,24,tint)
	var p := fposmod(phase/TAU,1.0)
	var toe := clampf(angles.y*0.22,-0.7,0.3)*move_weight if p>0.5 else 0.0
	part(8,ankle+Vector2(8,-9),Vector2(34,19),toe,tint)

func run_leg(hip: Vector2, phase: float, tint: Color) -> void:
	var angles := run_angles(phase)
	var k := hip + Vector2(sin(angles.x),cos(angles.x))*39
	var ankle := k + Vector2(sin(angles.y),cos(angles.y))*40
	# Keep the planted foot above the ground during compression.
	if ankle.y > -7:
		ankle.y = -7
	segment(6,hip,k,29,tint)
	segment(7,k,ankle,24,tint)
	var toe := clampf(angles.y*0.27,-0.8,0.3)
	part(8,ankle+Vector2(7,-5),Vector2(33,18),toe,tint)

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
	var dark := Color(0.58,0.63,0.76)
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
	# The coat is intentionally removed. The slung shotgun sits close to the back.
	if holstered > 0 and fighter.health > 0:
		part(2,torso+Vector2(-22,4),Vector2(89,26),-1.18,Color(0.8,0.85,0.95,holstered))
	if locomotion:
		gait_leg(hip+Vector2(-6,0),cycle+PI,false,dark)
	else:
		grounded_leg(hip+Vector2(-6,3),back,false,dark)
	if equipped < 0.5 and not fighter.climbing and not fighter.in_cover:
		free_arm(torso+Vector2(6,11),cycle+PI,dark)
	elif equipped >= 0.5 and not fighter.climbing and not fighter.in_cover:
		# Rear arm supports the fore-end while the near hand holds the trigger grip.
		segment(3,torso+Vector2(10,9),torso+Vector2(34,38),27,dark)
		segment(4,torso+Vector2(34,38),torso+Vector2(59,24),18,dark)
	if locomotion:
		gait_leg(hip+Vector2(5,0),cycle,true,Color.WHITE)
	else:
		grounded_leg(hip+Vector2(5,2),front,true,Color.WHITE)
	fitted_waist(hip)
	part(1,torso,Vector2(56,58),lean)
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
		part(2,torso+Vector2(32-kick-reach,13-reach),Vector2(99,29),-fighter.recoil*0.055-(1.0-equipped),Color(1,1,1,equipped))
		segment(3,shoulder,elbow,31)
		segment(4,elbow,hand-Vector2(kick+reach,reach),19)
		if fighter.recoil > 0.65:
			var flash := torso+Vector2(85,24)
			draw_colored_polygon(PackedVector2Array([flash+Vector2(0,-9),flash+Vector2(33,-3),flash+Vector2(16,0),flash+Vector2(39,8),flash+Vector2(0,7)]),Color(1,0.78,0.34,fighter.recoil))
	if fighter.hurt_flash > 0:
		draw_circle(torso+Vector2(0,30),42,Color(1,0.5,0.2,0.2))
	if fighter.enemy and fighter.health > 0:
		draw_rect(Rect2(-24,-174,48,3),Color("243243"))
		draw_rect(Rect2(-24,-174,48*fighter.health/75,3),Color("f07855"))



	for i in range(part_cursor,parts.size()):
		parts[i].visible = false
