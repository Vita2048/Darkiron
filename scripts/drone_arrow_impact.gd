extends Node2D
## Blue-white plasma bloom, expanding shock ring and curling electrical filaments.
var world: Node2D
var incoming := Vector2.RIGHT
var critical := false
var age := 0.0
const LIFE := 0.62
var rays: Array[Vector3] = []
var filaments: Array[PackedVector2Array] = []

func _ready() -> void:
	z_index = 30
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	add_to_group("drone_arrow_impacts")
	var active := get_tree().get_nodes_in_group("drone_arrow_impacts")
	if active.size() > 20: active[0].queue_free()
	for i in 54:
		rays.append(Vector3(world.rng.randf_range(0,TAU),world.rng.randf_range(22,95),world.rng.randf_range(.25,1.5)))
	for i in 5:
		var points := PackedVector2Array()
		for j in 25:
			var t := j/24.0
			var x := sin(t*12+i*1.8)*(4+12*t)+sin(t*29+i)*3*t
			points.append(Vector2(x+(i-2)*9*t,-t*(62+i*8)))
		filaments.append(points)

func _process(dt: float) -> void:
	if world.paused or world.completed: return
	age += dt
	if age >= LIFE: queue_free()
	queue_redraw()

func bloom(at: Vector2, size: Vector2, tint: Color) -> void:
	draw_texture_rect(world.bullet_glow,Rect2(at-size*.5,size),false,tint)

func _draw() -> void:
	var fade := pow(maxf(0,1-age/LIFE),1.5)
	var flash := exp(-age*15)
	var expansion := 1-exp(-age*19)
	var power := 1.15 if critical else .85
	# Soft tapered radial rays fade to transparent tips rather than hard spokes.
	for ray in rays:
		var axis := Vector2.from_angle(ray.x)
		var normal := axis.orthogonal()*ray.z*power
		var tip := axis*ray.y*power*(.65+expansion*.4)
		draw_polygon(PackedVector2Array([-normal,tip,normal]),PackedColorArray([Color(.1,.65,1,flash*.65),Color(0,.15,1,0),Color(.1,.65,1,flash*.65)]))
	bloom(Vector2.ZERO,Vector2(155,155)*power,Color(.02,.25,1,fade*.65))
	# A complete thin shock ring expands throughout the hit and fades to zero.
	var radius := (18+clampf(age/LIFE,0,1)*110)*power
	draw_arc(Vector2.ZERO,radius,0,TAU,96,Color(.02,.3,1,fade*.2),3,true)
	draw_arc(Vector2.ZERO,radius,0,TAU,96,Color(.05,.65,1,fade*.55),.7,true)
	draw_set_transform(Vector2.ZERO,incoming.angle()+PI/2)
	# Fine twisting ribbons lift from the white core; they decay after the flash.
	for i in filaments.size():
		var path := PackedVector2Array()
		for point in filaments[i]:
			path.append(point*power*(.45+expansion*.55)+Vector2(sin(age*18+i)*absf(point.y)*.045,0))
		draw_polyline(path,Color(0,.25,1,fade*.12),5,true)
		draw_polyline(path,Color(0,.65,1,fade*.6),1.6,true)
		draw_polyline(path,Color(.5,.95,1,fade*.7),.55,true)
	draw_set_transform(Vector2.ZERO)
	bloom(Vector2.ZERO,Vector2(95,13)*power,Color(.1,.75,1,flash))
	bloom(Vector2.ZERO,Vector2(13,95)*power,Color(.1,.75,1,flash))
	bloom(Vector2.ZERO,Vector2(40,40)*power,Color(.3,1,1,fade))
	bloom(Vector2.ZERO,Vector2(19,19)*power,Color(1,1,1,fade))
