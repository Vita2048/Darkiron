extends SceneTree

var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func capture(probe: Node) -> Array:
	probe.captured.clear()
	probe._draw()
	return probe.captured.duplicate(true)

func poses_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for i in a.size():
		if a[i].index != b[i].index: return false
		if a[i].at.distance_to(b[i].at) > 0.001: return false
		if a[i].size.distance_to(b[i].size) > 0.001: return false
		if absf(a[i].angle - b[i].angle) > 0.0001: return false
		if not a[i].tint.is_equal_approx(b[i].tint): return false
	return true

func run() -> void:
	var game = load("res://debug_movement.tscn").instantiate()
	root.add_child(game)
	for i in 20: await physics_frame
	var actor = game.player
	actor.set_physics_process(false)
	actor.rig.set_process(false)
	actor.weapon_blend = 0
	actor.running = true
	actor.velocity = Vector2(330, 0)
	var preview = load("res://characters/DarkironAnimationsTweaker.tscn").instantiate()
	root.add_child(preview)
	preview.set_process(false)
	var player: AnimationPlayer = preview.get_node("Controls/AnimationPlayer")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var baseline = load("res://tests/animation_probe_rig.gd").new()
	baseline.editor_preview = true
	baseline.preview_grounded = true
	baseline.fighter = actor
	baseline.run_weight = 1
	baseline.move_weight = 1
	baseline.stand_weight = 0
	root.add_child(baseline)
	baseline.set_process(false)
	var edited = load("res://tests/animation_probe_rig.gd").new()
	edited.editor_preview = true
	edited.preview_grounded = true
	edited.fighter = preview.actor
	edited.run_weight = 1
	edited.move_weight = 1
	edited.stand_weight = 0
	edited.run_controls = preview.get_node("Controls")
	edited.run_edit_weight = 1
	root.add_child(edited)
	edited.set_process(false)
	var clip: Animation = player.get_animation("run_sheathed")
	for i in 65:
		var phase := i / 65.0
		actor.gait = phase * TAU
		player.seek(phase * clip.length, true)
		preview._process(0)
		baseline.clock = preview.rig.clock
		edited.clock = preview.rig.clock
		check(poses_equal(capture(baseline), capture(edited)), "Zero adjustments match original at phase " + str(phase))
	# Duplicate before edits so this test never modifies the saved asset.
	var modified: Animation = clip.duplicate(true)
	var library := AnimationLibrary.new()
	library.add_animation("run_sheathed", modified)
	player.remove_animation_library("")
	player.add_animation_library("", library)
	player.play("run_sheathed")
	var foot := modified.find_track(NodePath(".:front_foot_offset"), Animation.TYPE_VALUE)
	var arm := modified.find_track(NodePath(".:front_arm_swing_degrees"), Animation.TYPE_VALUE)
	modified.track_insert_key(foot, modified.length * .68, Vector2(0, -8))
	modified.track_insert_key(arm, modified.length * .68, 15.0)
	# Put the exact authored library on the actual game's rig too.
	var live_player: AnimationPlayer = actor.rig.run_edit_player
	live_player.remove_animation_library("")
	live_player.add_animation_library("", library)
	live_player.play("run_sheathed")
	actor.gait = TAU * .68
	actor.rig.run_weight = 1
	actor.rig.move_weight = 1
	actor.rig._update_run_edits()
	player.seek(modified.length * .68, true)
	preview._process(0)
	check(is_equal_approx(actor.rig.run_edit_weight, 1), "Sheathed running enables edits")
	check(actor.rig.run_controls.front_foot_offset.is_equal_approx(Vector2(0, -8)), "Game samples authored foot key")
	var original_pose := capture(baseline)
	var edited_pose := capture(edited)
	check(not poses_equal(original_pose, edited_pose), "Keys visibly change pose geometry")
	baseline.run_controls = actor.rig.run_controls
	baseline.run_edit_weight = actor.rig.run_edit_weight
	check(poses_equal(capture(baseline), edited_pose), "Preview and gameplay produce identical edited geometry")
	# Scrubbing backwards must not depend on accumulated playback state.
	player.seek(0, true)
	preview._process(0)
	player.seek(modified.length * .68, true)
	preview._process(0)
	check(poses_equal(capture(edited), edited_pose), "Repeated/backward seeking is deterministic")
	actor.weapon_blend = 1
	actor.rig._update_run_edits()
	check(is_zero_approx(actor.rig.run_edit_weight), "Missing drawn clip never reuses sheathed edits")
	actor.weapon_blend = 0
	actor.crouching = true
	actor.rig._update_run_edits()
	check(is_zero_approx(actor.rig.run_edit_weight), "Missing crouch clip never reuses run edits")
	# Verify saving/reopening the editing scene preserves those same keys.
	var packed := PackedScene.new()
	check(packed.pack(preview) == OK, "Preview scene packs")
	check(ResourceSaver.save(packed, "res://.runtime/run-edit-save.tscn") == OK, "Edited scene saves")
	var reopened = ResourceLoader.load("res://.runtime/run-edit-save.tscn", "", ResourceLoader.CACHE_MODE_IGNORE).instantiate()
	root.add_child(reopened)
	reopened.set_process(false)
	var reopened_player: AnimationPlayer = reopened.get_node("Controls/AnimationPlayer")
	reopened_player.pause()
	reopened_player.seek(modified.length * .68, true)
	check(reopened.get_node("Controls").front_foot_offset.is_equal_approx(Vector2(0, -8)), "Authored key survives save/reopen")
	if "--visual" in OS.get_cmdline_user_args():
		var viewport := SubViewport.new()
		viewport.size = Vector2i(900, 450)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var background := ColorRect.new()
		background.size = Vector2(900, 450)
		background.color = Color("202830")
		viewport.add_child(background)
		for i in 2:
			var display = (load("res://characters/DarkironAnimationsTweaker.tscn") if i == 0 else packed).instantiate()
			display.position = Vector2(230 + 430 * i, 400)
			display.scale = Vector2.ONE * 2
			viewport.add_child(display)
			display.get_node("Camera2D").enabled = false
			display.get_node("Instructions").hide()
			display.set_process(false)
			var display_player: AnimationPlayer = display.get_node("Controls/AnimationPlayer")
			display_player.pause()
			display_player.seek(modified.length * .68, true)
			display._process(0)
		var label := Label.new()
		label.position = Vector2(25, 20)
		label.text = "ORIGINAL PROCEDURAL RUN                         SAME RUN + KEYED EDITS\n                                                                            Front foot: Y -8 px / front arm: +15 degrees"
		viewport.add_child(label)
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://preview-run-animation-edits.png")
		viewport.queue_free()
	for node in [baseline, edited, preview, reopened, game]: node.queue_free()
	await process_frame
	print("RUN ANIMATION EDITS: ", failures, " failures (65 baseline poses, preview/game equality, edits, seeking, scope, persistence)")
	quit(failures)
