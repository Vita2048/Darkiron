extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	assert(Engine.is_editor_hint(), "Run this test with --editor")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var pose = load("res://animations/armed_cover.tscn").instantiate()
	pose.position = Vector2(360,620)
	pose.scale = Vector2.ONE * 3
	viewport.add_child(pose)
	for i in 8: await process_frame
	assert(is_instance_valid(pose.preview_rig))
	assert(pose.preview_actor.owner == null)
	assert(pose.preview_rig.cover_player == null, "Preview must not take over timeline playback")
	var player: AnimationPlayer = pose.get_node("AnimationPlayer")
	var animation: Animation = player.get_animation("armed_cover")
	var track := animation.find_track(NodePath("Torso/RightShoulder:position"),Animation.TYPE_VALUE)
	animation.track_insert_key(track,0.5,Vector2(-9,-3))
	player.play("armed_cover")
	player.pause()
	player.seek(0.5,true)
	for i in 4: await process_frame
	assert(pose.get_node("Torso/RightShoulder").position == Vector2(-9,-3))
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		assert(pose.preview_rig.parts.size() > 0)
		var found := false
		var expected: Vector2 = pose.get_node("Hip").position + pose.get_node("Torso").position + Vector2(-9,-3)
		for part in pose.preview_rig.parts:
			if part.index == 3 and part.position.is_equal_approx(expected):
				found = true
		assert(found, "Artwork must use scrubbed shoulder position")
		viewport.get_texture().get_image().save_png("res://preview-cover-editor.png")
	player.seek(0,true)
	for i in 3: await process_frame
	assert(pose.get_node("Torso/RightShoulder").position == Vector2(-9,9))
	pose.preview_face_left = true
	for i in 3: await process_frame
	assert(pose.preview_actor.facing == -1)
	var packed := PackedScene.new()
	assert(packed.pack(pose) == OK)
	for i in packed.get_state().get_node_count():
		assert(not "EditorCharacterPreview" in str(packed.get_state().get_node_path(i)))
	print("PASS: editor tool preview, scrubbed shoulder, facing, no saved preview nodes")
	viewport.queue_free()
	await process_frame
	quit()
