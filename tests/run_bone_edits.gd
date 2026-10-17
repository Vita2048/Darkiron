extends SceneTree

var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func rendered(rig: Node) -> Array:
	rig._draw()
	var result: Array = []
	for i in rig.part_cursor:
		result.append([rig.parts[i].index, rig.parts[i].transform, rig.parts[i].modulate])
	return result

func same(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for i in a.size():
		if a[i][0] != b[i][0] or a[i][2] != b[i][2]: return false
		var x: Transform2D = a[i][1]
		var y: Transform2D = b[i][1]
		if x.origin.distance_to(y.origin) > .002 or x.x.distance_to(y.x) > .0001 or x.y.distance_to(y.y) > .0001: return false
	return true

func run() -> void:
	var scene = load("res://characters/DarkironAnimationsTweaker.tscn")
	var preview = scene.instantiate()
	root.add_child(preview)
	preview.set_process(false)
	var player: AnimationPlayer = preview.get_node("Controls/AnimationPlayer")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var layer = preview.rig.run_bone_layer
	check(layer.get_bone_count() == 32, "Native Skeleton2D registers all pose and adjustment bones")
	var baseline = load("res://scripts/rig.gd").new()
	baseline.editor_preview = true
	baseline.preview_grounded = true
	baseline.fighter = preview.actor
	baseline.run_weight = 1
	baseline.move_weight = 1
	baseline.stand_weight = 0
	root.add_child(baseline)
	baseline.set_process(false)
	var clip: Animation = player.get_animation("run_sheathed")
	for i in 121:
		player.seek(clip.length * i / 121.0, true)
		preview._process(0)
		baseline.clock = preview.rig.clock
		check(same(rendered(baseline), rendered(preview.rig)), "Neutral artwork transforms reproduce original at sample " + str(i))
	# Use real Bone2D transforms, exactly as the native editor gizmo does.
	player.seek(clip.length / 3, true)
	preview._process(0)
	var original := rendered(preview.rig)
	var thigh: Bone2D = layer.bones.RightThigh
	var shin: Bone2D = layer.bones.RightShin
	var foot: Bone2D = layer.bones.RightFoot
	var old_knee: Vector2 = layer.final_transforms.RightShin.origin
	var old_ankle: Vector2 = layer.final_transforms.RightFoot.origin
	thigh.rotation = deg_to_rad(-25)
	var changed := rendered(preview.rig)
	check(not same(original, changed), "Thigh rotation changes rendered artwork")
	check(layer.final_transforms.RightShin.origin.distance_to(old_knee) > 5, "Thigh rotation moves the knee")
	check(layer.final_transforms.RightFoot.origin.distance_to(old_ankle) > 5, "Thigh rotation carries the ankle")
	check(is_equal_approx(thigh.rotation, deg_to_rad(-25)), "Procedural pass preserves the editable rotation")
	check(same(changed, rendered(preview.rig)), "Repeated rendering does not accumulate adjustments")
	shin.position = Vector2(3, -5)
	shin.rotation = deg_to_rad(12)
	thigh.scale = Vector2(1.05, 1.1)
	changed = rendered(preview.rig)
	for bone_name in layer.PARENTS:
		var native: Transform2D = layer.global_transform.affine_inverse() * layer.bones[bone_name].global_transform
		var final: Transform2D = layer.final_transforms[bone_name]
		check(native.is_equal_approx(final), "Native bone gizmo agrees with rendered transform: " + bone_name)
	# Save ordinary native bone tracks, then reload the scene and use it in the game.
	var edited_clip: Animation = clip.duplicate(true)
	var library := AnimationLibrary.new()
	library.add_animation("run_sheathed", edited_clip)
	player.remove_animation_library("")
	player.add_animation_library("", library)
	var controls: Node = preview.get_node("Controls")
	for bone in [thigh, shin]:
		for property in ["position", "rotation", "scale"]:
			var path := NodePath(str(controls.get_path_to(bone)) + ":" + property)
			var track := edited_clip.find_track(path, Animation.TYPE_VALUE)
			check(track >= 0 and edited_clip.track_get_key_count(track) == 13, "Thirteen native keys for " + str(path))
			edited_clip.track_set_key_value(track, 4, bone.get(property))
	player.play("run_sheathed")
	player.seek(clip.length / 3, true)
	preview._process(0)
	changed = rendered(preview.rig)
	player.seek(0, true)
	preview._process(0)
	check(same(rendered(baseline), rendered(preview.rig)), "Neutral key restores scale/skew and pose after editing")
	player.seek(clip.length / 3, true)
	preview._process(0)
	check(same(changed, rendered(preview.rig)), "Backwards seeking restores edited bone pose")
	var packed := PackedScene.new()
	check(packed.pack(preview) == OK, "Bone editing scene packs")
	check(ResourceSaver.save(packed, "res://.runtime/run-bone-save.tscn") == OK, "Bone editing scene saves")
	var saved: PackedScene = ResourceLoader.load("res://.runtime/run-bone-save.tscn", "", ResourceLoader.CACHE_MODE_IGNORE)
	var restored = saved.instantiate()
	root.add_child(restored)
	restored.set_process(false)
	var restored_player: AnimationPlayer = restored.get_node("Controls/AnimationPlayer")
	restored_player.pause()
	restored_player.seek(clip.length / 3, true)
	restored._process(0)
	check(same(changed, rendered(restored.rig)), "Saved bone edits reproduce identical artwork")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for enemy in game.enemies: enemy.set_physics_process(false)
	var actor = game.player
	actor.position = Vector2(1700, 720)
	for i in 20: await physics_frame
	actor.set_physics_process(false)
	actor.rig.set_process(false)
	actor.weapon_blend = 0
	actor.running = true
	actor.velocity = Vector2(330, 0)
	actor.gait = TAU / 3
	actor.rig.run_weight = 1
	actor.rig.move_weight = 1
	actor.rig.stand_weight = 0
	var live_player: AnimationPlayer = actor.rig.run_edit_player
	live_player.remove_animation_library("")
	live_player.add_animation_library("", restored_player.get_animation_library(""))
	live_player.play("run_sheathed")
	actor.rig._update_run_edits()
	check(same(changed, rendered(actor.rig)), "Actual game applies saved native bone edits identically to preview")
	actor.facing = -1
	rendered(actor.rig)
	check(actor.rig.scale.x == -1, "Edited run mirrors with gameplay facing")
	actor.weapon_blend = 1
	actor.rig._update_run_edits()
	check(actor.rig.run_edit_weight == 0, "Missing drawn clip never reuses sheathed bone edits")
	if "--visual" in OS.get_cmdline_user_args():
		await make_visual(scene, saved, clip.length / 3)
	for node in [preview, baseline, restored, game]: node.queue_free()
	await process_frame
	print("RUN BONE EDITS: ", failures, " failures; 121 original poses, native gizmos, hierarchy, persistence, game integration")
	quit(failures)

func make_visual(original: PackedScene, edited: PackedScene, time: float) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000, 480)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(1000, 480)
	background.color = Color("202830")
	viewport.add_child(background)
	for i in 2:
		var display = (original if i == 0 else edited).instantiate()
		display.position = Vector2(240 + i * 500, 430)
		display.scale = Vector2.ONE * 2
		viewport.add_child(display)
		display.set_process(false)
		display.get_node("Camera2D").enabled = false
		display.get_node("Instructions").hide()
		var player: AnimationPlayer = display.get_node("Controls/AnimationPlayer")
		player.pause()
		player.seek(time, true)
		display._process(0)
	var label := Label.new()
	label.position = Vector2(25, 20)
	label.text = "ORIGINAL PROCEDURAL RUN                                      EDITABLE BONE ADJUSTMENTS\n                                                                            Right thigh -25 degrees; shin position/rotation; thigh scale"
	viewport.add_child(label)
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://preview-run-bone-edits.png")
	viewport.queue_free()
