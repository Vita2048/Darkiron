extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in count: await physics_frame
func floor_at(game: Node2D,x: float) -> bool:
	var query := PhysicsRayQueryParameters2D.create(Vector2(x,700),Vector2(x,750),1)
	return not game.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
func capture(game: Node2D,name: String) -> void:
	if not "--visual" in OS.get_cmdline_user_args(): return
	game.queue_redraw()
	game.relay.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/bridge-"+name+".png")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	for enemy in game.enemies: enemy.set_physics_process(false)
	await frames(2)
	check(not floor_at(game,600) and not floor_at(game,800),"Cut section has no initial collision")
	check(floor_at(game,900),"Right bank remains solid")
	check(game.rifle_pickups[0].p.x>game.YARD_RIGHT_BANK,"Rifle moved onto right bank")
	game._update_yard_bridge(10)
	check(game.bridge_progress==0,"Bridge waits for relay destruction")
	await capture(game,"before")
	game.relay.destroyed = true
	game.destroy_yard_relay()
	game._update_yard_bridge(.45+game.BRIDGE_RISE_SECONDS*.5)
	check(is_equal_approx(game.bridge_progress,.5),"Bridge rises partway rather than appearing instantly")
	check(game.platforms[game.bridge_index].position.y>720,"Rising platform remains below ground until settled")
	check(game.bridge_body.position.distance_to(game.platforms[game.bridge_index].get_center())<.01,"Moving collision follows artwork")
	game.paused = true
	game._physics_process(5)
	check(is_equal_approx(game.bridge_progress,.5),"Pause freezes bridge rise")
	game.paused = false
	if "--visual" in OS.get_cmdline_user_args():
		game._update_yard_bridge(game.BRIDGE_RISE_SECONDS*.3)
	await capture(game,"rising")
	game._update_yard_bridge(game.BRIDGE_RISE_SECONDS)
	await frames(2)
	check(game.bridge_progress==1,"Bridge settles at ground level")
	check(floor_at(game,600) and floor_at(game,800),"Raised section is walkable")
	await capture(game,"raised")
	game.player.position = Vector2(385,720)
	game.player.velocity = Vector2.ZERO
	game.player.set_physics_process(true)
	await frames(8)
	Input.action_press("right")
	Input.action_press("run")
	Input.action_press("jump")
	await frames(42)
	Input.action_release("jump")
	await frames(60)
	Input.action_release("right")
	Input.action_release("run")
	await frames(12)
	check(game.player.health>0 and game.player.position.x>850 and game.player.is_on_floor(),"Player jumps remaining lip and crosses raised section")
	game.player.position = game.rifle_pickups[0].p
	game._update_pickups(0)
	check(game.rifle_pickups[0].taken,"Rifle can be recovered on right bank")
	game.respawn()
	check(game.bridge_progress==1 and game.relay.destroyed,"Recovery preserves restored crossing")
	game.queue_free()
	await process_frame
	var fresh = load("res://main.tscn").instantiate()
	root.add_child(fresh)
	check(fresh.bridge_progress==0 and fresh.bridge_body.collision_layer==0,"Fresh level restores the wide abyss")
	fresh.queue_free()
	await process_frame
	print("YARD BRIDGE: ",failures," failures")
	quit(failures)
