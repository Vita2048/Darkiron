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
func snapshot(rig: Node2D) -> Dictionary:
	rig.queue_redraw()
	rig.bow.queue_redraw()
	rig.bow.hands.queue_redraw()
	await process_frame
	await process_frame
	var pose := {}
	for index in rig.part_cursor:
		var part: Node2D = rig.parts[index]
		if part.index==1: pose.torso = part.global_position
	for anchor in ["left_shoulder","right_shoulder","left_elbow","right_elbow","grip","nock","right_hand"]:
		pose[anchor] = rig.to_global(rig.bow.call(anchor))
	return pose
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in 5: await physics_frame
	freeze(game)
	var hero = game.player
	var rig = hero.rig
	for facing in [-1.0,1.0]:
		for covered in [false,true]:
			for charge in [0.0,.5,1.0]:
				for stance_weight in [0.0,.5,1.0]:
					hero.facing = facing
					hero.in_cover = covered
					hero.bow_charge = charge
					hero.bow_angle = -.3
					hero.crouching = false
					rig.stand_weight = stance_weight
					rig.move_weight = 0
					rig.run_weight = 0
					rig.cover_weight = 1 if covered else 0
					rig.clock = .2
					rig._update_run_edits()
					var standing: Dictionary = await snapshot(rig)
					hero.crouching = true
					var crouched: Dictionary = await snapshot(rig)
					var body_shift: Vector2 = crouched.torso-standing.torso
					check(body_shift.y>20,"Crouch lowers the rendered torso")
					for anchor in ["left_shoulder","right_shoulder","left_elbow","right_elbow","grip","nock","right_hand"]:
						var shift: Vector2 = crouched[anchor]-standing[anchor]
						check(shift.distance_to(body_shift)<.1,"Crouched %s follows torso, facing %s cover %s charge %s weight %s" % [anchor,facing,covered,charge,stance_weight])
					hero.crouching = false
					var restored: Dictionary = await snapshot(rig)
					check(restored.grip.distance_to(standing.grip)<.1,"Standing again restores bow pose")
	hero.in_cover = false
	hero.crouching = true
	hero.facing = 1
	hero.bow_charge = .7
	rig.stand_weight = 0
	rig._update_run_edits()
	await snapshot(rig)
	game.fire_arrow(hero,.7)
	var expected: Vector2 = rig.to_global(rig.bow.nock())+Vector2.from_angle(hero.bow_angle)*110
	check(game.arrows[-1].p.distance_to(expected)<.01,"Arrow launches from crouched nocked tip")
	if "--visual" in OS.get_cmdline_user_args():
		game.ui.hide()
		game.camera.position = hero.position+Vector2(0,-85)
		game.camera.zoom = Vector2(5,5)
		for crouched in [false,true]:
			hero.crouching = crouched
			await snapshot(rig)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.runtime/bow-crouch-%s.png" % crouched)
	game.queue_free()
	await process_frame
	print("BOW CROUCH: ",failures," failures")
	quit(failures)
