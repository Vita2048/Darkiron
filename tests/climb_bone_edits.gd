extends SceneTree

var failures := 0
func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

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
	var scene = load("res://characters/run_sheathed.tscn")
	var preview = scene.instantiate()
	root.add_child(preview)
	preview.set_process(false)
	var player: AnimationPlayer = preview.get_node("Controls/AnimationPlayer")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	
	check(player.has_animation("climb_sheathed"), "AnimationPlayer has climb_sheathed animation")
	check(player.has_animation("climb"), "AnimationPlayer has climb animation alias")
	
	var clip: Animation = player.get_animation("climb_sheathed")
	check(clip.get_track_count() == 63, "Climb animation has all 63 tracks")
	
	var layer = preview.rig.run_bone_layer
	check(layer.get_bone_count() == 32, "Native Skeleton2D registers all pose and adjustment bones")
	
	preview.preview_mode = "Climb"
	player.play("climb_sheathed")
	preview._process(0)
	check(preview.actor.climbing, "Preview actor is in climbing mode")
	check(not preview.rig.preview_grounded, "Climbing is not grounded")
	
	# Baseline procedural rig
	var baseline = load("res://scripts/rig.gd").new()
	baseline.editor_preview = true
	baseline.preview_grounded = false
	baseline.fighter = preview.actor
	baseline.run_weight = 0
	baseline.move_weight = 0
	baseline.stand_weight = 0
	root.add_child(baseline)
	baseline.set_process(false)
	
	# Verify neutral bone keys reproduce original procedural climb across 121 samples
	var neutral_samples_passed := true
	for i in 121:
		player.seek(clip.length * i / 121.0, true)
		preview._process(0)
		baseline.clock = preview.rig.clock
		if not same(rendered(baseline), rendered(preview.rig)):
			neutral_samples_passed = false
			check(false, "Neutral climbing artwork transforms reproduce original at sample " + str(i))
			break
	if neutral_samples_passed:
		check(true, "All 121 neutral climbing samples exactly reproduce original procedural artwork")
	
	# Test native Bone2D editing on climbing pose
	player.seek(clip.length / 3.0, true)
	preview._process(0)
	var original := rendered(preview.rig)
	var thigh: Bone2D = layer.bones.RightThigh
	var shin: Bone2D = layer.bones.RightShin
	var foot: Bone2D = layer.bones.RightFoot
	var old_knee: Vector2 = layer.final_transforms.RightShin.origin
	var old_ankle: Vector2 = layer.final_transforms.RightFoot.origin
	
	thigh.rotation = deg_to_rad(-25)
	var changed := rendered(preview.rig)
	check(not same(original, changed), "Thigh rotation changes rendered climbing artwork")
	check(layer.final_transforms.RightShin.origin.distance_to(old_knee) > 5, "Thigh rotation moves the climbing knee")
	check(layer.final_transforms.RightFoot.origin.distance_to(old_ankle) > 5, "Thigh rotation carries the climbing ankle")
	check(is_equal_approx(thigh.rotation, deg_to_rad(-25)), "Procedural pass preserves editable bone rotation")
	check(same(changed, rendered(preview.rig)), "Repeated rendering does not accumulate adjustments")
	
	# Test arm editing on climbing pose
	var forearm: Bone2D = layer.bones.RightForearm
	var old_hand: Vector2 = layer.final_transforms.RightHand.origin
	forearm.rotation = deg_to_rad(30)
	var arm_changed := rendered(preview.rig)
	check(not same(changed, arm_changed), "Forearm rotation changes rendered climbing arm")
	check(layer.final_transforms.RightHand.origin.distance_to(old_hand) > 5, "Forearm rotation moves climbing hand")
	
	# Verify native bone gizmos agree with rendered transforms
	for bone_name in layer.PARENTS:
		var native: Transform2D = layer.global_transform.affine_inverse() * layer.bones[bone_name].global_transform
		var final: Transform2D = layer.final_transforms[bone_name]
		check(native.is_equal_approx(final), "Native bone gizmo agrees with rendered transform: " + bone_name)
	
	# Save edited clip into a copy and test in real gameplay
	var edited_clip: Animation = clip.duplicate(true)
	var library := AnimationLibrary.new()
	library.add_animation("climb_sheathed", edited_clip)
	library.add_animation("climb", edited_clip)
	library.add_animation("run_sheathed", player.get_animation("run_sheathed"))
	player.remove_animation_library("")
	player.add_animation_library("", library)
	
	var controls: Node = preview.get_node("Controls")
	for bone in [thigh, forearm]:
		for property in ["position", "rotation", "scale"]:
			var path := NodePath(str(controls.get_path_to(bone)) + ":" + property)
			var track := edited_clip.find_track(path, Animation.TYPE_VALUE)
			check(track >= 0 and edited_clip.track_get_key_count(track) == 13, "Thirteen native keys for " + str(path))
			edited_clip.track_set_key_value(track, 4, bone.get(property))
	
	player.play("climb_sheathed")
	player.seek(clip.length / 3.0, true)
	preview._process(0)
	var saved_pose := rendered(preview.rig)
	
	# Test actual game integration
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for enemy in game.enemies: enemy.set_physics_process(false)
	var actor = game.player
	actor.position = Vector2(1250, 600) # At first ladder
	for i in 20: await physics_frame
	actor.set_physics_process(false)
	actor.rig.set_process(false)
	actor.weapon_blend = 0
	actor.climbing = true
	actor.running = false
	actor.velocity = Vector2(0, -145)
	actor.gait = TAU / 3.0
	
	var live_player: AnimationPlayer = actor.rig.run_edit_player
	live_player.remove_animation_library("")
	live_player.add_animation_library("", player.get_animation_library(""))
	live_player.play("climb_sheathed")
	
	actor.rig.stand_weight = 0.0
	actor.rig.run_weight = 0.0
	actor.rig.move_weight = 0.0
	actor.rig.clock = preview.rig.clock
	actor.rig._update_skeleton(0)
	actor.rig._update_run_edits()
	check(not actor.rig.skeleton_active, "Skeleton from darkiron.tscn is deactivated during climbing")
	check(actor.rig.run_edit_weight == 1.0, "Climbing bone edits have full weight")
	var actual := rendered(actor.rig)
	if not same(saved_pose, actual):
		print("Differences count: saved=", saved_pose.size(), " actual=", actual.size())
		for i in min(saved_pose.size(), actual.size()):
			if not same([saved_pose[i]], [actual[i]]):
				print("Diff part ", i, " index ", saved_pose[i][0], " saved: ", saved_pose[i][1], " actual: ", actual[i][1])
	check(same(saved_pose, actual), "Actual game applies saved climbing bone edits identically to preview")
	
	actor.facing = -1
	rendered(actor.rig)
	check(actor.rig.scale.x == -1, "Climbing mirrors with gameplay facing")
	
	for node in [preview, baseline, game]: node.queue_free()
	await process_frame
	print("CLIMB BONE EDITS RESULT: ", failures, " failure(s)")
	quit(0 if failures == 0 else 1)
