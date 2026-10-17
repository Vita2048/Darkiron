extends Node2D
## Isolated bow prototype. All coordinates and mouse aiming share the camera transform.
const Actor = preload("res://scripts/bow_range_actor.gd")
const LEVEL_END := 1100.0
const MAX_HEALTH := 75.0
const GRAVITY := 260.0
var player: CharacterBody2D
var target: CharacterBody2D
var camera: Camera2D
var camera_x := 0.0
var paused := false
var completed := false
var kills := 0
var arrows: Array = []
var sparks: Array = []
var drag_start := Vector2.ZERO
var drag_angle := 0.0
var charging := false
var charge := 0.0
var shot_count := 0
var feedback := "Hold left mouse: UP/DOWN aims; drag LEFT for power, RIGHT to ease. Release to shoot."
var font: Font = ThemeDB.fallback_font
var glow: GradientTexture2D
var clock := 0.0
var show_zones := false

func _ready() -> void:
	get_window().title = "DARKIRON / Plasma Bow Test Range"
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(2400,100)
	shape.shape = box
	ground.position = Vector2(600,770)
	ground.add_child(shape)
	add_child(ground)
	player = Actor.new()
	player.world = self
	player.position = Vector2(230,720)
	add_child(player)
	target = Actor.new()
	target.enemy = true
	target.drake = true
	target.world = self
	target.position = Vector2(850,720)
	add_child(target)
	camera = Camera2D.new()
	camera.position = Vector2(550,500)
	add_child(camera)
	get_viewport().size_changed.connect(_fit)
	_fit()
	glow = GradientTexture2D.new()
	glow.width = 128
	glow.height = 128
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5,0.5)
	glow.fill_to = Vector2(1,0.5)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0,0.2,0.5,1])
	gradient.colors = PackedColorArray([Color(0.5,0.95,1,0.95),Color(0.1,0.65,1,0.55),Color(0.05,0.3,1,0.15),Color(0,0.2,1,0)])
	glow.gradient = gradient

func _fit() -> void:
	camera.zoom = get_viewport_rect().size / Vector2(1100,620)

func update_mouse(at: Vector2) -> void:
	if paused: return
	if charging:
		player.bow_angle = clampf(drag_angle+(at.y-drag_start.y)*0.0035,-1.0,0.6)
		charge = clampf((drag_start.x-at.x)/220.0,0,1)
	else:
		player.bow_angle = clampf((at.y-origin().y)*0.0035,-1.0,0.6)
	player.bow_charge = charge

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		update_mouse(get_canvas_transform().affine_inverse()*event.position)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not paused:
				drag_start = get_canvas_transform().affine_inverse()*event.position
				drag_angle = player.bow_angle
				charging = true
				charge = 0
			elif charging:
				if not paused: shoot()
				charging = false
				charge = 0
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			charging = false
			charge = 0
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R: reset_target()
			KEY_H: show_zones = not show_zones
			KEY_ESCAPE:
				paused = not paused
				charging = false
				charge = 0
			KEY_F11:
				get_window().mode = Window.MODE_MAXIMIZED if get_window().mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

func reset_target() -> void:
	target.health = MAX_HEALTH
	target.dead_time = 0
	target.rig.rotation = 0
	target.rig.position = Vector2.ZERO
	target.rig.modulate = Color.WHITE
	arrows.clear()
	sparks.clear()
	charging = false
	charge = 0
	shot_count = 0
	feedback = "Target restored / 100%"

func origin() -> Vector2:
	return player.position + Vector2(0,-126)

func shoot() -> void:
	# Input can release between render frames; sample the final draw amount now.
	player.rig._update_run_edits()
	var direction := Vector2.from_angle(player.bow_angle)
	arrows.append({"p": player.position+player.rig.bow.nock()+direction*110, "v": direction*lerpf(640,2080,charge), "life": 5.0, "stuck": false})
	shot_count += 1

func head_rect() -> Rect2:
	return Rect2(target.position+Vector2(-30,-184),Vector2(54,48))

func body_rect() -> Rect2:
	return Rect2(target.position+Vector2(-30,-136),Vector2(60,136))

# Slab intersection returns the earliest segment fraction; prevents fast arrows tunneling.
func segment_entry(a: Vector2, b: Vector2, box: Rect2) -> float:
	var low := 0.0
	var high := 1.0
	var delta := b-a
	for axis in 2:
		if absf(delta[axis]) < 0.00001:
			if a[axis] < box.position[axis] or a[axis] > box.end[axis]: return INF
		else:
			var t1: float = (box.position[axis]-a[axis])/delta[axis]
			var t2: float = (box.end[axis]-a[axis])/delta[axis]
			low = maxf(low,minf(t1,t2))
			high = minf(high,maxf(t1,t2))
			if low > high: return INF
	return low

func _physics_process(dt: float) -> void:
	if paused: return
	clock += dt

	player.bow_charge = charge
	for arrow in arrows:
		arrow.life -= dt
		if arrow.stuck: continue
		var previous: Vector2 = arrow.p
		arrow.p += arrow.v*dt + Vector2(0,0.5*GRAVITY*dt*dt)
		arrow.v.y += GRAVITY*dt
		var head := segment_entry(previous,arrow.p,head_rect()) if target.health > 0 else INF
		var body := segment_entry(previous,arrow.p,body_rect()) if target.health > 0 else INF
		if minf(head,body) != INF:
			arrow.p = previous.lerp(arrow.p,minf(head,body))
			var is_head := head <= body
			target.take_damage(MAX_HEALTH/3.0 if is_head else MAX_HEALTH/4.0)
			feedback = ("HEADSHOT / -33.3%" if is_head else "BODY HIT / -25%") + (" / Target defeated - R to reset" if target.health <= 0 else "")
			impact(arrow.p)
			arrow.life = 0
		elif arrow.p.y >= 720:
			arrow.p = previous.lerp(arrow.p,clampf((720-previous.y)/(arrow.p.y-previous.y),0,1))
			arrow.stuck = true
			arrow.life = 2
			feedback = "Ground hit / draw further or aim higher"
	arrows = arrows.filter(func(a): return a.life > 0)
	for spark in sparks:
		spark.p += spark.v*dt
		spark.life -= dt
	sparks = sparks.filter(func(s): return s.life > 0)
	queue_redraw()

func impact(at: Vector2) -> void:
	for i in 18:
		sparks.append({"p":at,"v":Vector2.from_angle(TAU*i/18.0)*randf_range(40,160),"life":0.4})

func plasma_arrow(tip: Vector2, angle: float) -> void:
	draw_set_transform(tip,angle)
	draw_line(Vector2(-110,0),Vector2(-10,0),Color("6f91a6"),2,true)
	preload("res://scripts/arrow_feathers.gd").draw_feathers(self,Vector2(-110,0))
	draw_texture_rect(glow,Rect2(-30,-24,48,48),false)
	draw_colored_polygon(PackedVector2Array([Vector2(3,0),Vector2(-14,-5),Vector2(-10,0),Vector2(-14,5)]),Color("7deaff"))
	draw_line(Vector2(-11,0),Vector2(2,0),Color.WHITE,2,true)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	draw_rect(Rect2(-100,100,1400,800),Color("090f1c"))
	for x in range(0,1200,100):
		draw_line(Vector2(x,310),Vector2(x,720),Color("142236"),1)
	for y in range(320,721,50):
		draw_line(Vector2(0,y),Vector2(1100,y),Color("142236"),1)
	draw_rect(Rect2(0,720,1100,90),Color("172334"))
	draw_line(Vector2(0,720),Vector2(1100,720),Color("43788a"),2)
	draw_string(font,Vector2(45,250),"DARKIRON  /  PLASMA BOW",HORIZONTAL_ALIGNMENT_LEFT,-1,27,Color("ccedff"))
	draw_string(font,Vector2(45,282),"WEAPON LAB 01     /     OBSIDIAN DRAKE - PASSIVE TARGET",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("70a1ba"))
	draw_string(font,Vector2(45,320),feedback,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("6bddff"))
	draw_string(font,Vector2(45,766),"HOLD LEFT: up/down aim, left/right power   /   RELEASE fire   /   RIGHT cancel",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("d1dfeb"))
	draw_string(font,Vector2(45,792),"R reset   /   H hit zones   /   ESC pause   /   F11 fullscreen     |     Shots: %d" % shot_count,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("7e9eb7"))
	if paused: draw_string(font,Vector2(480,400),"PAUSED",HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color.WHITE)
	draw_rect(Rect2(340,690,130,5),Color("293c51"))
	draw_rect(Rect2(340,690,130*charge,5),Color("5cdcff"))
	draw_string(font,Vector2(340,682),"DRAW %d%%" % int(charge*100),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("83def7"))
	draw_rect(Rect2(785,494,130,9),Color("302632"))
	draw_rect(Rect2(785,494,130*target.health/MAX_HEALTH,9),Color("ef8167"))
	draw_string(font,Vector2(785,484),"DRAKE  %d%%" % ceili(target.health/MAX_HEALTH*100),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f3af94"))
	if show_zones and target.health > 0:
		draw_rect(head_rect(),Color(0.2,0.8,1,0.25))
		draw_rect(body_rect(),Color(1,0.6,0.3,0.15))
	for arrow in arrows:
		plasma_arrow(arrow.p,arrow.v.angle())
	for spark in sparks:
		draw_circle(spark.p,2,Color(0.4,0.85,1,spark.life/0.4))
	var cursor := get_global_mouse_position()
	draw_arc(cursor,8,0,TAU,24,Color("74dfff"),1,true)
	draw_line(cursor-Vector2(12,0),cursor+Vector2(12,0),Color("74dfff"),1,true)
	draw_line(cursor-Vector2(0,12),cursor+Vector2(0,12),Color("74dfff"),1,true)






