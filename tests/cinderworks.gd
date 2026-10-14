extends SceneTree
var game: Node2D
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool,message: String) -> void:
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures += 1
func press(action: String,n: int) -> void:
	Input.action_press(action)
	await frames(n)
	Input.action_release(action)
	await frames(2)
func walk_to(x: float,shoot := true) -> void:
	var direction := "right" if x>game.player.position.x else "left"
	Input.action_press(direction)
	if shoot: Input.action_press("shoot")
	for i in 1700:
		await physics_frame
		if absf(game.player.position.x-x)<5 or game.player.health<=0: break
	Input.action_release(direction)
	Input.action_release("shoot")
	await frames(10)
	if game.player.health<=0: print("DIED at ",game.player.position," kills ",game.kills)
	check(absf(game.player.position.x-x)<35,"route reaches x="+str(x))
func climb() -> void:
	if game.player.weapon_drawn: await press("toggle_weapon",20)
	await press("up",125)
	await frames(10)
	check(absf(game.player.position.y-480)<4,"ladder reaches upper gallery")
	await press("toggle_weapon",20)
func jump_right() -> void:
	Input.action_press("right")
	Input.action_press("shoot")
	await press("jump",38)
	await frames(28)
	Input.action_release("right")
	Input.action_release("shoot")
	await frames(10)
func capture(name: String) -> void:
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview-"+name+".png")
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(15)
	check(game.grenades_left==0,"begin with no bombs: pickups matter")
	await walk_to(385)
	await jump_right()
	await press("shoot",130)
	await walk_to(1250)
	await climb()
	await walk_to(1550)
	check(game.grenades_left==3,"upper cache supplies three bombs")
	await capture("gallery")
	await press("shoot",140)
	await walk_to(1850)
	await press("shoot",100)
	check(game.seals_broken==0,"bullets cannot break a reinforced blast seal")
	await press("grenade",2)
	await frames(105)
	check(game.seals_broken==1,"actual thrown bomb breaks first seal")
	await walk_to(2630)
	check(game.checkpoint_active,"relay checkpoint activates after first breach")
	await walk_to(2895)
	await frames(35)
	await jump_right()
	await press("shoot",130)
	await walk_to(3400)
	await climb()
	await walk_to(3700)
	check(game.grenades_left>=3,"optional upper supply alcove rewards exploration")
	await capture("alcove")
	await walk_to(3940)
	await frames(40)
	# Return to a safe throwing distance from the second blast seal.
	await walk_to(3900)
	game.player.facing = 1
	await press("grenade",2)
	await frames(105)
	check(game.seals_broken==2,"actual thrown bomb breaks second seal")
	await walk_to(4950)
	await capture("furnace-yard")
	await walk_to(5100)
	await climb()
	await press("shoot",150)
	await walk_to(5960)
	check(game.kills==6,"all six guards defeated through normal combat")
	check(game.completed and game.player.health>0,"complete redesigned level alive")
	await capture("furnace-gate")
	game.completed = false
	game.player.take_damage(1000)
	await frames(30)
	await press("continue_game",2)
	check(game.player.health==100 and game.player.position.distance_to(game.checkpoint)<5,"ENTER respawns at checkpoint")
	check(game.seals_broken==2 and game.kills==6,"checkpoint retains earned progress")
	# Pickups remain consumed after death, waiting and returning to the same location.
	game.player.position = game.caches[0].p
	game.grenades_left = 0
	await frames(750)
	check(game.caches[0].taken and game.grenades_left==0,"collected bombs disappear permanently and cannot be collected twice")
	print("CINDERWORKS RESULT: ",failures," failure(s)")
	game.queue_free()
	await frames(3)
	quit(0 if failures==0 else 1)

