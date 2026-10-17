extends Node2D
## Movement debug playground for the Darkiron hero (Darkonian).
##
## - Spawns the exact same Fighter used in game.gd (hero, non-enemy).
## - Reuses the exact same game input bindings (arrows / Shift / Space / S / J / F / G ...).
## - Adds non-conflicting debug keys + clickable buttons to stop / slow / step animation:
##     P or 0 or ESC .... pause / resume (full stop)
##     . or N ............ advance exactly one physics frame while paused
##     - / = ............. slower / faster time scale
##     1..5 .............. jump to 0.05 / 0.10 / 0.25 / 0.50 / 1.00 speed
##     Z ................. cycle camera zoom 1x / 2x / 3x
##     R ................. reset player to start (same key as game restart)
##     F11 ............... fullscreen (same as game)
##
## Open debug_movement.tscn and press Play (F6 for single scene) to use it.
## The main game scene (main.tscn) is untouched.

const FighterScript = preload("res://scripts/fighter.gd")

const LEVEL_END := 3000.0
const START_POS := Vector2(260, 720)

var platforms: Array[Rect2] = [Rect2(-2000, 720, 5000, 220)]
var barriers: Array = []
var ladders := [Vector3(600, 480, 720)]
var completed := false
var paused := false # world.paused stub; real freeze uses get_tree().paused
var camera_x := START_POS.x
var shake := 0.0
var kills := 0
var grenades_left := 99
var rng := RandomNumberGenerator.new()
var font: Font = ThemeDB.fallback_font
var _previous_clear_color := Color.BLACK

var player: CharacterBody2D
var camera: Camera2D

# Slow-motion state. Engine.time_scale slows physics + gait together,
# so stride length / foot planting stay consistent, just slower.
var time_scales := [0.05, 0.1, 0.25, 0.5, 1.0]
var speed_idx := 4
var zoom_levels := [1.0, 2.0, 3.0]
var zoom_idx := 1
var clock := 0.0
var trail: Array[Vector2] = []
var flashes: Array = [] # muzzle / grenade markers {p, life, c}
var last_shot_age := 999.0
var last_grenade_age := 999.0
var _stepping := false

# UI nodes (CanvasLayer is PROCESS_MODE_ALWAYS so buttons work while paused).
var ui_layer: CanvasLayer
var info_label: Label
var state_label: Label
var help_label: Label
var pause_btn: Button
var speed_label: Label


func _ready() -> void:
	# ALWAYS so the overlay refreshes and buttons work while the tree is paused.
	# The player itself stays pausable, so pause == full animation stop.
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 1234
	Engine.time_scale = 1.0
	get_tree().paused = false
	# White backdrop for silhouette inspection. Restored on scene exit so the
	# game keeps its own clear color.
	_previous_clear_color = RenderingServer.get_default_clear_color()
	RenderingServer.set_default_clear_color(Color.WHITE)
	_setup_input()
	for rect in platforms:
		_make_solid(rect)
	player = FighterScript.new()
	player.world = self
	player.skeleton_character = $Darkiron
	player.position = START_POS
	# Explicit: debug root is PROCESS_MODE_ALWAYS (so keys/labels work while
	# paused), but INHERIT would leak ALWAYS onto the player and its rig,
	# keeping the animation running during pause. Force pausable instead.
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	camera = Camera2D.new()
	camera.position = Vector2(START_POS.x, 600)
	camera.zoom = Vector2.ONE * zoom_levels[zoom_idx]
	add_child(camera)
	camera.make_current()
	_build_ui()
	_refresh_pause_button()
	_refresh_speed_label()


func _setup_input() -> void:
	# Identical game bindings (copied from game.gd so keys never drift).
	var bindings := {"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN], "toggle_weapon": [KEY_S], "jump": [KEY_SPACE], "shoot": [KEY_J, KEY_F], "grenade": [KEY_G], "run": [KEY_SHIFT], "restart": [KEY_R], "pause_game": [KEY_ESCAPE], "mute": [KEY_M], "continue_game": [KEY_ENTER]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("shoot", mouse)
	if not InputMap.has_action("fullscreen"):
		InputMap.add_action("fullscreen")
	InputMap.action_erase_events("fullscreen")
	var fullscreen_key := InputEventKey.new()
	fullscreen_key.physical_keycode = KEY_F11
	InputMap.action_add_event("fullscreen", fullscreen_key)
	# Debug-only actions. Keys chosen to never overlap the game bindings above.
	_ensure_debug_action("debug_pause", [KEY_P, KEY_0])
	_ensure_debug_action("debug_step", [KEY_PERIOD, KEY_N])
	_ensure_debug_action("debug_slower", [KEY_MINUS])
	_ensure_debug_action("debug_faster", [KEY_EQUAL])
	_ensure_debug_action("debug_zoom", [KEY_Z])
	_ensure_debug_action("debug_ui", [KEY_H])
	_ensure_debug_action("debug_speed_1", [KEY_1])
	_ensure_debug_action("debug_speed_2", [KEY_2])
	_ensure_debug_action("debug_speed_3", [KEY_3])
	_ensure_debug_action("debug_speed_4", [KEY_4])
	_ensure_debug_action("debug_speed_5", [KEY_5])


func _ensure_debug_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func _make_solid(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	return body


# --- Minimal world API required by fighter.gd / dropped_weapon.gd ---

func ladder_at(at: Vector2) -> Vector3:
	for ladder in ladders:
		if absf(at.x - ladder.x) < 40 and at.y >= ladder.y - 10 and at.y <= ladder.z + 13:
			return ladder
	return Vector3.ZERO


func sound(_kind: String) -> void:
	pass


func burst(_at: Vector2, _color: Color, _count: int) -> void:
	pass


func fire_bullet(actor: CharacterBody2D) -> void:
	last_shot_age = 0.0
	flashes.append({"p": actor.muzzle(), "life": 0.18, "c": Color("35bfff")})


func throw_grenade(actor: CharacterBody2D) -> void:
	last_grenade_age = 0.0
	flashes.append({"p": actor.position + Vector2(actor.facing * 30, -110), "life": 0.4, "c": Color("ffd185")})


# --- Debug controls ---

func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	# Sync the world.paused stub too: fighter/rig check it directly, so this
	# freezes them even if a node ever ends up non-pausable again.
	paused = get_tree().paused
	_refresh_pause_button()


func set_speed_idx(idx: int) -> void:
	speed_idx = clampi(idx, 0, time_scales.size() - 1)
	Engine.time_scale = time_scales[speed_idx]
	_refresh_speed_label()


func cycle_zoom() -> void:
	zoom_idx = (zoom_idx + 1) % zoom_levels.size()
	camera.zoom = Vector2.ONE * zoom_levels[zoom_idx]


func step_one_frame() -> void:
	if not get_tree().paused or _stepping:
		return
	_stepping = true
	# Unblock both freeze paths (tree pause and the world.paused stub that
	# fighter.gd checks) for exactly one physics tick.
	paused = false
	get_tree().paused = false
	await get_tree().physics_frame
	get_tree().paused = true
	paused = true
	_stepping = false
	_refresh_pause_button()


func reset_player() -> void:
	# Same meaning as R in the game, but without reloading the scene
	# (keeps time scale / zoom / trail settings intact).
	player.position = START_POS
	player.velocity = Vector2.ZERO
	player.health = 100.0
	player.dead_time = 0.0
	player.facing = 1.0
	player.climbing = false
	player.in_cover = false
	player.crouching = false
	player.collision_mask = 1
	player.weapon_drawn = true
	player.weapon_blend = 1.0
	player.weapon_transition = 0.0
	player.recoil = 0.0
	player.gait = 0.0
	player.rig.rotation = 0
	player.rig.position = Vector2.ZERO
	player.rig.modulate = Color.WHITE
	camera_x = START_POS.x
	trail.clear()
	flashes.clear()
	for child in get_children():
		if child.get_script() != null and child.get("settled") != null:
			child.queue_free()


func toggle_fullscreen() -> void:
	var window := get_window()
	window.mode = Window.MODE_MAXIMIZED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN


func _physics_process(dt: float) -> void:
	if get_tree().paused:
		return
	clock += dt
	last_shot_age += dt
	last_grenade_age += dt
	for i in range(flashes.size() - 1, -1, -1):
		flashes[i].life -= dt
		if flashes[i].life <= 0:
			flashes.remove_at(i)
	# Smooth follow on X, fixed height so the full stride stays in frame.
	camera_x = lerpf(camera_x, player.position.x, 1.0 - exp(-dt * 6.0))
	camera.position = Vector2(camera_x, 600)
	trail.append(player.position)
	while trail.size() > 400:
		trail.pop_front()
	queue_redraw()


func _process(_dt: float) -> void:
	_enforce_pausable_props()
	if Input.is_action_just_pressed("fullscreen"):
		toggle_fullscreen()
	if Input.is_action_just_pressed("restart"):
		reset_player()
	# ESC behaves exactly like the game pause key: it stops the animation.
	if Input.is_action_just_pressed("pause_game") or Input.is_action_just_pressed("debug_pause"):
		toggle_pause()
	if Input.is_action_just_pressed("debug_step"):
		step_one_frame()
	if Input.is_action_just_pressed("debug_slower"):
		set_speed_idx(speed_idx - 1)
	if Input.is_action_just_pressed("debug_faster"):
		set_speed_idx(speed_idx + 1)
	if Input.is_action_just_pressed("debug_zoom"):
		cycle_zoom()
	if Input.is_action_just_pressed("debug_ui") and is_instance_valid(ui_layer):
		ui_layer.visible = not ui_layer.visible
	for i in 5:
		if Input.is_action_just_pressed("debug_speed_" + str(i + 1)):
			set_speed_idx(i)
	_update_labels()
	queue_redraw()


func _enforce_pausable_props() -> void:
	# Dropped weapons are added to the debug root (ALWAYS) by fighter.gd, so
	# they would inherit ALWAYS and keep falling during pause. Pin them back.
	for child in get_children():
		if child.get("settled") != null and child.process_mode != Node.PROCESS_MODE_PAUSABLE:
			child.process_mode = Node.PROCESS_MODE_PAUSABLE


func _state_name() -> String:
	if player.health <= 0:
		return "DEAD"
	if player.climbing:
		return "CLIMB"
	if not player.is_on_floor():
		return "AIR"
	if player.in_cover:
		return "COVER"
	if player.crouching:
		return "CROUCH"
	if absf(player.velocity.x) > 12:
		return "RUN" if player.running else "WALK"
	return "IDLE"


func _update_labels() -> void:
	if not is_instance_valid(info_label):
		return
	var rig = player.rig
	var frozen := "PAUSED" if get_tree().paused else "RUNNING"
	info_label.text = "DARKIRON MOVEMENT DEBUG  [%s  %.2fx  zoom %.0fx]\n" % [frozen, Engine.time_scale, zoom_levels[zoom_idx]]
	info_label.text += "pos (%.1f, %.1f)  vel (%.1f, %.1f)  floor %s  facing %+.0f\n" % [player.position.x, player.position.y, player.velocity.x, player.velocity.y, str(player.is_on_floor()), player.facing]
	info_label.text += "state %s  gait %.2f rad  run_w %.2f move_w %.2f stand_w %.2f\n" % [_state_name(), player.gait, rig.run_weight, rig.move_weight, rig.stand_weight]
	info_label.text += "input L/R %d/%d run %d jump %d up %d down %d shoot %d\n" % [int(Input.is_action_pressed("left")), int(Input.is_action_pressed("right")), int(Input.is_action_pressed("run")), int(Input.is_action_pressed("jump")), int(Input.is_action_pressed("up")), int(Input.is_action_pressed("down")), int(Input.is_action_pressed("shoot"))]
	var shot := "SHOOT key OK" if last_shot_age < 1.0 else "press J/F/click to test muzzle"
	var bomb := "GRENADE key OK" if last_grenade_age < 1.0 else "press G to test throw"
	state_label.text = "%s   |   %s   |   weapon %s" % [shot, bomb, "drawn" if player.weapon_drawn else "sheathed"]
	speed_label.text = "speed %.2fx" % Engine.time_scale


func _exit_tree() -> void:
	RenderingServer.set_default_clear_color(_previous_clear_color)
	Engine.time_scale = 1.0
	get_tree().paused = false


func _draw() -> void:
	# Intentionally empty: just the player, no rulers, trails, arrows,
	# markers, or flashes in the world view.
	pass


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(root)
	# Top-left status readout.
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.06, 0.88)
	bg.position = Vector2(10, 10)
	bg.size = Vector2(640, 150)
	bg.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(bg)
	info_label = Label.new()
	info_label.position = Vector2(20, 16)
	info_label.size = Vector2(620, 110)
	info_label.add_theme_font_size_override("font_size", 15)
	info_label.add_theme_color_override("font_color", Color("d5deea"))
	info_label.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(info_label)
	state_label = Label.new()
	state_label.position = Vector2(20, 118)
	state_label.size = Vector2(620, 28)
	state_label.add_theme_font_size_override("font_size", 14)
	state_label.add_theme_color_override("font_color", Color("e8b47e"))
	state_label.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(state_label)
	# Bottom help bar: same game keys + debug keys.
	var help_bg := ColorRect.new()
	help_bg.color = Color(0.02, 0.03, 0.06, 0.92)
	help_bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	help_bg.offset_top = -64
	help_bg.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(help_bg)
	help_label = Label.new()
	help_label.text = "GAME KEYS (same as level): ARROWS move/climb  SHIFT run  SPACE jump  S draw/sheathe  UP cover  DOWN crouch  J/F/click shoot  G bomb  R reset  ESC pause  F11 fullscreen\nDEBUG: P/0 pause   . /N step 1 frame   -/= slower/faster   1-5 speed 0.05-1.0x   Z zoom   H hide UI   |  ladder at x=600: sheathe (S) then UP/DOWN to climb"
	help_label.add_theme_font_size_override("font_size", 13)
	help_label.add_theme_color_override("font_color", Color("acbaca"))
	help_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	help_label.offset_left = 16
	help_label.offset_right = -16
	help_label.offset_top = -60
	help_label.offset_bottom = -6
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(help_label)
	# Right-side button column (mouse alternative to debug keys).
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	box.position = Vector2(-10, 10)
	box.offset_left = -220
	box.offset_right = -10
	box.offset_top = 10
	box.add_theme_constant_override("separation", 6)
	box.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(box)
	pause_btn = _make_button(box, "Pause", toggle_pause)
	_make_button(box, "Step 1 frame", step_one_frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.process_mode = Node.PROCESS_MODE_ALWAYS
	box.add_child(row)
	_make_button(row, "-", func() -> void: set_speed_idx(speed_idx - 1))
	speed_label = Label.new()
	speed_label.custom_minimum_size = Vector2(84, 0)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_label.add_theme_font_size_override("font_size", 14)
	speed_label.process_mode = Node.PROCESS_MODE_ALWAYS
	row.add_child(speed_label)
	_make_button(row, "+", func() -> void: set_speed_idx(speed_idx + 1))
	var speeds := HBoxContainer.new()
	speeds.add_theme_constant_override("separation", 4)
	speeds.process_mode = Node.PROCESS_MODE_ALWAYS
	box.add_child(speeds)
	for i in 5:
		var idx := i
		_make_button(speeds, str(time_scales[i]) + "x", func() -> void: set_speed_idx(idx))
	_make_button(box, "Reset (R)", reset_player)
	_make_button(box, "Zoom (Z)", cycle_zoom)


func _make_button(parent: Control, text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn


func _refresh_pause_button() -> void:
	if is_instance_valid(pause_btn):
		pause_btn.text = "Resume (P)" if get_tree().paused else "Pause (P)"


func _refresh_speed_label() -> void:
	if is_instance_valid(speed_label):
		speed_label.text = "speed %.2fx" % Engine.time_scale
