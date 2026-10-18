extends Node2D
## Split armored shutters protect the small central reactor lens.
var world: Node2D
var destroyed := false:
	set(value):
		destroyed = value
		visible = not value
		queue_redraw()
var cycle := 0.0
var opening := 0.0
var last_phase := -1
const CORE := Rect2(-14,-14,28,28)
const FACE := Rect2(-60,-57,120,114)
# All contacts share the lens depth so approaching shots can reach the core.
# Cover the complete 210-pixel housing, including its motor and ground socket.
const HOUSING_PLANE := Rect2(-14,-110,28,210)
# Timing in seconds from the start of each cycle. Keep 0 < OPEN_START < OPEN_END < PERIOD.
# OPEN_START is when fully open; OPEN_END is when closing begins.
const OPENING_DURATION := .55
const CLOSING_DURATION := .18
const PERIOD := 6.5
const OPEN_START := 0.05
const OPEN_END := 2.50
var atlas: Texture2D = preload("res://assets/hunter-relay-atlas.png")
var font: Font = ThemeDB.fallback_font
var contact_core := false

func _ready() -> void:
	z_index = 1

func restart_charge() -> void:
	cycle = 0
	last_phase = -1

func advance(dt: float) -> void:
	if destroyed:
		queue_redraw()
		return
	cycle = fmod(cycle+dt,PERIOD)
	var open_at := clampf(OPEN_START,.001,PERIOD-.002)
	var close_at := clampf(OPEN_END,open_at+.001,PERIOD-.001)
	var lift_at := maxf(0,open_at-OPENING_DURATION)
	var shut_at := minf(PERIOD,close_at+CLOSING_DURATION)
	var phase := 0 if cycle<lift_at else (1 if cycle<open_at else (2 if cycle<close_at else (3 if cycle<shut_at else 4)))
	opening = 0
	if phase == 1: opening = smoothstep(lift_at,open_at,cycle)
	elif phase == 2: opening = 1
	elif phase == 3: opening = 1-smoothstep(close_at,shut_at,cycle)
	if phase != last_phase:
		if phase == 0: world.sound("charge")
		if phase == 4: world.sound("shutter")
		last_phase = phase
	queue_redraw()

func exposed() -> bool:
	return not destroyed and opening >= .97

func arrow_entry(a: Vector2,b: Vector2) -> float:
	contact_core = false
	if destroyed: return INF
	var local_a := a-position
	var local_b := b-position
	if exposed():
		# Hit the lens itself, not the edge of a broad invisible face rectangle.
		var core_hit: float = world.segment_entry(local_a,local_b,CORE)
		if core_hit != INF:
			contact_core = true
			return core_hit
		# At ordinary frame steps the shaft approaches from the side: do not
		# stop it on the outer face before it reaches the exposed lens plane.
		# Armor above and below the lens still catches missed shots.
		var top := Rect2(CORE.position.x,HOUSING_PLANE.position.y,CORE.size.x,CORE.position.y-HOUSING_PLANE.position.y)
		var bottom := Rect2(CORE.position.x,CORE.end.y,CORE.size.x,HOUSING_PLANE.end.y-CORE.end.y)
		return minf(world.segment_entry(local_a,local_b,top),world.segment_entry(local_a,local_b,bottom))
	return world.segment_entry(local_a,local_b,HOUSING_PLANE)

func receive_arrow(at: Vector2) -> void:
	if destroyed: return
	if contact_core and exposed():
		destroyed = true
		world.destroy_yard_relay()
	else:
		world.impact(at,Color("ffc080"))
		world.sound("housing_hit")
		if not destroyed:
			world.say("RELAY ARMORED / Time your arrow for the bright central lens.")
	queue_redraw()

func panel(rect: Rect2, flipped: bool) -> void:
	# Floor clips the descending panel as it retracts into its ground socket.
	var source := Rect2(881,350,640,391)
	var visible_height := minf(rect.size.y,100-rect.position.y)
	if visible_height <= 0: return
	if flipped:
		draw_set_transform(Vector2(0,rect.position.y+rect.size.y),0,Vector2(1,-1))
		var cut := rect.size.y-visible_height
		source.position.y += source.size.y*cut/rect.size.y
		source.size.y *= visible_height/rect.size.y
		draw_texture_rect_region(atlas,Rect2(rect.position.x,cut,rect.size.x,visible_height),source)
		draw_set_transform(Vector2.ZERO)
	else:
		source.size.y *= visible_height/rect.size.y
		draw_texture_rect_region(atlas,Rect2(rect.position,Vector2(rect.size.x,visible_height)),source)

func _draw() -> void:
	if destroyed: return
	if not destroyed:
		for drone in world.drones:
			if drone.health <= 0: continue
			var end: Vector2 = drone.position-position
			var mid := end*.5+Vector2(0,-40)
			draw_line(Vector2.ZERO,mid,Color(.2,.65,.85,.14),1,true)
			draw_line(mid,end,Color(.2,.65,.85,.14),1,true)
			var t := fmod(world.clock*.55+drone.slot*.3,1.0)
			var pulse := Vector2.ZERO.lerp(mid,t*2) if t<.5 else mid.lerp(end,(t-.5)*2)
			draw_circle(pulse,1.8,Color(.5,.9,1,.65))
	# The generated housing includes the motors, armored pillars and foundation.
	draw_texture_rect_region(atlas,Rect2(-105,-110,210,210),Rect2(0,58,875,892))
	if exposed():
		draw_texture_rect(world.bullet_glow,Rect2(-25,-25,50,50),false,Color(.2,.85,1,.25+.12*sin(world.clock*12)))
	# Matching armored halves separate vertically, lower half disappears into floor.
	panel(Rect2(-63,-56-opening*66,126,60),false)
	panel(Rect2(-63,-4+opening*108,126,60),true)
	var status := "SHOOT THE LENS" if exposed() else ("RELAY CHARGING" if cycle<OPEN_START else "RELAY ARMORED")
	draw_string(font,Vector2(-68,-132),status,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("8fefff") if exposed() else Color("dbb78f"))
