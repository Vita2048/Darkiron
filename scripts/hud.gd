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
	text(Vector2(42,66),"THE CINDERWORKS  /  CHAPTER 01",12,Color("8b9bad"))
	text(Vector2(458,37),"VITALS",12,Color("8b9bad"))
	for i in range(10):
		draw_rect(Rect2(459+i*17,51,12,17),Color("e2ad78") if world.player.health>i*10 else Color("293744"))
	text(Vector2(646,66),str(int(world.player.health))+"%",16)
	var state := "IN COVER" if world.player.in_cover else ("SELECT WEAPON" if world.weapon_selecting else ("WEAPON DRAWN" if world.player.weapon_drawn else "WEAPON SHEATHED"))
	text(Vector2(761,37),state,12,Color("e7b680"))
	# Weapon status: selected weapon, then the grenade icon with its count.
	var shown: int = world.weapon_options if world.weapon_selecting else world.weapon_index
	var weapon: String = world.weapon_name(world.weapons[shown])
	text(Vector2(761,65),weapon,16)
	var width: float = font.get_string_size(weapon,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
	draw_texture_rect_region(world.equipment,Rect2(761+width+16,47,11,20),Rect2(900,25,350,675))
	text(Vector2(761+width+32,65),str(world.grenades_left),16)
	if world.weapon_selecting and world.weapons.size() > 1:
		var panel_h: int = world.weapons.size()*21+22
		draw_rect(Rect2(755,72,192,panel_h),Color(0.025,0.045,0.075,0.92))
		draw_rect(Rect2(755,72,3,panel_h),Color("e5aa72"))
		for i in world.weapons.size():
			var picked: bool = i == world.weapon_options
			text(Vector2(770,72+18+i*21),world.weapon_name(world.weapons[i]),13 if picked else 12,Color("f1d5b4") if picked else Color("9fb2c5"))
		text(Vector2(770,72+panel_h+13),"[ ]  BROWSE      ENTER  CONFIRM",11,Color("8b9bad"))
	text(Vector2(1125,37),"BLAST SEALS / "+str(world.seals_broken)+" OF 2",12,Color("8b9bad"))
	text(Vector2(1125,65),str(world.kills)+" / "+str(world.total_targets)+" TARGETS",16,Color("e7b680"))
	text(Vector2(1125,91),"%d FPS  /  %.1f ms" % [roundi(fps),1000.0/maxf(fps,1)],13,Color("8fe3bc"))
	# Bottom panel stays out of the traversable portion of the scene.
	draw_rect(Rect2(0,814,1440,86),Color(0.025,0.044,0.072,0.96))
	draw_line(Vector2(40,814),Vector2(1400,814),Color("354051"),1)
	text(Vector2(40,847),"ARROWS  MOVE / CLIMB     SHIFT  RUN     SPACE  JUMP",15)
	text(Vector2(40,877),"S DRAW/SHEATHE   [ ]/ENTER WEAPON   UP COVER   DOWN CROUCH   LMB DRAG BOW (RELEASE FIRES)   J/CLICK RIFLE   G GRENADE",14,Color("acbaca"))
	text(Vector2(1057,847),"R  RESTART     ESC  PAUSE",14,Color("acbaca"))
	text(Vector2(1057,877),"F11  FULLSCREEN     M  SOUND",14,Color("acbaca"))
	var prompt := "Break both blast seals and clear the furnace gate."
	var ladder: Vector3 = world.ladder_at(world.player.position)
	if world.weapon_selecting:
		prompt = "Choose a weapon: [ and ] to browse, ENTER to confirm."
	elif world.player.position.x<1100:
		prompt = "Cross the yard. UP takes cover from the drone patrol. The rifle waits past the abyss."
	elif world.player.position.x<2200 and world.seals_broken==0:
		prompt = "Collect bombs from the amber chest. Throw G near the blast seal."
	elif world.player.position.x<4300:
		prompt = "Reach the next blast seal. The upper alcove holds extra supplies."
	elif world.kills<world.total_targets:
		prompt = "Climb to the furnace. Clear the remaining targets to open the gate."
	elif world.seals_broken==2:
		prompt = "FURNACE GATE OPEN / Reach the cyan portal."
	if ladder!=Vector3.ZERO:
		prompt = "S to sheathe before climbing." if world.player.weapon_drawn else "UP / DOWN to climb. SPACE to jump away."
	if world.player.in_cover:
		prompt = "IN COVER / Let enemy fire pass, then release UP and return fire."
	if world.notice_time>0:
		prompt = world.notice
	draw_rect(Rect2(40,128,850,42),Color(0.025,0.045,0.075,0.8))
	draw_rect(Rect2(40,128,3,42),Color("e5aa72"))
	text(Vector2(57,155),prompt,16)
	# Bow draw meter follows Darkiron in screen space (the camera keeps 1:1 world y).
	if world.has_method("current_weapon") and world.current_weapon() == "BOW" \
			and world.player.health>0 and world.player.weapon_drawn \
			and not world.player.in_cover and not world.player.climbing and not world.weapon_selecting:
		var at: Vector2 = world.player.position-Vector2(world.camera_x,0)
		draw_rect(Rect2(at.x-65,at.y-26,130,5),Color("293c51"))
		draw_rect(Rect2(at.x-65,at.y-26,130*world.player.bow_charge,5),Color("5cdcff"))
		text(Vector2(at.x-65,at.y-32),"DRAW %d%%" % int(world.player.bow_charge*100),12,Color("83def7"))
	if world.completed or world.player.health<=0 or world.paused:
		draw_rect(Rect2(0,104,1440,710),Color(0.02,0.035,0.06,0.76))
		draw_rect(Rect2(400,290,640,277),Color("121f2e"))
		draw_line(Vector2(400,290),Vector2(1040,290),Color("d7a477"),2)
		var title := "CINDERWORKS CLEARED" if world.completed else ("DARKIRON HAS FALLEN" if world.player.health<=0 else "PAUSED")
		text(Vector2(457,358),title,32,Color("f1d5b4"))
		var subtitle := "The seals are broken. The furnace road is open." if world.completed else ("The outpost takes no prisoners. Try another approach." if world.player.health<=0 else "Your journey waits.")
		text(Vector2(457,410),subtitle,17)
		text(Vector2(457,501),"ESC  RESUME   /   R  RESTART" if world.paused else ("ENTER  CONTINUE   /   R  RESTART" if world.player.health<=0 else "PRESS R TO PLAY AGAIN"),18,Color("e8b47e"))
