extends SceneTree

var game: Node2D
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func snapshot(name: String) -> void:
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://"+name+".png")

func check(condition: bool,message: String) -> void:
	if condition:
		print("PASS: "+message)
	else:
		push_error("FAIL: "+message)
		failures += 1

func walk_to(x: float,limit := 650) -> void:
	Input.action_press("right")
	for i in limit:
		await physics_frame
		if game.player.position.x >= x or game.player.health <= 0:
			break
	Input.action_release("right")
	await frames(12)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(12)
	check(game.player.is_on_floor(),"player spawns on solid ground")
	await walk_to(355)
	check(game.player.position.x>350,"movement responds to input")
	Input.action_press("right")
	Input.action_press("jump")
	await frames(20)
	check(game.player.position.y<640,"jump reaches above the rubble")
	await snapshot("preview-jump")
	Input.action_release("jump")
	await frames(64)
	Input.action_release("right")
	await frames(20)
	check(game.player.position.x>550 and game.player.is_on_floor(),"jump crosses rubble and lands")
	Input.action_press("shoot")
	await frames(150)
	Input.action_release("shoot")
	check(game.kills==1,"shotgun kills first guard through actual projectile collision")
	await walk_to(1250)
	Input.action_press("toggle_weapon")
	await frames(2)
	Input.action_release("toggle_weapon")
	await frames(20)
	Input.action_press("up")
	await frames(125)
	Input.action_release("up")
	await frames(12)
	check(absf(game.player.position.y-480)<3 and game.player.is_on_floor(),"ladder exits onto upper walkway")
	# Check a return trip, including collision restoration after descent.
	Input.action_press("down")
	await frames(120)
	Input.action_release("down")
	await frames(12)
	check(absf(game.player.position.y-720)<3,"ladder descends to lower ground")
	Input.action_press("up")
	await frames(120)
	Input.action_release("up")
	await frames(12)
	Input.action_press("toggle_weapon")
	await frames(2)
	Input.action_release("toggle_weapon")
	await frames(20)
	Input.action_press("shoot")
	await frames(155)
	Input.action_release("shoot")
	check(game.kills==2,"second guard can be defeated on upper walkway")
	await walk_to(1750)
	await snapshot("preview-upper")
	Input.action_press("grenade")
	await frames(2)
	Input.action_release("grenade")
	await frames(115)
	check(game.grenades_left==4,"grenade input consumes one grenade")
	check(game.crate_health<=0,"grenade destroys barrier")
	await walk_to(2820)
	check(game.completed,"full encounter reaches completion gate")
	check(game.player.health>0,"full encounter is survivable")
	await snapshot("preview-complete")
	game.completed = false
	game.player.take_damage(1000)
	await frames(45)
	check(game.player.health==0,"lethal damage enters death state")
	game.player.position = Vector2(260,720)
	var before: Vector2 = game.player.position
	Input.action_press("right")
	await frames(10)
	Input.action_release("right")
	check(absf(game.player.position.x-before.x)<2,"dead player cannot move with input")
	Input.action_press("restart")
	await frames(3)
	Input.action_release("restart")
	game = current_scene
	await frames(12)
	check(game.player.health==100 and game.kills==0 and game.grenades_left==5,"restart resets health, enemies, and grenade inventory")
	print("PLAYTHROUGH RESULT: ",failures," failure(s)")
	game.queue_free()
	await frames(3)
	quit(0 if failures==0 else 1)
