extends Node2D
## Raster environment layers; gameplay collision remains authored separately.
var world: Node2D
var backdrop = preload("res://assets/cinderworks-background.png")
var masonry = preload("res://assets/cinderworks-platform.png")
var equipment = preload("res://assets/cinderworks-equipment.png")
var props = preload("res://assets/cinderworks-props.png")
var stone_region := Rect2()
var font: Font = ThemeDB.fallback_font
var regions := [Rect2(40,0,550,600),Rect2(685,190,535,400),Rect2(40,635,550,600),Rect2(770,630,370,600)]
func _ready() -> void:
	stone_region = Rect2(0,145,2172,475)
func _process(_dt: float) -> void:
	queue_redraw()
func label(at: Vector2,value: String,size := 14,color := Color("c5c8c7")) -> void:
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func prop(index: int,rect: Rect2,tint := Color.WHITE) -> void:
	var source: Rect2 = regions[index]
	var factor := Vector2(props.get_size())/1280.0
	source.position *= factor
	source.size *= factor
	draw_texture_rect_region(props,rect,source,tint)
func visible_x(x: float,width := 0.0) -> bool:
	return x+width>world.camera_x-100 and x<world.camera_x+1540
func _draw() -> void:
	draw_texture_rect(backdrop,Rect2(world.camera_x*0.74-20,-50,2740,915),false,Color("bdc8d9"))
	draw_rect(Rect2(world.camera_x,0,1440,900),Color(0.015,0.025,0.05,0.18))
	for gap in [Vector2(410,525),Vector2(2920,3030)]:
		draw_rect(Rect2(gap.x,720,gap.y-gap.x,400),Color("080d16"))
		for edge in [gap.x-18,gap.y]:
			draw_rect(Rect2(edge,720,18,7),Color("e6a354"))
			draw_texture_rect(world.bullet_glow,Rect2(edge-12,710,40,35),false,Color(1,0.35,0.07,0.4))
	for rect in world.platforms:
		var x: float = rect.position.x
		while x<rect.end.x:
			var width := minf(620,rect.end.x-x)
			if visible_x(x,width):
				var height := 200.0 if rect.size.y>100 else (100.0 if rect.size.x>200 else 75.0)
				var source := stone_region
				source.size.x *= width/620.0 if rect.size.x>200 else 1.0
				draw_texture_rect_region(masonry,Rect2(x,rect.position.y,width,height),source)
				draw_line(Vector2(x,rect.position.y),Vector2(x+width,rect.position.y),Color("8d9fa5"),2,true)
			x += width
	for ladder in world.ladders:
		if not visible_x(ladder.x,45): continue
		var y: float = ladder.y-40
		while y<ladder.z:
			var height := minf(93.3,ladder.z-y)
			draw_texture_rect_region(equipment,Rect2(ladder.x-30,y,60,height),Rect2(182,40,418,650*height/93.3))
			y += height
	for barrier in world.barriers:
		var rect: Rect2 = barrier.rect
		if not visible_x(rect.position.x,rect.size.x): continue
		if not barrier.destroyed:
			prop(2,Rect2(rect.position.x-12,rect.position.y-4,rect.size.x+24,rect.size.y+4))
			label(rect.position+Vector2(-38,-25),"BLAST SEAL",14,Color("ffc58c"))
			label(rect.position+Vector2(-44,-7),"EXPLOSIVES ONLY",11,Color("ee9c70"))
		else:
			for i in 7:
				var at := Vector2(rect.position.x-15+i*17,rect.end.y)
				draw_colored_polygon(PackedVector2Array([at,at+Vector2(8,-9-i%3*5),at+Vector2(21,0)]),Color("58616a"))
	for cache in world.caches:
		if not visible_x(cache.p.x,100): continue
		prop(1,Rect2(cache.p-Vector2(48,72),Vector2(96,72)),Color.WHITE if cache.cooldown<=0 else Color("68727d"))
		label(cache.p+Vector2(-55,-86),"BOMBS +3" if cache.cooldown<=0 else "REFILL %ds" % ceili(cache.cooldown),13,Color("ffd295"))
	for med in world.meds:
		if med.taken or not visible_x(med.p.x): continue
		var at: Vector2 = med.p+Vector2(0,-26-sin(world.clock*2)*3)
		draw_texture_rect(world.bullet_glow,Rect2(at-Vector2(24,24),Vector2(48,48)),false,Color("62ffc3"))
		draw_texture_rect_region(equipment,Rect2(at-Vector2(28,22),Vector2(56,45)),Rect2(1395,95,745,600))
	prop(3,Rect2(2750,525,100,195),Color.WHITE if world.checkpoint_active else Color("576d7c"))
	label(Vector2(2730,510),"RELAY / CHECKPOINT",12,Color("86e0dc"))
	prop(0,Rect2(5840,170,290,310))
	var unlocked: bool = world.seals_broken==2 and world.kills==world.enemies.size()
	label(Vector2(5860,145),"FURNACE GATE / "+("OPEN" if unlocked else "LOCKED"),14,Color("9ee8df") if unlocked else Color("edba8e"))
	if not unlocked:
		for y in range(315,460,24):
			draw_line(Vector2(5940,y),Vector2(6030,y),Color(1,0.38,0.16,0.6),2,true)
	# Environmental signposts; labels explain interactions rather than decoration.
	for sign in [[Vector2(100,510),"01 / THE OUTER YARD"],[Vector2(1440,265),"02 / DEMOLITION GALLERY"],[Vector2(2940,405),"03 / THE CINDERWORKS"],[Vector2(3380,275),"SUPPLY ALCOVE"],[Vector2(5190,255),"04 / FURNACE APPROACH"]]:
		if visible_x(sign[0].x,260): label(sign[0],sign[1],18,Color("dbb78f"))
	label(Vector2(420,620),"SPACE / JUMP",12)
	label(Vector2(1125,370),"S / SHEATHE   UP / CLIMB",12,Color("c1d8d9"))
	# Amber practical lights visually connect the route.
	for x in [150,970,1620,2420,3100,3900,4560,5300,5750]:
		var y := 480 if (x>=1150 and x<2750) or x>=5000 else 720
		if visible_x(x):
			draw_texture_rect(world.bullet_glow,Rect2(x-30,y-47,70,60),false,Color("ff9948"))
			draw_rect(Rect2(x,y-6,24,3),Color("ffcc8a"))
