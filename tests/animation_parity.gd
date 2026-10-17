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
		if a.parts[i].index != b.parts[i].index: return false
		if x.origin.distance_to(y.origin) > .003 or x.x.distance_to(y.x) > .0002 or x.y.distance_to(y.y) > .0002: return false
		if not a.parts[i].modulate.is_equal_approx(b.parts[i].modulate): return false
	return true
func run() -> void:
	var preview = load("res://characters/DarkironAnimationsTweaker.tscn").instantiate()
	root.add_child(preview)
	preview.set_process(false)
	preview.rig.set_process(false)
	var player: AnimationPlayer = preview.get_node("Controls/AnimationPlayer")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var old = load("res://tests/fixtures/legacy_darkiron_rig.gd").new()
	old.fighter = preview.actor
	root.add_child(old)
	old.set_process(false)
	check(player.get_animation_list().size() == 17, "Exactly 17 supported clips")
	check(not player.has_animation("climb_drawn"), "No drawn climb")
	for clip_name in player.get_animation_list():
		if clip_name.begins_with("bow_"): continue
		player.play(clip_name)
		var clip := player.get_animation(clip_name)
		var matches := true
		for i in 65:
			player.seek(clip.length * i / 65.0, true)
			preview._process(0)
			old.test_grounded = preview.rig.preview_grounded
			for property in ["clock", "stand_weight", "run_weight", "move_weight", "cover_weight"]:
				old.set(property, preview.rig.get(property))
			old.rotation = 0
			old.position = Vector2.ZERO
			old.queue_redraw()
			preview.rig.queue_redraw()
			await process_frame
			await process_frame
			if not same(old, preview.rig):
				matches = false
				break
		check(matches, clip_name + " preserves original rendered geometry")
		print("LEGACY PARITY ", clip_name, ": ", matches)
	old.queue_free()
	preview.queue_free()
	await process_frame
	print("ANIMATION PARITY: ", failures, " failures (15 clips x 65 phases)")
	quit(failures)
