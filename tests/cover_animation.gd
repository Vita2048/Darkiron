extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1
func run() -> void:
	var character = load("res://characters/darkiron.tscn").instantiate()
	root.add_child(character)
	var animation: AnimationPlayer = character.get_node("AnimationPlayer")
	var skeleton: Skeleton2D = character.get_node("Skeleton2D")
	check(skeleton.get_bone_count() == 16, "All 16 editable body/weapon bones exist")
	var clip: Animation = animation.get_animation("cover")
	for i in skeleton.get_bone_count():
		var bone := skeleton.get_bone(i)
		var path := str(character.get_path_to(bone))
		check(clip.find_track(NodePath(path+":position"),Animation.TYPE_VALUE)>=0, path+" position track")
		check(clip.find_track(NodePath(path+":rotation"),Animation.TYPE_VALUE)>=0, path+" rotation track")
	animation.play("cover")
	animation.pause()
	animation.seek(0.4,true)
	var shoulder: Bone2D = character.get_node("Skeleton2D/Hip/Torso/RightShoulder")
	var art: Polygon2D = shoulder.get_node("Art")
	var before := art.global_position
	shoulder.position.y -= 6
	for i in 3: await process_frame
	check(art.global_position.distance_to(before)>5, "Artwork immediately follows bone edit without procedural overwrite")
	var track := clip.find_track(NodePath("Skeleton2D/Hip/Torso/RightShoulder:position"),Animation.TYPE_VALUE)
	var key := clip.track_insert_key(track,0.3,shoulder.position)
	var edited := shoulder.position
	animation.seek(0,true)
	animation.seek(0.3,true)
	check(shoulder.position.is_equal_approx(edited), "Scrubbing restores edited keyframe")
	# Save a copy and verify authored edit survives reopening.
	var packed := PackedScene.new()
	check(packed.pack(character)==OK, "Scene packs")
	check(ResourceSaver.save(packed,"res://.runtime/skeleton-save-test.tscn")==OK,"Scene saves")
	var restored = ResourceLoader.load("res://.runtime/skeleton-save-test.tscn","",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
	root.add_child(restored)
	var restored_player: AnimationPlayer = restored.get_node("AnimationPlayer")
	restored_player.play("cover")
	restored_player.pause()
	restored_player.seek(0.3,true)
	check(restored.get_node("Skeleton2D/Hip/Torso/RightShoulder").position.is_equal_approx(edited),"Saved key survives reopen")
	restored.queue_free()
	character.queue_free()
	await process_frame
	var game = load("res://debug_movement.tscn").instantiate()
	root.add_child(game)
	for i in 15: await physics_frame
	var actor = game.player
	actor.set_physics_process(false)
	var rig = actor.rig
	actor.in_cover = true
	rig._process(0.5)
	check(rig.skeleton_active and is_equal_approx(rig.cover_time,0.4),"Gameplay enters and holds authored cover")
	actor.in_cover = false
	rig._process(0.5)
	check(is_equal_approx(rig.cover_time,0.8),"Gameplay completes authored exit")
	actor.velocity.x = 210
	rig._process(0.1)
	check(not rig.skeleton_active and not rig.skeleton_character.visible,"Walking returns to existing locomotion")
	actor.velocity.x = 0
	rig._process(0.1)
	check(rig.skeleton_active,"Standing returns to skeleton")
	game.queue_free()
	await process_frame
	print("Skeleton tests: ",failures," failures")
	quit(failures)
