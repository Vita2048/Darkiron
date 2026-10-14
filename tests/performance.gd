extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 30:
		await process_frame
	for actor in [game.player]+game.enemies:
		actor.set_physics_process(false)
	var started := Time.get_ticks_usec()
	var process_ms := 0.0
	var draws := 0.0
	for i in 180:
		game.player.gait += 0.12
		game.player.velocity.x = 210
		await process_frame
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS)*1000
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var elapsed := (Time.get_ticks_usec()-started)/1000000.0
	var result := {"fps":180/elapsed,"frame_ms":elapsed*1000/180,"process_ms":process_ms/180,"draw_calls":draws/180,"window":str(root.size)}
	print("PERFORMANCE: ",JSON.stringify(result))
	var suffix := "before" if "--before" in OS.get_cmdline_user_args() else "after"
	var file := FileAccess.open("res://tests/performance-"+suffix+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	game.queue_free()
	await process_frame
	quit()
