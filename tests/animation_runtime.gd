extends SceneTree

var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	# Use the shipped game, not a preview-only AnimationPlayer.
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for enemy in game.enemies: enemy.set_physics_process(false)
	var actor = game.player
	actor.position = Vector2(1700, 720)
	for i in 20: await physics_frame
	actor.set_physics_process(false)
	var rig = actor.rig
	rig.set_process(false)
	var player: AnimationPlayer = rig.skeleton_animation
	var head: Bone2D = rig.skeleton_character.find_child("Head", true, false)
	for state in ["idle", "walk", "run", "crouch", "cover", "climb", "air"]:
		actor.climbing = state == "climb"
		actor.weapon_blend = 0.0 if actor.climbing else 1.0
		actor.in_cover = state == "cover"
		actor.crouching = state == "crouch"
		actor.running = state == "run"
		actor.velocity = Vector2(210 if state in ["walk", "run"] else 0, 0)
		actor.gait = TAU * 0.37
		rig.cover_active = false
		rig.crouch_active = false
		rig.cover_time = 0
		rig.crouch_time = 0
		if state == "air":
			actor.position.y -= 250
			actor.move_and_slide()
		var original: Animation = player.get_animation(state)
		var edited: Animation = original.duplicate(true)
		var library := player.get_animation_library("")
		library.remove_animation(state)
		library.add_animation(state, edited)
		var path := NodePath(str(rig.skeleton_character.get_path_to(head)) + ":position")
		var track := edited.find_track(path, Animation.TYPE_VALUE)
		var sentinel := Vector2(19, -43)
		for key in edited.track_get_key_count(track):
			edited.track_set_key_value(track, key, sentinel)
		edited.length *= 1.7
		rig._process(0.03)
		check(rig.skeleton_active and rig.skel_clip == state, state + " selected in the actual game")
		check(head.position.is_equal_approx(sentinel), state + " authored position survives runtime update")
		rig._process(0.02)
		check(head.position.is_equal_approx(sentinel), state + " key is not overwritten next frame")
		if state in ["walk", "run", "climb"]:
			check(is_equal_approx(player.current_animation_position, edited.length * 0.37), state + " follows gait across edited duration")
		if state in ["cover", "crouch"]:
			rig._process(1.0)
			check(is_equal_approx(player.current_animation_position, edited.length / 2), state + " holds edited midpoint")
			actor.in_cover = false
			actor.crouching = false
			rig._process(0.01)
			check(is_equal_approx(player.current_animation_position, edited.length / 2 + .01), state + " plays exit forward")
			actor.in_cover = state == "cover"
			actor.crouching = state == "crouch"
			rig._process(0.005)
			check(is_equal_approx(player.current_animation_position, edited.length / 2 - .005), state + " reverses interrupted exit")
		library.remove_animation(state)
		library.add_animation(state, original)
		rig.skel_clip = ""
	game.queue_free()
	await process_frame
	print("ANIMATION RUNTIME: ", failures, " failures")
	quit(failures)
