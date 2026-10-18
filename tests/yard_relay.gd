extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): freeze(child)
func shoot(game: Node2D,y: float) -> void:
	game.arrows = [{"p":Vector2(game.relay.position.x-130,y),"v":Vector2(2080,0),"life":5.0,"stuck":false}]
	game._update_arrows(.1)
func capture(game: Node2D,name: String) -> void:
	game.queue_redraw()
	game.relay.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/relay-"+name+".png")
func run() -> void:
	# Reproduce approach over many small physics steps, from either side,
	# including a low-power ballistic shot.
	for fps in [30,60,120]:
		for direction in [-1.0,1.0]:
			var probe = load("res://main.tscn").instantiate()
			root.add_child(probe)
			freeze(probe)
			probe.relay.cycle = (probe.relay.OPEN_START+probe.relay.OPEN_END)*.5
			probe.relay.advance(0)
			var travel := 130.0/640.0
			probe.arrows = [{"p":probe.relay.position+Vector2(-130*direction,0),"v":Vector2(640*direction,-.5*probe.ARROW_GRAVITY*travel),"life":5.0,"stuck":false}]
			for frame in 60:
				probe._update_arrows(1.0/fps)
				if probe.arrows.is_empty(): break
			check(probe.relay.destroyed,"Real frame-step arrow reaches open core at %d FPS, direction %s" % [fps,direction])
			probe.queue_free()
			await process_frame
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	freeze(game)
	check(game.get_node("ArrowLayer").z_index>game.relay.z_index,"Arrows render in front of relay housing")
	for closed in [false,true]:
		game.relay.cycle = 5.0 if closed else (game.relay.OPEN_START+game.relay.OPEN_END)*.5
		game.relay.advance(0)
		for height in [-100.0,-80.0,-40.0,40.0,80.0,95.0]:
			for direction in [-1.0,1.0]:
				var distance := 130.0 if direction>0 else 60.0 # Avoid the upper gallery on the right.
				var travel := distance/640.0
				game.arrows = [{"p":game.relay.position+Vector2(-distance*direction,height),"v":Vector2(640*direction,-.5*game.ARROW_GRAVITY*travel),"life":5.0,"stuck":false}]
				for frame in 30:
					game._update_arrows(1.0/60)
					if game.arrows.is_empty(): break
				check(game.arrows.is_empty(),"Housing catches missed lens shot at height %s, closed %s" % [height,closed])
				check(not game.relay.destroyed,"Housing impacts do not destroy relay")
	# Shots above the complete silhouette should remain in flight.
	game.arrows = [{"p":game.relay.position+Vector2(-130,-140),"v":Vector2(2080,0),"life":5.0,"stuck":false}]
	game._update_arrows(.1)
	check(not game.arrows.is_empty(),"True miss above housing continues flying")
	game.arrows.clear()
	check(game.audio.has("bow") and game.audio.bow is AudioStreamWAV,"Natural bow sample loaded")
	for drone in game.drones:
		check(drone.scale.x<.2,"Drone begins small in distant background")
		check(drone.warning==0,"Arrival cannot shoot")
	if "--visual" in OS.get_cmdline_user_args(): await capture(game,"arrival")
	for drone in game.drones: drone.advance(4.0)
	check(game.drones.all(func(d): return d.arrival==1),"All drones arrive at combat scale")
	for frame in 300:
		for drone in game.drones:
			drone.advance(1.0/60)
			check(drone.position.y<=440,"Drone stays above relay firing lane")
	game.relay.cycle = 0
	var exposed_seconds := 0.0
	for frame in 650:
		game.relay.advance(.01)
		if game.relay.exposed(): exposed_seconds += .01
	check(exposed_seconds>=game.relay.OPEN_END-game.relay.OPEN_START and exposed_seconds<game.relay.OPEN_END-game.relay.OPEN_START+.2,"Shot window follows configured timing")
	for drone in game.drones: drone.hit(100)
	check(game.kills==0,"Drone farming cannot unlock level")
	check(game.reinforcement_delay>0,"Last kill schedules replacements")
	game._update_drones(1.9)
	check(game.drones.size()==3 and game.drones.all(func(d): return d.health>0),"Three replacements arrive")
	for drone in game.drones: drone.position = Vector2(1000,300)
	game.relay.cycle = 4.8
	game.relay.advance(0)
	shoot(game,620)
	check(not game.relay.destroyed and game.arrows.is_empty(),"Closed shutter blocks fast arrows")
	game.relay.cycle = 2.15
	game.relay.advance(0)
	shoot(game,665)
	check(not game.relay.destroyed,"Exposed frame hit does not destroy core")
	game.relay.cycle = 6.4
	game.relay.advance(.2)
	check(game.relay.cycle<.2,"Missed opportunity cycles without another wave kill")
	game.relay.cycle = 2.15
	game.relay.advance(0)
	if "--visual" in OS.get_cmdline_user_args():
		for drone in game.drones:
			drone.advance(4)
			drone.position = Vector2(650+drone.slot*180,370+drone.slot*55)
		await capture(game,"open")
		for drone in game.drones: drone.position = Vector2(1000,300)
	game.drone_bolts.append({"p":Vector2(500,500),"v":Vector2.ZERO,"life":5.0})
	shoot(game,620)
	check(game.relay.destroyed,"Single arrow destroys exposed core")
	check(not game.relay.visible,"Destroyed relay disappears")
	check(game.relay.arrow_entry(game.relay.position-Vector2(150,0),game.relay.position+Vector2(150,0))==INF,"Destroyed relay no longer blocks arrows")
	check(game.drone_bolts.is_empty(),"Power loss clears hostile fire")
	check(game.drones.all(func(d): return d.health==0 and d.falling),"Power loss drops all hunters")
	check(game.kills==1,"Relay awards exactly one objective")
	game._update_drones(10)
	check(game.drones.all(func(d): return d.health==0),"No reinforcements after shutdown")
	game.respawn()
	check(game.relay.destroyed and game.kills==1,"Checkpoint recovery preserves relay destruction")
	game.player.position = Vector2(6000,480)
	game.seals_broken = 2
	game.kills = game.total_targets
	game._physics_process(0)
	check(game.completed,"Relay objective permits furnace completion with guards and seals cleared")
	game.queue_free()
	await process_frame
	var fresh = load("res://main.tscn").instantiate()
	root.add_child(fresh)
	freeze(fresh)
	check(not fresh.relay.destroyed and fresh.kills==0,"Restart gives a fresh encounter")
	fresh.paused = true
	fresh._physics_process(2)
	check(fresh.relay.cycle==0 and fresh.drones[0].arrival==0,"Pause freezes charge and arrivals")
	fresh.paused = false
	if "--visual" in OS.get_cmdline_user_args():
		for drone in fresh.drones: drone.advance(4)
		fresh.relay.cycle = 2.15
		fresh.relay.advance(0)
		fresh.notice_time = 0
		fresh.clock = 4
		await capture(fresh,"scene")
		fresh.relay.cycle = 5
		fresh.relay.advance(0)
		await capture(fresh,"closed")
	fresh.queue_free()
	await process_frame
	print("YARD RELAY: ",failures," failures")
	quit(failures)
