extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in 15: await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	for actor in [game.player]+game.enemies:
		actor.set_physics_process(false)
		actor.rig.set_process(false)
	var rig = game.player.rig
	var armed := "--armed" in OS.get_cmdline_user_args()
	game.player.weapon_blend = 1 if armed else 0
	game.player.facing = -1 if "--left" in OS.get_cmdline_user_args() else 1
	game.player.velocity.x = 300
	rig.move_weight = 1
	rig.stand_weight = 0
	for mode in ["stand","walk","run"]:
		rig.run_weight = 1.0 if mode=="run" else 0.0
		rig.move_weight = 0.0 if mode=="stand" else 1.0
		rig.stand_weight = 1.0 if mode=="stand" else 0.0
		game.player.velocity.x = 0 if mode=="stand" else 300
		var sheet := Image.create(1760,240,false,Image.FORMAT_RGBA8)
		for i in 8:
			game.player.gait = TAU*(i/8.0+0.025)
			game.player.recoil = 0.8 if armed and i%2==1 else 0.0
			rig.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var shot := root.get_texture().get_image()
			var ratio := Vector2(shot.get_size())/root.get_visible_rect().size
			var transform: Transform2D = game.get_global_transform_with_canvas()
			var start: Vector2 = transform*(game.player.position+Vector2(-110,-210))*ratio
			var end: Vector2 = transform*(game.player.position+Vector2(110,30))*ratio
			var crop := shot.get_region(Rect2i(start,end-start))
			crop.resize(220,240,Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(crop,Rect2i(0,0,220,240),Vector2i(i*220,0))
		sheet.save_png("res://preview-"+("left-" if "--left" in OS.get_cmdline_user_args() else "")+("armed-" if armed else "")+mode+"-strip.png")
	game.queue_free()
	await process_frame
	quit()
