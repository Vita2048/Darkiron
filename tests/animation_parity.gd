extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://debug_movement.tscn").instantiate()
	root.add_child(game)
	for i in 20: await physics_frame
	var actor = game.player
	actor.set_physics_process(false)
	actor.rig.set_process(false)
	var probe = load("res://tests/animation_probe_rig.gd").new()
	probe.fighter = actor
	probe.editor_preview = true
	root.add_child(probe)
	probe.set_process(false)
	var character = actor.rig.skeleton_character
	var player: AnimationPlayer = character.get_node("AnimationPlayer")
	var skeleton: Skeleton2D = character.get_node("Skeleton2D")
	var visual := "--visual" in OS.get_cmdline_user_args()
	var viewport: SubViewport
	var sheet: Image
	var label: Label
	var row := 0
	if visual:
		viewport = SubViewport.new()
		viewport.size = Vector2i(900, 340)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var background := ColorRect.new()
		background.size = Vector2(900, 340)
		background.color = Color(.18, .20, .24)
		viewport.add_child(background)
		for x in [250, 650]:
			var wrapper := Node2D.new()
			wrapper.position = Vector2(x, 310)
			wrapper.scale = Vector2.ONE * 1.6
			viewport.add_child(wrapper)
			if x == 650:
				character.reparent(wrapper, false)
				character.show()
			else:
				actor.rig.reparent(wrapper, false)
		actor.rig.procedural_override = true
		label = Label.new()
		label.position = Vector2(30, 10)
		viewport.add_child(label)
		sheet = Image.create(900, 340 * 7, false, Image.FORMAT_RGBA8)
	for clip in ["idle", "walk", "run", "air", "crouch", "cover", "climb"]:
		actor.climbing = clip == "climb"
		actor.crouching = clip == "crouch"
		actor.in_cover = clip == "cover"
		actor.running = clip == "run"
		actor.velocity = Vector2(330 if clip == "run" else (210 if clip == "walk" else 0), 0)
		probe.run_weight = 1.0 if clip == "run" else 0.0
		probe.move_weight = 1.0 if clip in ["walk", "run"] else 0.0
		probe.stand_weight = 1.0 if clip == "idle" else 0.0
		probe.cover_weight = 1.0 if clip == "cover" else 0.0
		if clip == "air":
			actor.position.y -= 300
			actor.move_and_slide()
		elif not actor.is_on_floor():
			actor.position.y = 720
			actor.velocity.y = 10
			actor.move_and_slide()
		var max_position := 0.0
		var max_angle := 0.0
		var worst := ""
		var animation := player.get_animation(clip)
		player.play(clip)
		for sample in 65:
			var phase := sample / 64.0
			var time := phase * animation.length
			actor.gait = phase * TAU
			probe.clock = time
			# Compare held poses for transitional clips.
			if clip == "cover": time = animation.length / 2
			if clip == "crouch": time = animation.length / 2
			player.seek(time, true)
			probe.captured.clear()
			probe._draw()
			var counts := {}
			for part in probe.captured:
				var index: int = part.index
				var count: int = counts.get(index, 0)
				counts[index] = count + 1
				var name := ""
				match index:
					0: name = "Head"
					1: name = "Torso"
					2: name = "Weapon"
					6: name = "LeftThigh" if count == 0 else "RightThigh"
					7: name = "LeftShin" if count == 0 else "RightShin"
				if name.is_empty(): continue
				var bone := skeleton.find_child(name, true, false) as Bone2D
				# Remove the authored whole-body cover squash before comparing joints.
				var relative := skeleton.global_transform.affine_inverse() * bone.global_transform
				var error := relative.origin.distance_to(part.at)
				if error > max_position:
					max_position = error
					worst = name
				max_angle = maxf(max_angle, absf(wrapf(relative.get_rotation() - part.angle, -PI, PI)))
			if visual and sample == 43:
				for property in ["run_weight", "move_weight", "stand_weight", "cover_weight", "clock"]:
					actor.rig.set(property, probe.get(property))
				label.text = clip.to_upper() + "    |    LEFT: procedural    |    RIGHT: authored scene    |    phase 0.672"
				actor.rig.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var frame := viewport.get_texture().get_image()
				frame.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(frame, Rect2i(0, 0, 900, 340), Vector2i(0, row * 340))
		print("PARITY ", clip, " max joint error=", snappedf(max_position, .01), "px (", worst, ") angle=", snappedf(rad_to_deg(max_angle), .01), "deg")
		row += 1
	if visual:
		sheet.save_png("res://preview-animation-parity.png")
		viewport.queue_free()
	probe.queue_free()
	game.queue_free()
	await process_frame
	quit()
