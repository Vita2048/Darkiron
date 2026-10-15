extends RefCounted
## SVG atlas artwork in joint-local space. Godot imports the SVGs once as textures;
## animation only changes the retained part transforms, never reparses paths.
const TORSO = preload("res://assets/darkiron-body-torso.svg")
const ARMS = preload("res://assets/darkiron-body-arms.svg")
const LEGS = preload("res://assets/darkiron-body-legs.svg")
const HEAD = preload("res://assets/darkiron-body-head.svg")
const RIFLE = preload("res://assets/darkiron-rifle.svg")
const Weapon = preload("res://scripts/hybrid_sprites.gd")
const GLOVE := Rect2(1613,232,348,422)

static func supports(index: int) -> bool:
	return index in [0,1,2,3,4,6,7,8,9,10,11,13,14]

static func module(canvas: Node2D,texture: Texture2D,region: Rect2,a: Vector2,b: Vector2,width: float) -> void:
	var axis := (b-a).normalized()
	var side := Vector2(axis.y,-axis.x)
	var corners := PackedVector2Array([region.position,Vector2(region.end.x,region.position.y),region.end,Vector2(region.position.x,region.end.y)])
	var left := INF
	var right := -INF
	for p in corners:
		left = minf(left,(p-a).dot(side))
		right = maxf(right,(p-a).dot(side))
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	for p in corners:
		vertices.append(Vector2((p-a).dot(side)*width/(right-left),(p-a).dot(axis)*100.0/a.distance_to(b)))
		uv.append(p/texture.get_size())
	canvas.draw_polygon(vertices,PackedColorArray([Color.WHITE]),uv,texture)

# Straighten the painted vambrace around its centerline instead of tilting a
# single rectangular crop. Both visible hinges stay on the bone axis.
static func forearm(canvas: Node2D) -> void:
	var rows := [Vector2(985,110),Vector2(1010,198),Vector2(1055,300),Vector2(1100,420),Vector2(1130,520),Vector2(1123,593),Vector2(1123,676)]
	for i in range(rows.size()-1):
		var vertices := PackedVector2Array()
		var uv := PackedVector2Array()
		for corner in [Vector2(968,rows[i].y),Vector2(1255,rows[i].y),Vector2(1255,rows[i+1].y),Vector2(968,rows[i+1].y)]:
			var center: float = rows[i].x if corner.y==rows[i].y else rows[i+1].x
			vertices.append(Vector2((corner.x-center)*78.0/350.0,(corner.y-198.0)*100.0/395.0))
			uv.append(corner/ARMS.get_size())
		canvas.draw_polygon(vertices,PackedColorArray([Color.WHITE]),uv,ARMS)

static func draw(canvas: Node2D,index: int) -> void:
	match index:
		0: canvas.draw_texture_rect_region(HEAD,Rect2(-45,-3,90,103),Rect2(273,124,739,936))
		1: canvas.draw_texture_rect_region(TORSO,Rect2(-46,-5,92,111),Rect2(323,53,724,1108))
		2,11: canvas.draw_texture_rect_region(RIFLE,Weapon.rifle_rect(false),Weapon.source(false))
		# Joint centers, rather than rectangular atlas edges, define each bone.
		3: module(canvas,ARMS,Rect2(298,54,400,622),Vector2(510,245),Vector2(453,603),105)
		4: forearm(canvas)
		6: module(canvas,LEGS,Rect2(253,9,324,694),Vector2(415,72),Vector2(456,620),72)
		7: module(canvas,LEGS,Rect2(926,12,286,685),Vector2(1045,103),Vector2(1087,634),75)
		8:
			# The shin owns the ankle cuff. Keep the boot below it and rotate
			# about its visible hinge (1648,508), at rig-local (-5,8).
			# Bottom stays at y=100: sole contact remains 19-8 = 11 pixels.
			var source := Rect2(1537,460,531,234)
			var stretch := Vector2(100.0/531.0,(100.0-8.0/0.19)/(694.0-508.0))
			var pivot := Vector2(-5.0/0.34,8.0/0.19)
			canvas.draw_texture_rect_region(LEGS,Rect2(pivot+(source.position-Vector2(1648,508))*stretch,source.size*stretch),source)
		# Attach the glove at the center of its wrist cuff, not its atlas corner.
		13: module(canvas,ARMS,GLOVE,Vector2(1740,300),Vector2(1790,620),100)
		14:
			# Far hand shows the opposite side; avoid two identical outward palms.
			canvas.draw_set_transform(Vector2.ZERO,0,Vector2(-1,1))
			module(canvas,ARMS,GLOVE,Vector2(1740,300),Vector2(1790,620),100)
			canvas.draw_set_transform(Vector2.ZERO)
		9,10:
			canvas.draw_texture_rect_region(ARMS,Rect2(-32,59,17,44),GLOVE)
			var tip := -18.0 if index==10 else -15.0
			var points := PackedVector2Array([Vector2(-24,70),Vector2(-21,63),Vector2(tip,62),Vector2(tip,69),Vector2(-21,73)])
			canvas.draw_polyline(points,Color("0c121a"),4.8,true)
			canvas.draw_polyline(points,Color("8495a1"),2.5,true)
