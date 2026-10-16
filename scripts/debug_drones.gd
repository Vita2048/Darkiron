extends "res://scripts/debug_bow.gd"
const Drone = preload("res://scripts/range_drone.gd")
const Flame = preload("res://scripts/raptor_flame_texture.gd")
var fire_texture: Texture2D
var heat_glow: Texture2D
var fire_embers: Array = []
var bullet_glow: Texture2D
var drones: Array = []
var bolts: Array = []
var debris: Array = []
var rings: Array = []
var cover_held := false
const FIREBALL_GRAVITY := 220.0
var damage_flash := 0.0
var combat_won := false
var cover_layer: Node2D
var backdrop := preload("res://assets/cinderworks-background.png")

func _ready() -> void:
	super._ready()
	bullet_glow = glow
	fire_texture = Flame.flame_texture()
	heat_glow = Flame.glow_texture()
	get_window().title = "DARKIRON / Drone Gauntlet"
	target.hide()
	target.set_physics_process(false)
	target.rig.set_process(false)
	cover_layer = Node2D.new()
	cover_layer.z_index = 100
	cover_layer.draw.connect(draw_cover)
	add_child(cover_layer)
	get_window().focus_exited.connect(func(): cover_held = false; charging = false; charge = 0)
	spawn_drones()

func spawn_drones() -> void:
	for i in 3:
		var drone := Drone.new()
		drone.world = self
		drone.slot = i
		add_child(drone)
		drones.append(drone)
	feedback = "Three hunters inbound. HOLD UP for cover. Shoot between their orange firing pulses."

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode == KEY_UP:
		cover_held = event.pressed
	super._input(event)
	if cover_held or player.health <= 0 or combat_won:
		charging = false
		charge = 0

func shoot() -> void:
	if cover_held or player.in_cover or player.health <= 0 or combat_won: return
	super.shoot()

func reset_target() -> void:
	for drone in drones: drone.queue_free()
	drones.clear()
	for effect in get_tree().get_nodes_in_group("blast_effects"):
		if effect.get_parent() == self: effect.queue_free()
	arrows.clear()
	bolts.clear()
	fire_embers.clear()
	sparks.clear()
	debris.clear()
	rings.clear()
	player.health = 100
	player.dead_time = 0
	player.rig.rotation = 0
	player.rig.position = Vector2.ZERO
	player.rig.modulate = Color.WHITE
	player.in_cover = false
	cover_held = false
	combat_won = false
	charging = false
	charge = 0
	shot_count = 0
	kills = 0
	damage_flash = 0
	spawn_drones()

func fire_drone(drone: Node2D) -> void:
	var muzzle: Vector2 = drone.position+Vector2(-58,13).rotated(drone.rotation)
	var travel := maxf(0.25,(muzzle.x-player.position.x)/480.0)
	var velocity := Vector2(-480,(player.position.y-110-muzzle.y-0.5*FIREBALL_GRAVITY*travel*travel)/travel)
	bolts.append({"p":muzzle,"v":velocity,"life":5.0})
	rings.append({"p":muzzle,"life":0.25,"max":0.25,"c":Color("ff9e56"),"radius":24.0})

func drone_destroyed(drone: Node2D) -> void:
	kills += 1
	var blast := preload("res://scripts/blast_effect.gd").new()
	blast.world = self
	blast.position = drone.position
	blast.scale = Vector2.ONE*0.65
	add_child(blast)
	rings.append({"p":drone.position,"life":0.65,"max":0.65,"c":Color("69dbff"),"radius":105.0})
	for i in 14:
		debris.append({"p":drone.position,"v":Vector2.from_angle(i*TAU/14)*randf_range(60,210),"life":2.3,"spin":randf_range(-8,8),"angle":randf()*TAU})
	if kills == drones.size():
		combat_won = true
		bolts.clear()
		feedback = "AIRSPACE CLEAR / All hunters destroyed. R to run again."
	else: feedback = "Hunter destroyed / %d remaining" % (drones.size()-kills)

func hit_player() -> void:
	if cover_held:
		return
	player.take_damage(20)
	damage_flash = 0.25
	if player.health <= 0:
		charging = false
		charge = 0
		feedback = "DOWN / Press R to retry. Hold UP when drones wind up their shots."

func _physics_process(dt: float) -> void:
	if paused: return
	clock += dt
	player.in_cover = cover_held and player.health > 0
	player.crouching = false # Use the same upright, tucked cover stance as the gun rig.
	if player.in_cover:
		charging = false
		charge = 0
	player.bow_charge = charge
	damage_flash = maxf(0,damage_flash-dt)
	for drone in drones: drone.advance(dt)
	for arrow in arrows:
		arrow.life -= dt
		if arrow.stuck: continue
		var previous: Vector2 = arrow.p
		arrow.p += arrow.v*dt+Vector2(0,0.5*GRAVITY*dt*dt)
		arrow.v.y += GRAVITY*dt
		var nearest := INF
		var victim: Node2D
		var critical := false
		for drone in drones:
			if drone.health <= 0: continue
			var hull := segment_entry(previous,arrow.p,drone.hull_rect())
			var eye := segment_entry(previous,arrow.p,drone.eye_rect())
			if hull < nearest:
				nearest = hull
				victim = drone
				critical = eye != INF
		if victim:
			arrow.p = previous.lerp(arrow.p,nearest)
			victim.hit(25.0 if critical else 18.75)
			impact(arrow.p)
			arrow.life = 0
			if not combat_won: feedback = "SENSOR HIT / -33%" if critical else "ARMOR HIT / -25%"
		elif arrow.p.y >= 720: arrow.life = 0
	arrows = arrows.filter(func(a): return a.life > 0)
	for bolt in bolts:
		bolt.life -= dt
		var old: Vector2 = bolt.p
		fire_embers.append({"p":bolt.p,"v":-bolt.v*0.07+Vector2(randf_range(-12,12),randf_range(-22,22)),"life":0.32})
		bolt.p += bolt.v*dt+Vector2(0,0.5*FIREBALL_GRAVITY*dt*dt)
		bolt.v.y += FIREBALL_GRAVITY*dt
		# Cover is a dodge stance, not a projectile-blocking barrier.
		var hit := INF if cover_held or player.health <= 0 else segment_entry(old,bolt.p,Rect2(210,545,42,175))
		var ground := INF
		if old.y < 720 and bolt.p.y >= 720:
			ground = (720-old.y)/(bolt.p.y-old.y)
		if hit != INF and hit <= ground:
			bolt.p = old.lerp(bolt.p,hit)
			hit_player()
			fire_impact(bolt.p)
			bolt.life = 0
		elif ground != INF:
			bolt.p = old.lerp(bolt.p,ground)
			fire_impact(bolt.p)
			rings.append({"p":bolt.p,"life":0.3,"max":0.3,"c":Color("ffad65"),"radius":28.0})
			bolt.life = 0
	bolts = bolts.filter(func(b): return b.life > 0)
	for spark in sparks:
		spark.p += spark.v*dt
		spark.life -= dt
	sparks = sparks.filter(func(s): return s.life > 0)
	for shard in debris:
		shard.p += shard.v*dt
		shard.v.y += 230*dt
		shard.angle += shard.spin*dt
		shard.life -= dt
	debris = debris.filter(func(s): return s.life > 0)
	for ring in rings: ring.life -= dt
	rings = rings.filter(func(r): return r.life > 0)
	for ember in fire_embers:
		ember.p += ember.v*dt
		ember.life -= dt
	fire_embers = fire_embers.filter(func(e): return e.life > 0)
	queue_redraw()
	cover_layer.queue_redraw()

func draw_cover() -> void:
	if damage_flash > 0:
		cover_layer.draw_rect(Rect2(0,190,1100,620),Color(1,0.1,0.05,damage_flash*0.35))

func _draw() -> void:
	draw_texture_rect(backdrop,Rect2(0,190,1100,620),false,Color(0.32,0.4,0.52))
	draw_rect(Rect2(0,190,1100,620),Color(0.02,0.04,0.08,0.35))
	for x in [50,430,1070]:
		draw_rect(Rect2(x,350,9,370),Color("121d2d"))
		draw_line(Vector2(x+4,355),Vector2(x+4,700),Color(0.2,0.6,0.8,0.25),2)
	for i in 28:
		var p := Vector2(fposmod(i*97+clock*9,1100),350+fposmod(i*43-clock*13,370))
		draw_circle(p,1,Color(0.3,0.7,1,0.25))
	draw_rect(Rect2(0,720,1100,90),Color("111d2b"))
	draw_line(Vector2(0,720),Vector2(1100,720),Color("4d8ba1"),2)
	draw_rect(Rect2(25,216,1050,117),Color(0.015,0.025,0.05,0.85))
	draw_string(font,Vector2(45,251),"DARKIRON / HUNTER DRONES",HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("d8f4ff"))
	draw_string(font,Vector2(45,280),"ION FLIGHT TEST     /     %d OF 3 DESTROYED" % kills,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("82adc4"))
	draw_string(font,Vector2(45,311),feedback,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("8de3ff"))
	draw_string(font,Vector2(45,754),"HOLD UP: cover   |   HOLD LEFT MOUSE: up/down aim, left/right power   |   RELEASE: fire",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("d3e8f3"))
	draw_string(font,Vector2(45,785),"R restart   /   ESC pause   /   H hit zones   /   F11 fullscreen",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("7295ae"))
	draw_rect(Rect2(820,242,210,8),Color("293649"))
	draw_rect(Rect2(820,242,210*player.health/100.0,8),Color("71dacd"))
	draw_string(font,Vector2(820,275),"ARMOR %d%%" % int(player.health),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("9cebe2"))
	draw_rect(Rect2(340,690,130,5),Color("293c51"))
	draw_rect(Rect2(340,690,130*charge,5),Color("5cdcff"))
	draw_string(font,Vector2(340,682),"DRAW %d%%" % int(charge*100),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("83def7"))
	if paused: draw_string(font,Vector2(470,410),"PAUSED",HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color.WHITE)
	for drone in drones:
		if drone.warning > 0 and drone.health > 0:
			draw_dashed_line(drone.position,player.position+Vector2(0,-110),Color(1,0.3,0.1,0.18),1,9)
		if show_zones and drone.health > 0:
			draw_rect(drone.hull_rect(),Color(1,0.5,0.1,0.2))
			draw_rect(drone.eye_rect(),Color(0.1,0.8,1,0.4))
	for arrow in arrows:
		draw_line(arrow.p,arrow.p-arrow.v.normalized()*42,Color(0.2,0.7,1,0.2),5,true)
		plasma_arrow(arrow.p,arrow.v.angle())
	for ember in fire_embers:
		var fade: float = ember.life/0.32
		draw_circle(ember.p,2.5*fade,Color(1,0.35+fade*0.4,0.08,fade))
	for bolt in bolts:
		var pulse := 1.0+0.12*sin(clock*35+bolt.p.x*0.1)
		draw_texture_rect(heat_glow,Rect2(bolt.p-Vector2(27,27),Vector2(54,54)),false,Color(1,0.26,0.03,0.65))
		draw_set_transform(bolt.p,bolt.v.angle()-PI/2,Vector2.ONE*pulse)
		draw_texture_rect(fire_texture,Rect2(-17,-43,34,56),false)
		draw_set_transform(Vector2.ZERO)
		draw_circle(bolt.p,6*pulse,Color("ff7223"))
		draw_circle(bolt.p,3.3*pulse,Color("fff1b0"))
	for ring in rings:
		var t: float = 1-ring.life/ring.max
		var tint: Color = ring.c
		tint.a = 1-t
		draw_arc(ring.p,4+ring.radius*t,0,TAU,48,tint,2,true)
	for spark in sparks: draw_circle(spark.p,2,Color(0.4,0.85,1,spark.life/0.4))
	for shard in debris:
		draw_set_transform(shard.p,shard.angle)
		draw_colored_polygon(PackedVector2Array([Vector2(-5,-2),Vector2(5,0),Vector2(1,4)]),Color("647b8d"))
		draw_line(Vector2(-4,-2),Vector2(4,0),Color("ffb15d"),1,true)
	draw_set_transform(Vector2.ZERO)
	var cursor := get_global_mouse_position()
	draw_arc(cursor,7,0,TAU,24,Color("7feaff"),1,true)
	draw_line(cursor-Vector2(11,0),cursor+Vector2(11,0),Color("7feaff"),1,true)



func fire_impact(at: Vector2) -> void:
	var blast := preload("res://scripts/blast_effect.gd").new()
	blast.world = self
	blast.position = at
	blast.scale = Vector2.ONE*0.22
	add_child(blast)
	blast.z_index = 110
	for i in 12:
		fire_embers.append({"p":at,"v":Vector2.from_angle(i*TAU/12)*randf_range(45,130),"life":0.32})



