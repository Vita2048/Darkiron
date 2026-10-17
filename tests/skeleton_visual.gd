extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1500,600)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var bg := ColorRect.new()
	bg.color = Color(0.22,0.24,0.28)
	bg.size = Vector2(1500,600)
	viewport.add_child(bg)
	for i in 5:
		var character = load("res://characters/darkiron.tscn").instantiate()
		character.position = Vector2(150+i*300,530)
		character.scale = Vector2.ONE*2.5
		viewport.add_child(character)
		var player: AnimationPlayer = character.get_node("AnimationPlayer")
		player.play("cover")
		player.pause()
		player.seek(i*.2,true)
		var label := Label.new()
		label.position = Vector2(75+i*300,550)
		label.text = ["0.0s STANDING","0.2s ENTER","0.4s COVER","0.6s EXIT","0.8s STANDING"][i]
		viewport.add_child(label)
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://preview-skeleton-cover.png")
	quit()
