extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func freeze(node: Node) -> void:
	node.set_physics_process(false)
	node.set_process(false)
	for child in node.get_children(): freeze(child)

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in 3: await physics_frame
	freeze(game)
	var hero = game.player
	var rig = hero.rig
	var preview = load("res://characters/DarkironAnimationsTweaker.tscn").instantiate()
	root.add_child(preview)
	preview.set_process(false)
	var timeline: AnimationPlayer = preview.get_node("Controls/AnimationPlayer")
	timeline.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	check(is_equal_approx(rig.bow.visual_scale, .75), "Game bow uses 75% artwork size")
	for clip in ["bow_draw", "bow_cover"]:
		for facing in [-1.0, 1.0]:
			for charge in [0.0, .25, .5, .75, 1.0]:
				hero.facing = facing
				hero.weapon_kind = "BOW"
				hero.weapon_blend = 1.0
				hero.in_cover = clip == "bow_cover"
				hero.bow_charge = charge if clip == "bow_draw" else 0.0
				hero.bow_angle = -.3
				rig._update_run_edits()
				check(rig.edit_clip == clip, "Main game selects authored " + clip)
				timeline.play(clip)
				timeline.seek(rig.run_edit_player.current_animation_position, true)
				preview.face_left = facing < 0
				preview.bow_aim_degrees = rad_to_deg(-.3)
				preview._process(0)
				for property in ["clock", "run_weight", "move_weight", "stand_weight", "cover_weight"]:
					rig.set(property, preview.rig.get(property))
				rig.queue_redraw()
				await process_frame
				await process_frame
				preview.rig._draw()
				for anchor in ["left_shoulder", "right_shoulder", "left_elbow", "right_elbow", "grip", "nock", "right_hand"]:
					check(rig.bow.call(anchor).distance_to(preview.rig.bow.call(anchor)) < .003, clip + " preserves tweaker " + anchor)
				check(is_equal_approx(preview.rig.bow.visual_scale, 1.0), "Standalone tweaker has initialized original bow size")
				rig.bow._process(0)
				preview.rig.bow._process(0)
				await process_frame
	for kind in ["BOW", "RIFLE"]:
		for blend in [0.0, .25, .5, .75, 1.0]:
			for climb in [false, true]:
				hero.weapon_kind = kind
				hero.weapon_blend = blend
				hero.climbing = climb
				hero.in_cover = false
				rig._update_run_edits()
				rig.queue_redraw()
				await process_frame
				await process_frame
				rig.bow._process(0)
				var held: bool = kind == "BOW" and blend >= .5 and not climb
				check(rig.bow.visible == held, "Held bow visibility follows selected weapon/state")
				check(rig._slung_bow_visible() == (kind == "BOW" and not held), "Selected bow stays on back when sheathed/climbing")
				for i in rig.part_cursor:
					check(kind != "BOW" or rig.parts[i].index not in [2,9,10,11], "Bow selection never renders rifle parts")
				await process_frame
	hero.weapon_kind = "BOW"
	hero.weapon_blend = 1.0
	hero.climbing = false
	hero.bow_charge = .73
	hero.facing = -1.0
	rig._draw()
	game.fire_arrow(hero, .73)
	check(is_equal_approx(rig.run_edit_player.current_animation_position, .73), "Release samples latest authored charge keys")
	var direction := Vector2.from_angle(hero.bow_angle) * Vector2(hero.facing, 1)
	check(game.arrows[-1].p.distance_to(rig.to_global(rig.bow.nock()) + direction * 110) < .003, "Projectile starts at rendered arrow tip facing left")
	preview.queue_free()
	if "--visual" in OS.get_cmdline_user_args():
		game.ui.hide()
		game.camera.position = hero.position + Vector2(0,-90)
		game.camera.zoom = Vector2(4,4)
		hero.facing = 1.0
		for state in ["drawn", "sheathed", "rifle"]:
			hero.weapon_kind = "RIFLE" if state == "rifle" else "BOW"
			hero.weapon_blend = 1.0 if state == "drawn" else 0.0
			hero.bow_charge = .5
			rig._update_run_edits()
			rig.queue_redraw()
			rig.bow._process(0)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.runtime/bow-game-" + state + ".png")
	game.queue_free()
	await process_frame
	print("BOW GAME INTEGRATION: ", failures, " failures")
	quit(failures)
