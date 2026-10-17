extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func same(a: Node, b: Node) -> bool:
	if a.part_cursor != b.part_cursor: return false
	for i in a.part_cursor:
		var x: Transform2D = a.parts[i].transform
		var y: Transform2D = b.parts[i].transform
		if x.origin.distance_to(y.origin) > .003 or x.x.distance_to(y.x) > .0002 or x.y.distance_to(y.y) > .0002: return false
		if a.parts[i].z_index != b.parts[i].z_index: return false
	return true
func run() -> void:
	var game = load("res://debug_drones.tscn").instantiate()
	root.add_child(game)
	game.set_process_input(false)
	game.set_physics_process(false)
	for i in 3: await physics_frame
	var live = game.player.rig
	game.player.set_physics_process(false)
	live.set_process(false)
	var preview = load("res://characters/DarkironAnimationsTweaker.tscn").instantiate()
	root.add_child(preview)
	preview.set_process(false)
	preview.actor.world = game
	var player: AnimationPlayer = preview.get_node("Controls/AnimationPlayer")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play("bow_cover")
	preview._process(0)
	var legacy = load("res://tests/fixtures/legacy_bow_range_rig.gd").new()
	legacy.editor_preview = true
	legacy.preview_grounded = true
	legacy.fighter = preview.actor
	root.add_child(legacy)
	legacy.set_process(false)
	var neutral_matches := true
	for clip in ["bow_cover", "bow_draw"]:
		player.play(clip)
		for aim in [-1.0, -.5, 0.0, .6]:
			preview.bow_aim_degrees = rad_to_deg(aim)
			for phase in [0.0, .25, .5, .75, 1.0]:
				player.seek(player.get_animation(clip).length * phase, true)
				preview._process(0)
				for property in ["clock", "run_weight", "move_weight", "stand_weight", "cover_weight"]: legacy.set(property, preview.rig.get(property))
				legacy._draw()
				preview.rig._draw()
				neutral_matches = neutral_matches and same(legacy, preview.rig)
				for method in ["grip", "nock", "right_hand", "draw_elbow"]:
					neutral_matches = neutral_matches and legacy.bow.call(method).distance_to(preview.rig.bow.call(method)) < .003
	check(neutral_matches, "40 cover/draw/aim samples preserve original geometry and anchors")
	for clip in ["bow_cover", "bow_draw"]:
		player.play(clip)
		player.seek(player.get_animation(clip).length * .5, true)
		preview._process(0)
		preview.rig._draw()
		var grip_before: Vector2 = preview.rig.bow.grip()
		var elbow_before: Vector2 = preview.rig.bow.left_elbow()
		preview.rig.run_bone_layer.bones.LeftForearm.position = Vector2(6,-5)
		preview.rig._draw()
		check(preview.rig.bow.left_elbow().distance_to(elbow_before + Vector2(6,-5)) < .003, clip + " native forearm position moves elbow")
		check(preview.rig.bow.grip().distance_to(grip_before) < .003, clip + " elbow correction keeps grip attached")
		for bone_name in ["LeftShoulder", "LeftForearm", "RightShoulder", "RightForearm"]:
			var bone: Bone2D = preview.rig.run_bone_layer.bones[bone_name]
			var expected: Vector2
			match bone_name:
				"LeftShoulder": expected = preview.rig.bow.left_shoulder()
				"LeftForearm": expected = preview.rig.bow.left_elbow()
				"RightShoulder": expected = preview.rig.bow.right_shoulder()
				"RightForearm": expected = preview.rig.bow.right_elbow()
			var actual: Vector2 = preview.rig.run_bone_layer.to_local(bone.global_position)
			check(actual.distance_to(expected) < .003, clip + " gizmo agrees with " + bone_name)
	# Save edited solver keys and body bone keys, then reopen and sample in real drones.
	var library: AnimationLibrary = player.get_animation_library("").duplicate(true)
	player.remove_animation_library("")
	player.add_animation_library("", library)
	for clip in ["bow_cover", "bow_draw"]:
		var animation := player.get_animation(clip)
		var grip_track := animation.find_track(NodePath(".:bow_grip_offset"), Animation.TYPE_VALUE)
		animation.track_set_key_value(grip_track, 0, Vector2(2, -3))
		animation.track_set_key_value(grip_track, 1, Vector2(6, -7))
		var elbow_track := animation.find_track(NodePath(".:bow_draw_elbow_degrees"), Animation.TYPE_VALUE)
		for key in 2: animation.track_set_key_value(elbow_track, key, 4.0)
		var head: Bone2D = preview.get_node("Controls/Skeleton2D").find_child("Head", true, false)
		var head_track := animation.find_track(NodePath(str(preview.get_node("Controls").get_path_to(head)) + ":position"), Animation.TYPE_VALUE)
		for key in 2: animation.track_set_key_value(head_track, key, Vector2(3,-4))
		# Native torso offsets also carry the bow and shoulder solver.
		var torso: Bone2D = preview.get_node("Controls/Skeleton2D").find_child("Torso", true, false)
		var torso_track := animation.find_track(NodePath(str(preview.get_node("Controls").get_path_to(torso)) + ":position"), Animation.TYPE_VALUE)
		for key in 2: animation.track_set_key_value(torso_track, key, Vector2(2,-2))
		for bone_name in ["LeftShoulder", "LeftForearm", "RightShoulder", "RightForearm"]:
			var arm: Bone2D = preview.rig.run_bone_layer.bones[bone_name]
			var arm_track := animation.find_track(NodePath(str(preview.get_node("Controls").get_path_to(arm)) + ":position"), Animation.TYPE_VALUE)
			check(arm_track >= 0, clip + " has native arm position track: " + bone_name)
			for key in 2: animation.track_set_key_value(arm_track, key, Vector2(2,-3))
	var packed := PackedScene.new()
	check(packed.pack(preview) == OK, "Bow tweaker packs")
	check(ResourceSaver.save(packed, "res://.runtime/bow-tweaker-save.tscn") == OK, "Bow edits save")
	var restored = ResourceLoader.load("res://.runtime/bow-tweaker-save.tscn", "", ResourceLoader.CACHE_MODE_IGNORE).instantiate()
	root.add_child(restored)
	restored.set_process(false)
	var saved: AnimationPlayer = restored.get_node("Controls/AnimationPlayer")
	saved.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	live.run_edit_player.remove_animation_library("")
	live.run_edit_player.add_animation_library("", saved.get_animation_library(""))
	for clip in ["bow_cover", "bow_draw"]:
		game.player.in_cover = clip == "bow_cover"
		game.player.bow_angle = -.3
		game.player.bow_charge = .5 if clip == "bow_draw" else 0
		live._update_run_edits(.1)
		check(live.run_edit_player.assigned_animation == clip, "Drones selects " + clip)
		saved.play(clip)
		saved.seek(live.run_edit_player.current_animation_position, true)
		restored.bow_aim_degrees = rad_to_deg(-.3)
		restored._process(0)
		for property in ["clock", "run_weight", "move_weight", "stand_weight", "cover_weight"]: live.set(property, restored.rig.get(property))
		live._draw()
		restored.rig._draw()
		check(same(live, restored.rig), clip + " saved edits render identically in preview/game")
		check(live.bow.grip().distance_to(restored.rig.bow.grip()) < .003, clip + " grip agrees")
		check(live.bow.nock().distance_to(restored.rig.bow.nock()) < .003, clip + " string agrees")
		check(live.run_controls.bow_grip_offset.distance_to(Vector2(4,-5)) < .003, clip + " samples edited key")
	# Mouse remains authoritative; pull amount seeks freely backwards and forwards.
	game.player.in_cover = false
	game.charging = true
	game.drag_start = Vector2(600,500)
	game.drag_angle = 0
	for mouse in [Vector2(490,450), Vector2(380,550), Vector2(545,500)]:
		game.update_mouse(mouse)
		live._update_run_edits()
		live._draw()
		check(is_equal_approx(live.run_edit_player.current_animation_position, game.charge), "Mouse charge drives timeline")
		check(is_equal_approx(live.bow.aim_angle(), game.player.bow_angle), "Mouse aim stays authoritative")
		check(absf(live.bow.draw_elbow().distance_to(live.bow.nock()) - 44) < .01, "Edited draw preserves forearm length")
	# Release immediately after a new input, without an intervening render/update.
	game.update_mouse(Vector2(470,480))
	game.shoot()
	check(is_equal_approx(live.run_edit_player.current_animation_position, game.charge), "Release samples the latest mouse draw amount")
	check(game.arrows.size() == 1, "Edited bow can fire")
	check(game.arrows[0].v.normalized().distance_to(Vector2.from_angle(game.player.bow_angle)) < .0001, "Shot keeps mouse aim")
	for node in [restored, preview, legacy, game]: node.queue_free()
	await process_frame
	print("BOW TWEAKER: ", failures, " failures (legacy parity, save/reload, gameplay, mouse aim/charge)")
	quit(failures)
