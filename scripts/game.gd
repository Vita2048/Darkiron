extends Node2D

const Fighter = preload("res://scripts/fighter.gd")
const Hud = preload("res://scripts/hud.gd")
const LADDER_X := 1250.0
const LEVEL_END := 6300.0
var player: CharacterBody2D
var enemies: Array = []
var bullets: Array = []
var grenades: Array = []
var particles: Array = []
var blast_flashes: Array = []
var equipment = preload("res://assets/cinderworks-equipment.png")
var platforms: Array[Rect2] = [Rect2(-200,720,610,220),Rect2(525,720,2395,220),Rect2(3030,720,3570,220),Rect2(1150,480,1600,44),Rect2(3300,480,600,44),Rect2(5000,480,1200,44)]
var ladders := [Vector3(1250,480,720),Vector3(3400,480,720),Vector3(5100,480,720)]
var barriers: Array = []
var caches := [{"p":Vector2(1550,480),"taken":false},{"p":Vector2(3780,720),"taken":false},{"p":Vector2(3700,480),"taken":false}]
var meds := [{"p":Vector2(2650,720),"taken":false},{"p":Vector2(3750,480),"taken":false},{"p":Vector2(4950,720),"taken":false}]
var checkpoint := Vector2(260,720)
var checkpoint_active := false
var notice := "THE CINDERWORKS / Find the demolition cache on the upper gallery."
var notice_time := 6.0
var seals_broken := 0
# Legacy single-barrier references retained for existing diagnostic scripts.
var crate := Rect2(2200,240,85,240)
var crate_health := 90.0
var crate_body: StaticBody2D
var camera: Camera2D
var camera_x := 0.0
var clock := 0.0
var shake := 0.0
var kills := 0
var grenades_left := 0
var completed := false
var paused := false
var muted := false
var backdrop: Texture2D = preload("res://assets/mountains.jpg")
var font: Font = ThemeDB.fallback_font
var rng := RandomNumberGenerator.new()
var audio: Dictionary = {}
var capture_mode := false
var captured := false
var ui: Node2D
var bullet_glow: GradientTexture2D

func _ready() -> void:
	var window := get_window()
	# Apply runtime settings as well as project defaults, including editor runs.
	window.content_scale_size = Vector2i(1920,1080)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	window.content_scale_factor = 1.0
	window.title = "DARKIRON — The Cinderworks / Edition 14"
	# Shared smooth falloff: two textured glow draws per projectile, no lights.
	bullet_glow = GradientTexture2D.new()
	bullet_glow.width = 128
	bullet_glow.height = 128
	bullet_glow.fill = GradientTexture2D.FILL_RADIAL
	bullet_glow.fill_from = Vector2(0.5,0.5)
	bullet_glow.fill_to = Vector2(1,0.5)
	var falloff := Gradient.new()
	falloff.offsets = PackedFloat32Array([0,0.16,0.45,1])
	falloff.colors = PackedColorArray([Color(1,1,1,0.8),Color(1,1,1,0.5),Color(1,1,1,0.14),Color(1,1,1,0)])
	bullet_glow.gradient = falloff
	rng.seed = 82491
	_setup_input()
	for rect in platforms:
		_make_solid(rect)
	for rect in [crate,Rect2(4300,480,85,240)]:
		barriers.append({"rect":rect,"body":_make_solid(rect),"destroyed":false})
	crate_body = barriers[0].body
	var art := preload("res://scripts/level_art.gd").new()
	art.world = self
	art.z_index = -5
	add_child(art)
	player = Fighter.new()
	player.world = self
	player.position = Vector2(260,720)
	add_child(player)
	for spawn in [Vector2(825,720),Vector2(1900,480),Vector2(2520,480),Vector2(3240,720),Vector2(4690,720),Vector2(5580,480)]:
		var enemy := Fighter.new()
		enemy.enemy = true
		enemy.drake = enemies.is_empty()
		enemy.world = self
		enemy.position = spawn
		add_child(enemy)
		enemies.append(enemy)
	camera = Camera2D.new()
	camera.position = Vector2(720,450)
	# Preserve level coordinates while drawing the full scene at the HD canvas size.
	camera.zoom = Vector2(1920.0/1440.0,1080.0/900.0)
	add_child(camera)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui = Hud.new()
	ui.world = self
	ui.scale = Vector2(1920.0/1440.0,1080.0/900.0)
	layer.add_child(ui)
	_setup_audio()
	capture_mode = "--capture" in OS.get_cmdline_user_args()
	get_viewport().size_changed.connect(_fit_canvas)
	_fit_canvas()
	if DisplayServer.get_name() != "headless" and not capture_mode and not "--script" in OS.get_cmdline_args():
		window.set_deferred("mode",Window.MODE_MAXIMIZED)

func _fit_canvas() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(ui):
		return
	var canvas_size := get_viewport_rect().size
	camera.zoom = canvas_size / Vector2(1440,900)
	ui.scale = canvas_size / Vector2(1440,900)

func toggle_fullscreen() -> void:
	var window := get_window()
	window.mode = Window.MODE_MAXIMIZED if window.mode==Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

func _setup_input() -> void:
	var bindings := {"left":[KEY_LEFT],"right":[KEY_RIGHT],"up":[KEY_UP],"down":[KEY_DOWN],"toggle_weapon":[KEY_S],"jump":[KEY_SPACE],"shoot":[KEY_J,KEY_F],"grenade":[KEY_G],"run":[KEY_SHIFT],"restart":[KEY_R],"pause_game":[KEY_ESCAPE],"mute":[KEY_M],"continue_game":[KEY_ENTER]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("shoot",mouse)
	if not InputMap.has_action("fullscreen"):
		InputMap.add_action("fullscreen")
	InputMap.action_erase_events("fullscreen")
	var fullscreen_key := InputEventKey.new()
	fullscreen_key.physical_keycode = KEY_F11
	InputMap.action_add_event("fullscreen",fullscreen_key)

func _make_solid(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	return body

func _process(dt: float) -> void:
	if Input.is_action_just_pressed("fullscreen"):
		toggle_fullscreen()
	if Input.is_action_just_pressed("continue_game") and player.health<=0:
		respawn()
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if Input.is_action_just_pressed("pause_game"):
		paused = not paused
	if Input.is_action_just_pressed("mute"):
		muted = not muted
		AudioServer.set_bus_mute(0,muted)
	if not paused:
		clock += dt
		notice_time = maxf(0,notice_time-dt)
	camera_x = lerpf(camera_x,clampf(player.position.x-500,0,LEVEL_END-1440),1-exp(-dt*4))
	shake = move_toward(shake,0,dt*23)
	camera.position = Vector2(camera_x+720,450) + Vector2(rng.randf_range(-shake,shake),rng.randf_range(-shake,shake))
	queue_redraw()
	if capture_mode and clock > 1.8 and not captured:
		captured = true
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://preview.png")
		get_tree().quit()

func _physics_process(dt: float) -> void:
	if paused or completed:
		return
	for i in range(blast_flashes.size()-1,-1,-1):
		blast_flashes[i].life -= dt
		if blast_flashes[i].life<=0: blast_flashes.remove_at(i)
	_update_pickups(dt)
	for i in range(bullets.size()-1,-1,-1):
		var b: Dictionary = bullets[i]
		var previous: Vector2 = b.p
		b.p += b.v * dt
		b.life -= dt
		var hit := false
		var armor_hit := false
		# Solid blast seals stop both sides' fire and cannot be shot open.
		for barrier in barriers:
			if not barrier.destroyed and _segment_hits(previous,b.p,barrier.rect):
				b.p = _hit_position(previous,b.p,barrier.rect)
				hit = true
				break
		var targets: Array = [player] if b.enemy else enemies
		for target in targets:
			if hit:
				break
			# Cover steps into the background plane: bullets pass, rather than
			# disappearing on an invulnerable character.
			if target.in_cover:
				continue
			var height := 103.0 if target.crouching else 140.0
			var box := Rect2(target.position-Vector2(23,height),Vector2(46,height))
			if target.health > 0 and _segment_hits(previous,b.p,box):
				b.p = _hit_position(previous,b.p,box)
				armor_hit = true
				target.take_damage(13 if b.enemy else 27,Color("ff534b") if b.enemy else Color("35bfff"))
				hit = true
				break
		if not hit:
			for rect in platforms:
				if _segment_hits(previous,b.p,rect):
					b.p = _hit_position(previous,b.p,rect)
					hit = true
					break
		if hit:
			var impact := preload("res://scripts/bullet_impact.gd").new()
			impact.world = self
			impact.position = b.p
			impact.incoming = b.v.normalized()
			impact.energy = Color("ff534b") if b.enemy else Color("35bfff")
			impact.armor = armor_hit
			add_child(impact)
		if hit or b.life <= 0:
			bullets.remove_at(i)
	for i in range(grenades.size()-1,-1,-1):
		var g: Dictionary = grenades[i]
		var previous: Vector2 = g.p
		g.v.y += 1100*dt
		g.p += g.v*dt
		g.fuse -= dt
		for barrier in barriers:
			if not barrier.destroyed and _segment_hits(previous,g.p,barrier.rect.grow(5)):
				g.p = previous
				g.v.x *= -0.4
				g.v.y *= -0.4
		for rect in platforms:
			if rect.has_point(g.p) and g.v.y > 0:
				g.p.y = rect.position.y-5
				g.v.y *= -0.42
				g.v.x *= 0.68
		if g.fuse <= 0:
			explode(g.p)
			grenades.remove_at(i)
	for i in range(particles.size()-1,-1,-1):
		var p: Dictionary = particles[i]
		p.p += p.v*dt
		p.v.y += 300*dt
		p.life -= dt
		if p.life <= 0:
			particles.remove_at(i)
	if player.health>0 and player.position.x>5940 and player.position.y<500 and seals_broken==2 and kills==enemies.size():
		completed = true
		sound("win")

func ladder_at(at: Vector2) -> Vector3:
	for ladder in ladders:
		if absf(at.x-ladder.x)<40 and at.y>=ladder.y-10 and at.y<=ladder.z+13:
			return ladder
	return Vector3.ZERO

func say(message: String) -> void:
	notice = message
	notice_time = 4.0

func _update_pickups(_dt: float) -> void:
	if player.health<=0:
		return
	for cache in caches:
		if player.position.distance_to(cache.p)<65 and not cache.taken and grenades_left<=3:
			grenades_left = mini(6,grenades_left+3)
			cache.taken = true
			burst(cache.p+Vector2(0,-25),Color("ffd185"),14)
			sound("jump")
			say("DEMOLITION CACHE / +3 bombs. G to throw. Blast seals resist gunfire.")
	for med in meds:
		if not med.taken and player.health<100 and player.position.distance_to(med.p)<50:
			med.taken = true
			player.health = minf(100,player.health+40)
			say("FIELD MEDKIT / +40 health")
	if not checkpoint_active and seals_broken>0 and player.position.x>2600:
		checkpoint_active = true
		checkpoint = Vector2(2800,720)
		player.health = minf(100,player.health+30)
		say("RELAY ONLINE / Checkpoint secured. ENTER to return here after death.")

func respawn() -> void:
	player.position = checkpoint
	player.velocity = Vector2.ZERO
	player.health = 100
	player.dead_time = 0
	player.climbing = false
	player.in_cover = false
	player.crouching = false
	player.collision_mask = 1
	player.weapon_drawn = true
	player.weapon_blend = 1
	player.rig.rotation = 0
	player.rig.position = Vector2.ZERO
	player.rig.modulate = Color.WHITE
	bullets.clear()
	grenades.clear()
	for enemy in enemies:
		enemy.cooldown = 2.0
	camera_x = clampf(checkpoint.x-500,0,LEVEL_END-1440)
	say("BACK IN THE FIGHT / Your progress is preserved.")

func _segment_hits(a: Vector2,b: Vector2,rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var corners := [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4]) != null:
			return true
	return false

func _hit_position(a: Vector2,b: Vector2,rect: Rect2) -> Vector2:
	if rect.has_point(a): return a
	var point := b
	var corners := [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
	for i in 4:
		var contact = Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4])
		if contact != null and a.distance_squared_to(contact)<a.distance_squared_to(point): point = contact
	return point

func fire_bullet(actor: CharacterBody2D) -> void:
	bullets.append({"p":actor.muzzle(),"v":Vector2(actor.facing*1100,0),"life":1.35,"enemy":actor.enemy})
	burst(actor.muzzle(),Color("ffb24b"),4)
	sound("enemy" if actor.enemy else "shot")
	if not actor.enemy:
		shake = 2
		var origin: Vector2 = actor.muzzle()
		for guard in enemies:
			var delta: Vector2 = guard.position+Vector2(0,-100)-origin
			if delta.x*actor.facing<=0 or absf(delta.x)>620 or absf(delta.y)>65: continue
			var blocked := false
			var target: Vector2 = guard.position+Vector2(0,-100)
			for barrier in barriers:
				if not barrier.destroyed and _segment_hits(origin,target,barrier.rect): blocked = true
			for platform in platforms:
				if _segment_hits(origin,target,platform): blocked = true
			if not blocked: guard.notice_shot(origin)

func throw_grenade(actor: CharacterBody2D) -> void:
	if grenades_left <= 0 or actor.health <= 0:
		say("NO BOMBS / Find an amber demolition cache.")
		return
	grenades_left -= 1
	grenades.append({"p":actor.position+Vector2(actor.facing*30,-110),"v":Vector2(actor.facing*420,-400),"fuse":1.45})
	sound("jump")

func explode(at: Vector2) -> void:
	var effect := preload("res://scripts/blast_effect.gd").new()
	effect.world = self
	effect.position = at
	for platform in platforms:
		if at.x >= platform.position.x and at.x <= platform.end.x and platform.position.y >= at.y-12 and platform.position.y-at.y < 210:
			effect.floor_offset = minf(effect.floor_offset,platform.position.y-at.y)
	add_child(effect)
	burst(at,Color("ffb45d"),65)
	burst(at,Color("a5c4d5"),20)
	shake = 12
	sound("boom")
	for enemy in enemies:
		if (enemy.position+Vector2(0,-60)).distance_to(at) < 185:
			enemy.take_damage(100)
	for barrier in barriers:
		var rect: Rect2 = barrier.rect
		var closest := Vector2(clampf(at.x,rect.position.x,rect.end.x),clampf(at.y,rect.position.y,rect.end.y))
		if not barrier.destroyed and closest.distance_to(at)<155:
			barrier.destroyed = true
			barrier.body.queue_free()
			var wreckage := preload("res://scripts/blast_effect.gd").new()
			wreckage.world = self
			wreckage.position = Vector2(rect.get_center().x,rect.end.y)
			wreckage.floor_offset = 0
			wreckage.door_debris = true
			add_child(wreckage)
			seals_broken += 1
			burst(rect.get_center(),Color("e8ad74"),45)
			if barrier==barriers[0]: crate_health = 0
			say("BLAST SEAL DESTROYED / Passage cleared. "+str(seals_broken)+" of 2.")

func _damage_crate(_amount: float) -> void:
	# Reinforced seals are explosives-only.
	pass

func burst(at: Vector2,color: Color,count: int) -> void:
	for i in count:
		particles.append({"p":at,"v":Vector2(rng.randf_range(-240,240),rng.randf_range(-280,80)),"life":rng.randf_range(0.15,0.7),"c":color,"s":rng.randf_range(1,4)})

func _draw() -> void:
	for flash in blast_flashes:
		var t: float = 1.0-flash.life/0.55
		var radius := lerpf(25,160,t)
		draw_texture_rect(bullet_glow,Rect2(flash.p-Vector2.ONE*radius,Vector2.ONE*radius*2),false,Color(1,0.46,0.12,(1-t)*0.9))
		draw_arc(flash.p,radius*0.72,0,TAU,48,Color(1,0.74,0.35,(1-t)*0.65),3,true)
	for b in bullets:
		var energy := Color("ff534b") if b.enemy else Color("35bfff")
		draw_set_transform(b.p,b.v.angle())
		draw_texture_rect(bullet_glow,Rect2(-58,-17,72,34),false,Color(energy,0.72))
		draw_texture_rect(bullet_glow,Rect2(-19,-19,38,38),false,energy)
		draw_line(Vector2(-42,0),Vector2(-5,0),Color(energy,0.22),7,true)
		draw_line(Vector2(-28,0),Vector2(1,0),energy,3.5,true)
		draw_line(Vector2(-16,0),Vector2(2,0),Color("fff0e9") if b.enemy else Color("dcfaff"),1.5,true)
		draw_circle(Vector2.ZERO,2.4,Color.WHITE)
		draw_set_transform(Vector2.ZERO)
	for g in grenades:
		draw_texture_rect(bullet_glow,Rect2(g.p-Vector2(25,25),Vector2(50,50)),false,Color(1,0.45,0.08,0.5+sin(clock*24)*0.25))
		draw_set_transform(g.p,(1.45-g.fuse)*9)
		draw_texture_rect_region(equipment,Rect2(-8,-15,16,30),Rect2(900,25,350,675))
		draw_set_transform(Vector2.ZERO)
	for p in particles:
		var color: Color = p.c
		color.a = minf(1,p.life*2)
		draw_line(p.p,p.p-p.v*0.023,color,p.s,true)
	for i in 32:
		var dust := Vector2(fposmod(i*159.7+clock*(8+i%3*7),1500)+camera_x,180+fposmod(i*67.2-clock*5,580))
		draw_circle(dust,1.3,Color(0.78,0.85,0.95,0.19+sin(clock+i)*0.1))

func _glow(at: Vector2,color: Color,radius: float) -> void:
	for i in range(5,0,-1):
		var c := color
		c.a = 0.035
		draw_circle(at,radius*i/5.0,c)
	draw_circle(at,2,color)

func _world_text(at: Vector2,value: String,size: int,color: Color) -> void:
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _setup_audio() -> void:
	for kind in ["shot","enemy","jump","boom","hurt","fall","win"]:
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		var duration := 0.7 if kind in ["boom","win"] else 0.2
		var bytes := PackedByteArray()
		bytes.resize(int(22050*duration)*2)
		var noise_rng := RandomNumberGenerator.new()
		noise_rng.seed = 12
		for i in range(bytes.size()/2):
			var t := float(i)/22050
			var envelope := pow(1-t/duration,2)
			var value := 0.0
			if kind in ["shot","enemy","boom"]:
				value = (noise_rng.randf_range(-1,1)*0.65+sin(t*(110 if kind=="boom" else 210)*TAU)*0.35)*envelope
			elif kind == "win":
				value = sin(t*(440 if t<0.22 else (554 if t<0.44 else 659))*TAU)*envelope*0.5
			else:
				value = sin(TAU*(240*t-170*t*t))*envelope*0.45
			bytes.encode_s16(i*2,int(clampf(value,-1,1)*20000))
		stream.data = bytes
		audio[kind] = stream

func sound(kind: String) -> void:
	if not audio.has(kind):
		return
	var voice := AudioStreamPlayer.new()
	voice.stream = audio[kind]
	voice.volume_db = -14 if kind == "enemy" else -10
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()
