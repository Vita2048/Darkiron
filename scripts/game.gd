extends Node2D

const Fighter = preload("res://scripts/fighter.gd")
const Hud = preload("res://scripts/hud.gd")
const LADDER_X := 1250.0
const LEVEL_END := 2980.0
var player: CharacterBody2D
var enemies: Array = []
var bullets: Array = []
var grenades: Array = []
var particles: Array = []
var platforms: Array[Rect2] = [Rect2(-200,720,3400,200),Rect2(1150,480,1800,42),Rect2(410,657,115,63)]
var crate := Rect2(2200,400,66,80)
var crate_health := 90.0
var crate_body: StaticBody2D
var camera: Camera2D
var camera_x := 0.0
var clock := 0.0
var shake := 0.0
var kills := 0
var grenades_left := 5
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
	window.title = "DARKIRON — Vector Edition 12"
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
	crate_body = _make_solid(crate)
	player = Fighter.new()
	player.world = self
	player.position = Vector2(260,720)
	add_child(player)
	for spawn in [Vector2(825,720),Vector2(1850,480)]:
		var enemy := Fighter.new()
		enemy.enemy = true
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
	var bindings := {"left":[KEY_LEFT],"right":[KEY_RIGHT],"up":[KEY_UP],"down":[KEY_DOWN],"toggle_weapon":[KEY_S],"jump":[KEY_SPACE],"shoot":[KEY_J,KEY_F],"grenade":[KEY_G],"run":[KEY_SHIFT],"restart":[KEY_R],"pause_game":[KEY_ESCAPE],"mute":[KEY_M]}
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
	for i in range(bullets.size()-1,-1,-1):
		var b: Dictionary = bullets[i]
		var previous: Vector2 = b.p
		b.p += b.v * dt
		b.life -= dt
		var hit := false
		var targets: Array = [player] if b.enemy else enemies
		for target in targets:
			# Cover steps into the background plane: bullets pass, rather than
			# disappearing on an invulnerable character.
			if target.in_cover:
				continue
			var height := 103.0 if target.crouching else 140.0
			var box := Rect2(target.position-Vector2(23,height),Vector2(46,height))
			if target.health > 0 and _segment_hits(previous,b.p,box):
				target.take_damage(13 if b.enemy else 27)
				hit = true
				break
		if not hit and crate_health > 0 and _segment_hits(previous,b.p,crate):
			_damage_crate(22)
			hit = true
		if not hit:
			for rect in platforms:
				if _segment_hits(previous,b.p,rect):
					hit = true
					break
		if hit:
			burst(b.p,Color("ffba70"),5)
		if hit or b.life <= 0:
			bullets.remove_at(i)
	for i in range(grenades.size()-1,-1,-1):
		var g: Dictionary = grenades[i]
		var previous: Vector2 = g.p
		g.v.y += 1100*dt
		g.p += g.v*dt
		g.fuse -= dt
		if crate_health > 0 and _segment_hits(previous,g.p,crate.grow(5)):
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
	if player.health > 0 and player.position.x > 2770 and player.position.y < 500 and kills == enemies.size() and crate_health <= 0:
		completed = true
		sound("win")

func _segment_hits(a: Vector2,b: Vector2,rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var corners := [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4]) != null:
			return true
	return false

func fire_bullet(actor: CharacterBody2D) -> void:
	bullets.append({"p":actor.muzzle(),"v":Vector2(actor.facing*1100,0),"life":1.35,"enemy":actor.enemy})
	burst(actor.muzzle(),Color("ffb24b"),4)
	sound("enemy" if actor.enemy else "shot")
	if not actor.enemy:
		shake = 2

func throw_grenade(actor: CharacterBody2D) -> void:
	if grenades_left <= 0 or actor.health <= 0:
		return
	grenades_left -= 1
	grenades.append({"p":actor.position+Vector2(actor.facing*30,-110),"v":Vector2(actor.facing*420,-400),"fuse":1.45})
	sound("jump")

func explode(at: Vector2) -> void:
	burst(at,Color("ffb45d"),65)
	burst(at,Color("a5c4d5"),20)
	shake = 12
	sound("boom")
	for enemy in enemies:
		if (enemy.position+Vector2(0,-60)).distance_to(at) < 185:
			enemy.take_damage(100)
	if crate_health > 0 and crate.get_center().distance_to(at) < 190:
		_damage_crate(150)

func _damage_crate(amount: float) -> void:
	crate_health -= amount
	burst(crate.get_center(),Color("fba86c"),9)
	if crate_health <= 0 and is_instance_valid(crate_body):
		crate_body.queue_free()
		burst(crate.get_center(),Color("a9b0be"),30)
		sound("boom")

func burst(at: Vector2,color: Color,count: int) -> void:
	for i in count:
		particles.append({"p":at,"v":Vector2(rng.randf_range(-240,240),rng.randf_range(-280,80)),"life":rng.randf_range(0.15,0.7),"c":color,"s":rng.randf_range(1,4)})

func _draw() -> void:
	# Atmospheric painting plus runtime vector construction and moving mist.
	draw_texture_rect(backdrop,Rect2(camera_x*0.86-70,-300,1700,1700),false,Color(0.68,0.76,0.95))
	draw_rect(Rect2(camera_x,0,1440,900),Color(0.018,0.04,0.09,0.17))
	for i in range(10):
		var x := i*375.0 - camera_x*0.15
		if x+110 < camera_x-60 or x-30 > camera_x+1500:
			continue
		var top := 315.0 + sin(i*2.3)*90
		draw_rect(Rect2(x,top,78,440),Color("142234"))
		draw_rect(Rect2(x-9,top-12,97,15),Color("233249"))
		draw_rect(Rect2(x+5,top+8,4,426),Color("243247"))
		draw_rect(Rect2(x+68,top+8,4,426),Color("0e1c2d"))
		for seam in range(6):
			var sy := top+83+seam*58
			draw_line(Vector2(x+9,sy),Vector2(x+68,sy),Color("1f2c40"),2)
			draw_line(Vector2(x+20+seam%2*23,sy),Vector2(x+20+seam%2*23,sy+56),Color("101d2e"),2)
		for tooth in 4:
			draw_rect(Rect2(x-5+tooth*25,top-24,16,13),Color("26354a"))
		for j in 3:
			draw_rect(Rect2(x+14+j*21,top+24,7,36),Color("344760"))
			if (i+j)%3 == 0:
				draw_rect(Rect2(x+16+j*21,top+27,2,29),Color("93785f"))
		if i%2 == 0:
			draw_line(Vector2(x+45,top),Vector2(x+45,top-130),Color("223349"),4)
			_glow(Vector2(x+45,top-128),Color("f3935e"),12)
	# Suspended industrial conduits.
	for cable in range(3):
		var points := PackedVector2Array()
		for i in range(61):
			var x := i*55.0
			points.append(Vector2(x,240+cable*12+sin(x/440.0)*48))
		draw_polyline(points,Color("111d2b"),3,true)
	_draw_ladder()
	for rect in platforms:
		_draw_platform(rect)
	# Walkway piers and understructure.
	for x in range(1170,2950,260):
		if x+230 < camera_x-60 or x > camera_x+1500:
			continue
		draw_rect(Rect2(x,521,25,198),Color("16202b"))
		draw_line(Vector2(x+8,530),Vector2(x+218,702),Color("293341"),9)
		draw_line(Vector2(x+10,530),Vector2(x+218,700),Color("455064"),2)
		for y in [542,680]:
			draw_circle(Vector2(x+12,y),3,Color("747b80"))
	_draw_gate()
	if crate_health > 0:
		_draw_crate()
	else:
		for i in 9:
			draw_colored_polygon(PackedVector2Array([Vector2(2190+i*10,480),Vector2(2195+i*10,468-i%3*5),Vector2(2205+i*10,480)]),Color("414553"))
	# Route markers and localized orange practical lights.
	for x in [145,1040,1540,2450]:
		var y := 480 if x > 1140 else 720
		draw_rect(Rect2(x,y-11,44,6),Color("6c4936"))
		draw_rect(Rect2(x+3,y-10,38,3),Color("f5bb76"))
		_glow(Vector2(x+22,y-10),Color("ff9851"),38)
	_world_text(Vector2(1180,365),"01 / ASCENT",19,Color("d1b99b"))
	_world_text(Vector2(2350,365),"02 / ASHEN GATE",19,Color("d1b99b"))
	_world_text(Vector2(435,620),"JUMP",14,Color("b5c2ce"))
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
		draw_circle(g.p,7,Color("1b2633"))
		draw_arc(g.p,7,0,TAU,12,Color("a8afb1"),2,true)
		_glow(g.p,Color("ffab5d"),12 if sin(clock*24)>0 else 6)
	for p in particles:
		var color: Color = p.c
		color.a = minf(1,p.life*2)
		draw_line(p.p,p.p-p.v*0.023,color,p.s,true)
	for i in 32:
		var dust := Vector2(fposmod(i*159.7+clock*(8+i%3*7),1500)+camera_x,180+fposmod(i*67.2-clock*5,580))
		draw_circle(dust,1.3,Color(0.78,0.85,0.95,0.19+sin(clock+i)*0.1))

func _draw_platform(rect: Rect2) -> void:
	draw_rect(rect,Color("17212e"))
	if rect.size.y > 50:
		for row in range(4):
			for col in range(int(rect.size.x/90)+1):
				var x := rect.position.x+col*90-(38 if row%2 else 0)
				if x+90 < camera_x-60 or x > camera_x+1500:
					continue
				var y := rect.position.y+20+row*45
				var block := Rect2(x+2,y+2,86,41).intersection(rect)
				if block.has_area():
					draw_rect(block,Color(0.13+sin(col*8+row)*0.02,0.17,0.215))
					draw_line(block.position,block.position+Vector2(block.size.x,0),Color("354052"),1)
	else:
		for x in range(int(rect.position.x),int(rect.end.x),96):
			if x+96 < camera_x-60 or x > camera_x+1500:
				continue
			draw_rect(Rect2(x+2,rect.position.y+10,90,24),Color("2b3544"))
			draw_line(Vector2(x+8,rect.position.y+13),Vector2(x+69,rect.position.y+31),Color("141e2a"),6)
	draw_rect(Rect2(rect.position.x,rect.position.y,rect.size.x,8),Color("657180"))
	draw_rect(Rect2(rect.position.x,rect.position.y+8,rect.size.x,4),Color("0c1723"))
	draw_line(rect.position,Vector2(rect.end.x,rect.position.y),Color("a6acb5"),2)

func _draw_ladder() -> void:
	for x in [LADDER_X-22,LADDER_X+22]:
		draw_line(Vector2(x,434),Vector2(x,720),Color("0d1824"),9)
		draw_line(Vector2(x-2,434),Vector2(x-2,720),Color("8a9198"),3)
	for y in range(448,718,22):
		draw_line(Vector2(LADDER_X-23,y),Vector2(LADDER_X+23,y),Color("1a2737"),8)
		draw_line(Vector2(LADDER_X-22,y-2),Vector2(LADDER_X+22,y-2),Color("a2a09a"),3)

func _draw_crate() -> void:
	draw_rect(crate,Color("1d2935"))
	draw_rect(crate.grow(-4),Color("69717a"),false,3)
	draw_rect(crate.grow(-10),Color("374351"))
	draw_line(crate.position+Vector2(8,8),crate.end-Vector2(8,8),Color("1a222e"),8)
	draw_line(Vector2(crate.end.x-8,crate.position.y+8),Vector2(crate.position.x+8,crate.end.y-8),Color("1a222e"),8)
	draw_rect(Rect2(crate.position+Vector2(20,27),Vector2(27,23)),Color("efa85e"))
	_world_text(crate.position+Vector2(29,44),"!",19,Color("182232"))
	_world_text(crate.position+Vector2(-33,-15),"BREAK BARRIER",13,Color("d6b388"))

func _draw_gate() -> void:
	var open: bool = kills == enemies.size() and crate_health <= 0
	draw_rect(Rect2(2740,277,155,203),Color("111b28"))
	draw_rect(Rect2(2725,260,22,220),Color("465263"))
	draw_rect(Rect2(2890,260,22,220),Color("465263"))
	draw_rect(Rect2(2725,252,187,24),Color("637080"))
	var color := Color("80d8c4") if open else Color("ee995e")
	if not open:
		for x in range(2750,2890,20):
			draw_rect(Rect2(x,286,8,193),Color("3d4959"))
	else:
		draw_rect(Rect2(2750,280,138,200),Color(0.18,0.5,0.48,0.18))
	_glow(Vector2(2816,267),color,42)
	_world_text(Vector2(2744,238),"EXIT / "+("OPEN" if open else "LOCKED"),15,color)

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
