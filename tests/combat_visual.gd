extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in 20: await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	for actor in [game.player]+game.enemies:
		actor.set_physics_process(false)
		actor.rig.set_process(false)
	game.enemies[0].facing = -1
	game.enemies[0].rig.queue_redraw()
	game.bullets = [{"p":Vector2(495,602),"v":Vector2(1100,0),"enemy":false,"life":1.0},{"p":Vector2(665,616),"v":Vector2(-1100,0),"enemy":true,"life":1.0}]
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview-combat-glow.png")
	game.queue_free()
	await process_frame
	quit()
