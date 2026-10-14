extends Node2D

var world: Node2D
var font: Font = ThemeDB.fallback_font

var elapsed := 0.0
var frames := 0
var fps := 0.0

func _process(_dt: float) -> void:
	elapsed += _dt
	frames += 1
	if elapsed >= 0.5:
		fps = frames/elapsed
		frames = 0
		elapsed = 0
	queue_redraw()

func text(at: Vector2,value: String,size := 18,color := Color("d5deea")) -> void:
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw() -> void:
	draw_rect(Rect2(0,0,1440,104),Color(0.025,0.044,0.072,0.9))
	draw_line(Vector2(40,103),Vector2(1400,103),Color("354051"),1)
	text(Vector2(40,38),"D A R K I R O N",25,Color("f3dec1"))
	text(Vector2(42,66),"ASHEN GATE  /  VECTOR EDITION 06",12,Color("8b9bad"))
	text(Vector2(458,37),"VITALS",12,Color("8b9bad"))
	for i in range(10):
		draw_rect(Rect2(459+i*17,51,12,17),Color("e2ad78") if world.player.health>i*10 else Color("293744"))
	text(Vector2(646,66),str(int(world.player.health))+"%",16)
	var state := "IN COVER" if world.player.in_cover else ("WEAPON DRAWN" if world.player.weapon_drawn else "WEAPON SHEATHED")
	text(Vector2(761,37),state,12,Color("e7b680"))
	text(Vector2(761,65),"SHOTGUN  /  "+str(world.grenades_left)+" GRENADES",16)
	text(Vector2(1125,37),"OUTPOST SECURITY",12,Color("8b9bad"))
	text(Vector2(1125,65),str(world.kills)+" / 2  NEUTRALIZED",16,Color("e7b680"))
	text(Vector2(1125,91),"%d FPS  /  %.1f ms" % [roundi(fps),1000.0/maxf(fps,1)],13,Color("8fe3bc"))
	# Bottom panel stays out of the traversable portion of the scene.
	draw_rect(Rect2(0,814,1440,86),Color(0.025,0.044,0.072,0.96))
	draw_line(Vector2(40,814),Vector2(1400,814),Color("354051"),1)
	text(Vector2(40,847),"ARROWS  MOVE / CLIMB     SHIFT  RUN     SPACE  JUMP",15)
	text(Vector2(40,877),"S  DRAW / SHEATHE     UP  COVER     DOWN  CROUCH     J / CLICK  SHOOT     G  GRENADE",14,Color("acbaca"))
	text(Vector2(1057,847),"R  RESTART     ESC  PAUSE",14,Color("acbaca"))
	text(Vector2(1057,877),"F11  FULLSCREEN     M  SOUND",14,Color("acbaca"))
	var prompt := "Reach the upper gate. Clear the guards and break the barrier."
	if world.player.position.x<540:
		prompt = "Cross the outpost. Jump the rubble, then engage the first guard."
	elif absf(world.player.position.x-world.LADDER_X)<120 and world.player.position.y>490:
		prompt = "S to sheathe your weapon before climbing." if world.player.weapon_drawn else "Hold UP to climb. DOWN to descend. SPACE to jump away."
	elif world.kills == 2 and world.crate_health <= 0:
		prompt = "Security cleared. Enter the illuminated gate."
	elif world.kills == 2 and world.crate_health > 0:
		prompt = "Break the barrier: throw G from a distance, or crouch and shoot."
	if world.player.in_cover:
		prompt = "IN COVER / Bullets pass you. Release UP to move or return fire."
	elif not world.player.weapon_drawn and absf(world.player.position.x-world.LADDER_X)>=120:
		prompt = "Weapon sheathed. S to draw. SHIFT + LEFT / RIGHT to run."
	draw_rect(Rect2(40,128,680,42),Color(0.025,0.045,0.075,0.8))
	draw_rect(Rect2(40,128,3,42),Color("e5aa72"))
	text(Vector2(57,155),prompt,16)
	if world.completed or world.player.health<=0 or world.paused:
		draw_rect(Rect2(0,104,1440,710),Color(0.02,0.035,0.06,0.76))
		draw_rect(Rect2(400,290,640,277),Color("121f2e"))
		draw_line(Vector2(400,290),Vector2(1040,290),Color("d7a477"),2)
		var title := "OUTPOST CLEARED" if world.completed else ("DARKIRON HAS FALLEN" if world.player.health<=0 else "PAUSED")
		text(Vector2(457,358),title,32,Color("f1d5b4"))
		var subtitle := "The Ashen Gate is yours. First encounter complete." if world.completed else ("The outpost takes no prisoners. Try another approach." if world.player.health<=0 else "Your journey waits.")
		text(Vector2(457,410),subtitle,17)
		text(Vector2(457,501),"ESC  RESUME   /   R  RESTART" if world.paused else "PRESS R TO PLAY AGAIN",18,Color("e8b47e"))
