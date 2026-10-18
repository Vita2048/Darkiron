extends SceneTree
var failures := 0
const SAVE := "res://.runtime/test-audio-settings.cfg"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func make_game() -> Node2D:
	var game = load("res://main.tscn").instantiate()
	game.settings_path = SAVE
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	return game
func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var game := make_game()
	check(is_equal_approx(game.master_volume,1),"Fresh settings default to full volume")
	await process_frame
	await process_frame
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	game._process(0)
	check(game.paused,"Esc opens pause screen")
	escape = escape.duplicate()
	escape.pressed = false
	Input.parse_input_event(escape)
	game.ui._sync_pause_controls()
	check(game.ui.pause_controls.visible,"Pause screen shows slider")
	game.ui.volume_slider.value = 37
	check(is_equal_approx(AudioServer.get_bus_volume_linear(0),.37),"Slider adjusts game bus immediately")
	check(game.audio_settings_saved,"Slider saves successfully")
	game.queue_free()
	await process_frame
	game = make_game()
	check(is_equal_approx(game.master_volume,.37),"Volume restored in fresh game instance")
	game.set_master_volume(0)
	check(AudioServer.is_bus_mute(0),"Zero volume is silent")
	game.set_master_volume(.62)
	check(not AudioServer.is_bus_mute(0),"Raising volume restores audio")
	game.muted = true
	game._apply_master_volume()
	game._save_audio_settings()
	game.queue_free()
	await process_frame
	game = make_game()
	check(game.muted and is_equal_approx(game.master_volume,.62),"Mute and selected volume persist")
	game.paused = true
	game.ui._sync_pause_controls()
	check(game.ui.volume_slider.value==0,"Muted slider displays zero")
	game.ui.volume_slider.value = 45
	check(not game.muted and not AudioServer.is_bus_mute(0),"Slider can unmute after M shortcut")
	if "--visual" in OS.get_cmdline_user_args():
		game.ui.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/pause-volume.png")
	await process_frame
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	game._process(0)
	check(not game.paused,"Esc resumes gameplay")
	escape = escape.duplicate()
	escape.pressed = false
	Input.parse_input_event(escape)
	game.ui._sync_pause_controls()
	check(not game.ui.pause_controls.visible,"Resume hides slider")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	AudioServer.set_bus_volume_linear(0,1)
	AudioServer.set_bus_mute(0,false)
	print("PAUSE AUDIO: ",failures," failures")
	quit(failures)
