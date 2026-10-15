extends RefCounted
## Rigid textured modules mapped from painted joint centers to the existing bones.
const TORSO = preload("res://assets/darkiron-body-torso.png")
const ARMS = preload("res://assets/darkiron-body-arms.png")
const LEGS = preload("res://assets/darkiron-body-legs.png")
const GLOVE := Rect2(1613,232,348,422)
static func supports(index: int) -> bool:
	return index in [1,3,4,6,7,8,9,10,13]
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
static func draw(canvas: Node2D,index: int) -> void:
	match index:
		1: canvas.draw_texture_rect_region(TORSO,Rect2(-46,-5,92,111),Rect2(323,53,724,1108))
		3: module(canvas,ARMS,Rect2(298,54,400,622),Vector2(510,245),Vector2(453,603),115)
		4: module(canvas,ARMS,Rect2(968,110,287,566),Vector2(1030,195),Vector2(1168,629),85)
		6: module(canvas,LEGS,Rect2(253,9,324,694),Vector2(415,72),Vector2(456,620),72)
		7: module(canvas,LEGS,Rect2(926,12,286,685),Vector2(1045,103),Vector2(1087,634),75)
		8: canvas.draw_texture_rect_region(LEGS,Rect2(-46,0,100,100),Rect2(1537,336,531,358))
		13: canvas.draw_texture_rect_region(ARMS,Rect2(-50,-15,100,100),GLOVE)
		9,10:
			canvas.draw_texture_rect_region(ARMS,Rect2(-32,59,17,44),GLOVE)
			# The raster palm is rigid; a small articulated finger closes over the trigger.
			var tip := -18.0 if index==10 else -15.0
			var points := PackedVector2Array([Vector2(-24,70),Vector2(-21,63),Vector2(tip,62),Vector2(tip,69),Vector2(-21,73)])
			canvas.draw_polyline(points,Color("0c121a"),4.8,true)
			canvas.draw_polyline(points,Color("8495a1"),2.5,true)
