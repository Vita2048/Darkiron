extends RefCounted
## Shared feather geometry for both nocked and flying arrows, relative to the tip.
static func draw_feathers(canvas: Node2D, tail: Vector2) -> void:
	for side in [-1.0,1.0]:
		var feather := PackedVector2Array([tail+Vector2(3,0),tail+Vector2(5,side*5),tail+Vector2(14,side*4),tail+Vector2(20,0)])
		canvas.draw_colored_polygon(feather,Color("b1a99a") if side < 0 else Color("6e777b"))
		for x in range(6,16,3):
			canvas.draw_line(tail+Vector2(x,0),tail+Vector2(x-2,side*3),Color("424d56"),0.65,true)
	canvas.draw_line(tail,tail+Vector2(22,0),Color("adb6bb"),1,true)
