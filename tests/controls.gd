extends SceneTree

var game: Node2D
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func check(condition: bool,message: String) -> void:
	if condition:
		print("PASS: "+message)
	else:
		push_error("FAIL: "+message)
		failures += 1

func key(code: int,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func snapshot(name: String) -> void:
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://"+name+".png")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(12)
	for enemy in game.enemies:
		enemy.set_physics_process(false)
	var p: CharacterBody2D = game.player
	game.grenades_left = 5 # Isolate cover blocking from pickup progression.
	var initial_x: float = p.position.x
	key(KEY_A,true)
	key(KEY_W,true)
	key(KEY_D,true)
	await frames(10)
	check(absf(p.position.x-initial_x)<1 and not p.climbing and not p.in_cover,"WASD no longer controls movement or cover")
	key(KEY_A,false)
	key(KEY_W,false)
	key(KEY_D,false)
	key(KEY_S,true)
	await frames(20)
	check(not p.weapon_drawn and not p.crouching and p.weapon_blend==0,"S sheathes shotgun without crouching")
	await frames(15)
	check(not p.weapon_drawn,"holding S does not repeatedly toggle weapon")
	key(KEY_S,false)
	Input.action_press("shoot")
	await frames(5)
	check(game.bullets.is_empty() and p.recoil==0,"sheathed weapon cannot fire")
	Input.action_release("shoot")
	key(KEY_S,true)
	await frames(2)
	Input.action_press("shoot")
	await frames(3)
	check(game.bullets.is_empty(),"cannot fire during draw transition")
	key(KEY_S,false)
	await frames(20)
	check(p.weapon_drawn and not game.bullets.is_empty(),"drawn weapon fires after transition")
	Input.action_release("shoot")
	game.bullets.clear()
	await frames(30)
	key(KEY_UP,true)
	await frames(15)
	check(p.in_cover,"UP enters cover away from ladders")
	await snapshot("preview-cover")
	var before: Vector2 = p.position
	key(KEY_RIGHT,true)
	Input.action_press("shoot")
	Input.action_press("grenade")
	await frames(12)
	check(p.position.distance_to(before)<1 and game.bullets.is_empty() and game.grenades_left==5,"cover blocks movement, firing, and grenade throws")
	key(KEY_RIGHT,false)
	Input.action_release("shoot")
	Input.action_release("grenade")
	var guard: CharacterBody2D = game.enemies[0]
	guard.position = Vector2(600,720)
	guard.facing = -1
	guard.fire()
	await frames(20)
	check(p.health==100 and game.bullets.size()==1,"enemy bullet passes through cover without damage or being consumed")
	key(KEY_UP,false)
	await frames(2)
	check(not p.in_cover,"releasing UP exits cover")
	guard.fire()
	await frames(20)
	check(p.health==87,"same enemy shot damages player outside cover")
	key(KEY_UP,true)
	await frames(2)
	key(KEY_S,true)
	await frames(20)
	key(KEY_S,false)
	check(p.in_cover and not p.weapon_drawn,"sheathed cover remains functional")
	await snapshot("preview-cover-sheathed")
	key(KEY_UP,false)
	Input.action_press("jump")
	await frames(8)
	key(KEY_UP,true)
	await frames(3)
	check(not p.in_cover,"cover is unavailable in midair")
	key(KEY_UP,false)
	Input.action_release("jump")
	await frames(50)
	p.position = Vector2(1250,720)
	key(KEY_S,true)
	await frames(20)
	key(KEY_S,false)
	key(KEY_UP,true)
	await frames(15)
	check(not p.climbing and p.in_cover and p.position.y>710,"drawn weapon takes cover at ladder instead of climbing")
	key(KEY_S,true)
	await frames(20)
	key(KEY_S,false)
	await frames(15)
	check(p.climbing and not p.in_cover and p.position.y<710,"ladder climbing takes priority over cover")
	key(KEY_S,true)
	await frames(3)
	key(KEY_S,false)
	check(not p.weapon_drawn and p.climbing,"cannot draw weapon while climbing")
	key(KEY_UP,false)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(80)
	p.position = Vector2(1620,720)
	await frames(10)
	key(KEY_RIGHT,true)
	Input.action_press("run")
	await frames(25)
	check(p.running and p.velocity.x>290,"Shift plus arrow activates full running speed")
	for i in range(4):
		await snapshot("preview-run-"+str(i))
		await frames(9)
	Input.action_release("run")
	key(KEY_RIGHT,false)
	await frames(20)
	check(not p.running and absf(p.velocity.x)<1,"run ends cleanly on input release")
	guard.position = Vector2(850,720)
	guard.set_physics_process(true)
	guard.take_damage(1000)
	await frames(90)
	check(is_instance_valid(guard.dropped_weapon) and guard.dropped_weapon.settled,"dead guard drops weapon onto floor")
	check(not guard.weapon_drawn and guard.weapon_blend==0,"dead guard no longer holds weapon")
	p.position = Vector2(guard.position.x+200,720)
	await frames(30)
	await snapshot("preview-death")
	print("CONTROLS RESULT: ",failures," failure(s)")
	game.queue_free()
	await frames(3)
	quit(0 if failures==0 else 1)


