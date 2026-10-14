extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for actor in game.enemies: actor.set_physics_process(false)
	var p = game.player
	p.position = Vector2(1700,720)
	for i in 10: await physics_frame
	p.rig.set_process(false)
	p.rig.run_weight = 1
	p.rig.move_weight = 1
	p.rig.stand_weight = 0
	var max_drift := 0.0
	var samples := 0
	var fastest := 0.0
	for direction in ["right","left"]:
		Input.action_press(direction)
		Input.action_press("run")
		var previous := {}
		for i in 110:
			await physics_frame
			fastest = maxf(fastest,absf(p.velocity.x))
			for leg in 2:
				var phase: float = p.gait+leg*PI
				var cycle := floori(phase/TAU)
				var contact: bool = fposmod(phase/TAU,1.0)<=p.rig.RUN_CONTACT
				var ankle: Vector2 = p.rig.run_ankle(phase)
				var world_x: float = p.position.x+p.facing*(ankle.x-4)
				if contact and i>15:
					if previous.has(leg) and previous[leg].cycle==cycle:
						max_drift = maxf(max_drift,absf(world_x-previous[leg].x))
						samples += 1
					previous[leg] = {"cycle":cycle,"x":world_x}
				else:
					previous.erase(leg)
		Input.action_release(direction)
		Input.action_release("run")
		for i in 15: await physics_frame
	var ok := samples>70 and max_drift<0.02 and fastest>=329
	print("RUN CONTACT: samples=",samples," max world-space foot drift=",max_drift," speed=",fastest," PASS=" ,ok)
	game.queue_free()
	await process_frame
	quit(0 if ok else 1)
