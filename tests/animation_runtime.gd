extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for enemy in game.enemies: enemy.set_physics_process(false)
	var actor = game.player
	actor.position = Vector2(1700, 720)
	for i in 20: await physics_frame
	actor.set_physics_process(false)
	var rig = actor.rig
	rig.set_process(false)
	var scene = load("res://characters/DarkironAnimationsTweaker.tscn").instantiate()
	# Edit the actual scene's animation resources, save, and reopen before use.
	var source: AnimationPlayer = scene.get_node("Controls/AnimationPlayer")
	var head: Bone2D = scene.get_node("Controls/Skeleton2D").find_child("Head", true, false)
	var path := NodePath(str(scene.get_node("Controls").get_path_to(head)) + ":position")
	var library := source.get_animation_library("").duplicate(true)
	source.remove_animation_library("")
	source.add_animation_library("", library)
	var markers := {}
	var number := 0
	for name in source.get_animation_list():
		number += 1
		var animation := source.get_animation(name)
		var track := animation.find_track(path, Animation.TYPE_VALUE)
		var marker := Vector2(number, -number * 2)
		markers[name] = marker
		for key in animation.track_get_key_count(track): animation.track_set_key_value(track, key, marker)
		animation.length *= 1.3
	var packed := PackedScene.new()
	check(packed.pack(scene) == OK, "Edited tweaker packs")
	DirAccess.make_dir_recursive_absolute("res://.runtime")
	check(ResourceSaver.save(packed, "res://.runtime/tweaker-save.tscn") == OK, "Edited tweaker saves")
	scene.free()
	var reopened = ResourceLoader.load("res://.runtime/tweaker-save.tscn", "", ResourceLoader.CACHE_MODE_IGNORE).instantiate()
	root.add_child(reopened)
	reopened.set_process(false)
	reopened.rig.set_process(false)
	var saved: AnimationPlayer = reopened.get_node("Controls/AnimationPlayer")
	saved.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for player in [rig.run_edit_player, rig.recoil_player]:
		player.remove_animation_library("")
		player.add_animation_library("", saved.get_animation_library(""))
	# Exercise real actor floor/air state, every clip switch, and repeated sampling.
	for name in saved.get_animation_list():
		actor.position = Vector2(1700, 720)
		actor.velocity = Vector2(0, 10)
		actor.move_and_slide()
		if name.begins_with("air"):
			actor.position.y -= 250
			actor.velocity = Vector2.ZERO
			actor.move_and_slide()
		actor.health = 0 if name == "death" else 100
		actor.dead_time = .4
		actor.climbing = name.begins_with("climb")
		actor.crouching = name.begins_with("crouch")
		actor.in_cover = name.begins_with("cover")
		actor.running = name.begins_with("run")
		actor.weapon_blend = 1 if name.ends_with("drawn") else 0
		actor.velocity.x = 330 if actor.running else (210 if name.begins_with("walk") else 0)
		actor.gait = TAU * .37
		actor.recoil = .3 if name == "recoil_drawn" else 0
		rig._process(.03)
		var selected: String = "idle_drawn" if name == "recoil_drawn" else name
		check(rig.run_edit_player.assigned_animation == selected, name + " selects gameplay clip")
		check(rig.run_bone_layer.bones.Head.position.is_equal_approx(markers[selected]), name + " saved key reaches runtime")
		if name.begins_with("run") or name.begins_with("walk") or name.begins_with("climb"):
			check(is_equal_approx(rig.run_edit_player.current_animation_position, saved.get_animation(name).length * .37), name + " gait respects edited duration")
		if name == "recoil_drawn":
			check(rig.recoil_layer.bones.Head.position.is_equal_approx(markers[name]), "Recoil overlay samples saved keys")
			check(is_equal_approx(rig.recoil_player.current_animation_position, saved.get_animation(name).length * .7), "Recoil follows actual shot decay")
		rig._process(.02)
		check(rig.run_bone_layer.bones.Head.position.is_equal_approx(markers[selected]), name + " edit survives next frame")
		if name != "recoil_drawn":
			saved.play(name)
			saved.seek(rig.run_edit_player.current_animation_position, true)
			reopened._process(0)
			# Match the live renderer's transition weights and elapsed breathing time.
			for property in ["clock", "run_weight", "move_weight", "stand_weight", "cover_weight"]:
				reopened.rig.set(property, rig.get(property))
			reopened.actor.gait = actor.gait
			reopened.actor.dead_time = actor.dead_time
			rig._draw()
			reopened.rig._draw()
			var equal: bool = rig.part_cursor == reopened.rig.part_cursor
			for i in mini(rig.part_cursor, reopened.rig.part_cursor):
				var x: Transform2D = rig.parts[i].transform
				var y: Transform2D = reopened.rig.parts[i].transform
				equal = equal and x.origin.distance_to(y.origin) < .003 and x.x.distance_to(y.x) < .0002 and x.y.distance_to(y.y) < .0002
			check(equal, name + " saved edits render identically in preview and game")
	# Recoil and locomotion edits remain active together.
	actor.health = 100
	actor.climbing = false
	actor.crouching = false
	actor.in_cover = false
	actor.weapon_blend = 1
	actor.running = true
	actor.velocity = Vector2(330, 10)
	actor.position = Vector2(1700, 720)
	actor.move_and_slide()
	actor.recoil = .3
	rig._process(.01)
	check(rig.run_edit_player.assigned_animation == "run_drawn" and rig.recoil_edit_weight == 1, "Run and recoil are composed")
	rig._draw()
	var base_head: Transform2D = rig.run_bone_layer.base_transforms.Head
	var rendered_head: Node2D
	for i in rig.part_cursor:
		if rig.parts[i].index == 0: rendered_head = rig.parts[i]
	check(rendered_head.position.distance_to(base_head.origin) > 5, "Saved edits visibly move rendered artwork")
	var combined: Vector2 = markers.run_drawn + markers.recoil_drawn
	check(rendered_head.position.distance_to(base_head * combined) < .003, "Recoil and stance keys both transform the artwork")
	actor.recoil = 0
	rig._process(.01)
	check(rig.recoil_edit_weight == 0, "Finished recoil stops affecting next pose")
	# Both drawn weapon layers must follow the Weapon bone together.
	rig._draw()
	var weapon_before := {}
	for i in rig.part_cursor:
		if rig.parts[i].index in [2, 9]: weapon_before[i] = rig.parts[i].position
	rig.run_bone_layer.bones.Weapon.position = Vector2(8, -5)
	rig._draw()
	var weapon_delta := Vector2.ZERO
	for i in weapon_before:
		var delta: Vector2 = rig.parts[i].position - weapon_before[i]
		check(delta.length() > 8, "Weapon artwork layer follows native bone")
		if weapon_delta != Vector2.ZERO: check(delta.distance_to(weapon_delta) < .003, "Weapon foreground and background stay aligned")
		weapon_delta = delta
	actor.in_cover = true
	rig._process(.1)
	rig._draw()
	var arm: Node2D
	for i in rig.part_cursor:
		if rig.parts[i].index == 3: arm = rig.parts[i]
	var arm_before := arm.position
	rig.run_bone_layer.bones.RightShoulder.position = Vector2(7, 0)
	rig._draw()
	check(arm.position.distance_to(arm_before) > 6, "Cover's single arm follows RightShoulder")
	reopened.queue_free()
	game.queue_free()
	await process_frame
	print("ANIMATION RUNTIME: ", failures, " failures (15 saved clips, selection, timing, recoil composition)")
	quit(failures)
