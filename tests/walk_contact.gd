extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://debug_movement.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	var max_drift := 0.0
	var samples := 0
	for variant in [false,true]:
		var actor = load("res://scripts/fighter.gd").new()
		actor.enemy = true
		actor.drake = variant
		actor.world = world
		world.add_child(actor)
		actor.rig.set_process(false)
		actor.rig.move_weight = 1
		actor.rig.stand_weight = 0
		actor.rig.run_weight = 0
		for direction in [-1,1]:
			actor.position = Vector2(1600 if direction<0 else 600,720)
			world.player.position = Vector2(1100,720)
			actor.velocity = Vector2.ZERO
			actor.cooldown = 999
			actor.gait = 0
			var previous := {}
			for frame in 115:
				await physics_frame
				for leg in 2:
					var phase: float = actor.gait+leg*PI
					var cycle := floori(phase/TAU)
					var contact: bool = fposmod(phase/TAU,1.0)<actor.rig.WALK_CONTACT
					var hip := Vector2(-4,-actor.rig.gait_height(actor.gait))
					var pose = actor.rig.gait_leg_points(hip,phase,leg==0)
					var foot: Vector2 = actor.position+Vector2(actor.facing*pose[2].x,pose[2].y)
					if contact and frame>20:
						assert(absf(actor.rig.walk_foot_angle(phase))<0.001)
						if previous.has(leg) and previous[leg].cycle==cycle:
							max_drift = maxf(max_drift,foot.distance_to(previous[leg].point))
							samples += 1
						previous[leg] = {"cycle":cycle,"point":foot}
					else: previous.erase(leg)
		actor.queue_free()
		await process_frame
	var ok := samples>300 and max_drift<0.02
	print("WALK CONTACT: both enemy types and directions; samples=",samples," drift=",max_drift," PASS=",ok)
	world.queue_free()
	await process_frame
	quit(0 if ok else 1)
