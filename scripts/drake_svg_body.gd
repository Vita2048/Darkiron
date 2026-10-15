extends RefCounted
## Obsidian Drake SVG modules, in the existing rig's 100-unit bone space.
const TORSO = preload("res://assets/enemy-body-torso.svg")
const ARMS = preload("res://assets/drake-body-arms.svg")
const LEGS = preload("res://assets/drake-body-legs.svg")
const TAIL = preload("res://assets/drake-body-tail.svg")
const Mapping = preload("res://scripts/svg_body.gd")
const GLOVE := Rect2(1280,245,430,600)
static func supports(index: int) -> bool:
	return index in [1,3,4,6,7,8,9,10,12,13,14,15,16,17]
static func draw(canvas: Node2D,index: int) -> void:
	match index:
		1: canvas.draw_texture_rect_region(TORSO,Rect2(-48,-5,96,112),Rect2(245,80,770,1170))
		3: Mapping.module(canvas,ARMS,Rect2(50,20,610,835),Vector2(415,300),Vector2(520,735),105)
		4: Mapping.module(canvas,ARMS,Rect2(760,60,310,800),Vector2(875,173),Vector2(935,777),86)
		6: Mapping.module(canvas,LEGS,Rect2(395,5,420,710),Vector2(710,95),Vector2(580,600),90)
		7: Mapping.module(canvas,LEGS,Rect2(975,10,295,695),Vector2(1060,115),Vector2(1060,630),85)
		8:
			var region := Rect2(1490,455,535,255)
			var stretch := Vector2(100.0/535.0,(100.0-8.0/0.19)/(710.0-530.0))
			canvas.draw_texture_rect_region(LEGS,Rect2(Vector2(-5.0/0.34,8.0/0.19)+(region.position-Vector2(1590,530))*stretch,region.size*stretch),region)
		13,14: Mapping.module(canvas,ARMS,GLOVE,Vector2(1430,305),Vector2(1480,770),100)
		9,10: canvas.draw_texture_rect_region(ARMS,Rect2(-32,59,18,42),GLOVE)
		12,15,16,17:
			var regions := [Rect2(10,150,670,445),Rect2(680,275,570,315),Rect2(1270,350,470,265),Rect2(1750,80,420,550)]
			var roots := [Vector2(60,410),Vector2(720,460),Vector2(1310,505),Vector2(1790,540)]
			var ends := [Vector2(660,470),Vector2(1230,510),Vector2(1720,550),Vector2(2140,195)]
			var i := 0 if index==12 else index-14
			var region: Rect2 = regions[i]
			var stretch := Vector2(100.0/(ends[i].x-roots[i].x),100.0/region.size.y)
			# Mirror along X only, keeping dorsal spikes on top of the tail.
			canvas.draw_set_transform(Vector2.ZERO,0,Vector2(-1,1))
			canvas.draw_texture_rect_region(TAIL,Rect2((region.position-roots[i])*stretch,region.size*stretch),region)
			canvas.draw_set_transform(Vector2.ZERO)
