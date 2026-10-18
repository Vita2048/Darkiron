extends Node2D
## Hunter drone from the debug gauntlet, adapted to patrol the Cinderworks yard.
var world: Node2D
var slot := 0
var health := 75.0
var age := 0.0
var arrival := 0.0
var falling := false
var fall_velocity := Vector2.ZERO
var cooldown := 2.0
var warning := 0.0
var flash := 0.0
var facing := 1.0 # Artwork faces left at positive scale.
var knockback := Vector2.ZERO
const HULL := Rect2(-58,-25,116,50)
const EYE := Rect2(-56,-10,24,26)
const YARD_LEFT := 80.0
const YARD_RIGHT := 1080.0 # Hull stays clear of the upper platform at x=1150.
var patrol_side := 1.0
const ENGINES := [Vector2(44,-6),Vector2(39,14)]
var trails: Array = [[],[]]
var sprite: Texture2D
var glow: Texture2D

func _ready() -> void:
	z_index = 3
	sprite = load("res://assets/ember-drone.png")
	glow = preload("res://scripts/raptor_flame_texture.gd").glow_texture()
	cooldown = 2.0+slot*1.15
	position = Vector2(1010+slot*30,245+slot*18)
	scale = Vector2.ONE*.12
	modulate = Color(.4,.55,.7,.3)

func advance(dt: float) -> void:
	if falling:
		fall_velocity.y += 530*dt
		position += fall_velocity*dt
		rotation += dt*(1.8+slot)
		modulate.a = maxf(0,modulate.a-dt*.35)
		queue_redraw()
		return
	if health <= 0: return
	age += dt
	if arrival < 1.0:
		arrival = clampf((age-slot*.45)/2.8,0,1)
		var t := arrival*arrival*(3-2*arrival)
		position = Vector2(1010+slot*30,245+slot*18).lerp(Vector2(760+slot*120,325+slot*40),t)
		scale = Vector2.ONE*lerpf(.12,1,t)
		modulate = Color(.4,.55,.7,.3).lerp(Color.WHITE,t)
		rotation = sin(arrival*PI)*-.18
		queue_redraw()
		return
	flash = maxf(0,flash-dt)
	var phase := age*(0.8+slot*0.12)+slot*2.1
	var target: Vector2 = world.player.position
	# Swap banks after the player crosses the abyss, rather than chasing them.
	# Retain the last side while they are above the expanded yard gap.
	if target.x >= world.YARD_RIGHT_BANK: patrol_side = -1.0
	elif target.x <= 410: patrol_side = 1.0
	var desired := Vector2(target.x+patrol_side*(600+slot*35)+sin(phase)*35,325+slot*40+sin(phase*1.7)*25)
	var left := YARD_LEFT+slot*25
	var right := YARD_RIGHT-slot*25
	var engaging: bool = target.x < 1150 and world.player.health > 0
	if engaging:
		# Leave room for the entire hull and anticipate the camera catching up.
		# The game camera shows 1440 world units, following 500 behind the player.
		var camera_left: float = maxf(world.camera_x,maxf(0,target.x-500))
		left = maxf(left,minf(YARD_RIGHT-160,camera_left+110+slot*55))
		right = minf(right,world.camera_x+1440-110-slot*55)
	var preferred_x := desired.x
	desired.x = clampf(desired.x,left,maxf(left,right))
	# Trade unavailable horizontal distance for altitude, keeping the volley visible.
	desired.y -= minf(160,absf(desired.x-preferred_x)*.6)
	desired.y = clampf(desired.y,240,440)
	# Retreat remains responsive during wind-up; never slow into the player.
	position = position.move_toward(desired,dt*520.0)
	position += knockback*dt
	position.x = clampf(position.x,YARD_LEFT,YARD_RIGHT)
	if engaging:
		position.x = clampf(position.x,minf(YARD_RIGHT,world.camera_x+85),minf(YARD_RIGHT,world.camera_x+1440-85))
	position.y = clampf(position.y,240,440)
	knockback = knockback.move_toward(Vector2.ZERO,dt*600)
	# Small dead zone prevents flickering when the player passes directly below.
	if absf(target.x-position.x) > 20:
		facing = 1.0 if target.x < position.x else -1.0
	scale.x = facing
	rotation = sin(phase*1.7)*0.12
	for i in 2:
		trails[i].push_front(to_global(ENGINES[i]))
		if trails[i].size() > 24: trails[i].pop_back()
	if engaging:
		if warning > 0:
			warning -= dt
			if warning <= 0:
				world.fire_drone(self)
				cooldown = 3.6+slot*0.35
		else:
			cooldown -= dt
			if cooldown <= 0: warning = 0.85
	else:
		warning = 0
		cooldown = maxf(cooldown,1.0)
	queue_redraw()

func power_down() -> void:
	if health <= 0: return
	health = 0
	falling = true
	warning = 0
	fall_velocity = Vector2(-70-slot*25,-35)
	queue_redraw()

func hit(amount: float, incoming := Vector2.ZERO) -> void:
	if health <= 0: return
	health = maxf(0,health-amount)
	flash = 0.18
	knockback = incoming.normalized()*150
	if health <= 0:
		visible = false
		world.drone_destroyed(self)

func hull_rect() -> Rect2:
	return global_transform * HULL

func eye_rect() -> Rect2:
	return global_transform * EYE

func _draw() -> void:
	if falling:
		draw_texture_rect(sprite,Rect2(-62,-41,124,82),false,Color(.35,.4,.45))
		return
	if health <= 0: return
	for trail in trails:
		for i in range(1,trail.size()):
			var fade: float = 1.0-float(i)/trail.size()
			draw_line(to_local(trail[i-1]),to_local(trail[i]),Color(0.15,0.65,1,fade*0.35),fade*5,true)
	draw_texture_rect(sprite,Rect2(-62,-41,124,82),false,Color(1.6,1.8,2) if flash > 0 else Color.WHITE)
	# Nozzle anchors are measured on the artwork; both rotate with the drone.
	for i in 2:
		var engine: Vector2 = ENGINES[i]
		var length := 21+5*sin(age*33+i*2.0)
		draw_texture_rect(glow,Rect2(engine-Vector2(10,10),Vector2(32,20)),false)
		draw_colored_polygon(PackedVector2Array([engine+Vector2(0,-3),engine+Vector2(length*0.65,-2),engine+Vector2(length,0),engine+Vector2(length*0.65,2),engine+Vector2(0,3)]),Color(0.2,0.65,1,0.55))
		draw_line(engine,engine+Vector2(length*0.75,0),Color("a4f1ff"),2,true)
	if warning > 0:
		var strength := 1.0-warning/0.85
		draw_arc(Vector2(-46,3),15+strength*8,0,TAU,40,Color(1,0.3,0.1,0.5+strength*0.5),2,true)
		draw_circle(Vector2(-46,3),3+strength*4,Color("ffcf94"))
	draw_rect(Rect2(-30,-45,60,3),Color("2d3948"))
	draw_rect(Rect2(-30,-45,60*health/75.0,3),Color("eea169"))
