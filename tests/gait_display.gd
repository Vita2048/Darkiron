extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,message: String) -> void:
	if ok:
		print("PASS: "+message)
	else:
		push_error("FAIL: "+message)
		failures += 1

func frames(count: int) -> void:
	for i in count:
		await process_frame

func capture(name: String) -> void:
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://"+name+".png")

func run() -> void:
	# Reproduce a host/editor launching with a small unscaled content area.
	root.content_scale_size = Vector2i(640,360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_factor = 0.5
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(15)
	var rig = game.player.rig
	var walk_supported := true
	var run_extended := true
	for i in range(100):
		var phase := float(i)/100*TAU
		var f: Vector2 = rig.walk_angles(phase)
		var b: Vector2 = rig.walk_angles(phase+PI)
		walk_supported = walk_supported and minf(absf(f.x-f.y),absf(b.x-b.y))<deg_to_rad(12)
		if i<=33:
			var r: Vector2 = rig.run_angles(phase)
			run_extended = run_extended and absf(r.x-r.y)<deg_to_rad(12)
	check(walk_supported,"walking keeps an extended supporting leg throughout the stride")
	check(run_extended,"running extends the weight-bearing leg during contact")
	var recovery: Vector2 = rig.run_angles(TAU*0.625)
	check(absf(recovery.x-recovery.y)>deg_to_rad(90),"running retains folded heel recovery")
	check(root.content_scale_size==Vector2i(1920,1080),"base canvas is 1920 by 1080")
	check(root.content_scale_aspect==Window.CONTENT_SCALE_ASPECT_IGNORE,"window stretch fills the available area")
	check(root.content_scale_mode==Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and root.content_scale_factor==1.0,"runtime restores scaling even after small-canvas overrides")
	# Compare actual rendered world positions, not just the configured zoom.
	var a: Vector2 = game.get_global_transform_with_canvas()*Vector2(0,0)
	var b: Vector2 = game.get_global_transform_with_canvas()*Vector2(1440,900)
	check((b-a).distance_to(Vector2(1920,1080))<1,"camera maps the full scene to the HD canvas")
	game.set_process(false)
	game.set_physics_process(false)
	for actor in [game.player]+game.enemies:
		actor.set_physics_process(false)
		actor.rig.set_process(false)
	rig.move_weight = 1
	rig.stand_weight = 0
	game.player.weapon_drawn = false
	game.player.weapon_blend = 0
	game.player.velocity = Vector2(210,0)
	for mode in ["walk","run"]:
		rig.run_weight = 1.0 if mode=="run" else 0.0
		for i in range(4):
			game.player.gait = TAU*i/8.0
			rig.queue_redraw()
			await frames(2)
			await capture("preview-"+mode+"-hd-"+str(i))
	# Exercise resize at two aspect ratios while the scene remains loaded.
	if "--visual" in OS.get_cmdline_user_args():
		root.mode = Window.MODE_WINDOWED
		await frames(5)
		root.size = Vector2i(1600,900)
		await frames(5)
		await capture("preview-resize-16-9")
		root.size = Vector2i(1200,900)
		await frames(5)
		await capture("preview-resize-4-3")
		root.mode = Window.MODE_MAXIMIZED
		await frames(15)
		await capture("preview-maximized")
		game.toggle_fullscreen()
		await frames(15)
		check(root.mode==Window.MODE_FULLSCREEN,"fullscreen toggle enters fullscreen")
		await capture("preview-fullscreen")
		game.toggle_fullscreen()
		await frames(15)
		check(root.mode==Window.MODE_MAXIMIZED,"fullscreen toggle returns to maximized window")
	print("GAIT/DISPLAY RESULT: ",failures," failure(s)")
	game.queue_free()
	await frames(3)
	quit(0 if failures==0 else 1)
