@tool
extends Node2D
## Preview uses the actual procedural renderer, with explicit grounded state.
const Actor = preload("res://scripts/cover_preview_actor.gd")
const Rig = preload("res://scripts/rig.gd")
@export var face_left := false
@export_enum("Auto", "Run", "Climb") var preview_mode: String = "Auto"
var actor: CharacterBody2D
var rig: Node2D

func _ready() -> void:
	actor = Actor.new()
	actor.in_cover = false
	actor.running = true
	actor.weapon_blend = 0.0
	actor.velocity = Vector2(330, 0)
	actor.collision_layer = 0
	actor.collision_mask = 0
	add_child(actor, false, Node.INTERNAL_MODE_BACK)
	rig = Rig.new()
	rig.editor_preview = true
	rig.preview_grounded = true
	rig.fighter = actor
	rig.run_controls = $Controls
	rig.run_bone_layer = $Controls/Skeleton2D
	rig.run_edit_weight = 1.0
	rig.run_weight = 1.0
	rig.move_weight = 1.0
	rig.stand_weight = 0.0
	actor.add_child(rig)
	if not Engine.is_editor_hint():
		var play_clip := "climb_sheathed" if preview_mode == "Climb" else "run_sheathed"
		if not $Controls/AnimationPlayer.has_animation(play_clip):
			play_clip = "run_sheathed"
		$Controls/AnimationPlayer.play(play_clip)
	_process(0)

func _process(_dt: float) -> void:
	if not is_instance_valid(rig): return
	var player: AnimationPlayer = $Controls/AnimationPlayer
	var clip_name := ""
	if is_instance_valid(player):
		clip_name = player.assigned_animation
		if clip_name.is_empty():
			clip_name = player.current_animation
	var is_climbing: bool = preview_mode == "Climb" or (preview_mode == "Auto" and clip_name.begins_with("climb"))
	actor.climbing = is_climbing
	actor.running = not is_climbing
	actor.velocity = Vector2(0, 145) if is_climbing else Vector2(330, 0)
	rig.preview_grounded = not is_climbing
	rig.run_weight = 0.0 if is_climbing else 1.0
	rig.move_weight = 0.0 if is_climbing else 1.0
	rig.stand_weight = 0.0
	rig.run_edit_weight = 1.0
	actor.gait = $Controls.phase * TAU
	actor.facing = -1.0 if face_left else 1.0
	# Preview bones live beside the actor; mirror their editor gizmos with the art.
	rig.run_bone_layer.scale.x = actor.facing
	if is_climbing:
		rig.clock = $Controls.phase * TAU * 25.0 / 145.0
	else:
		rig.clock = $Controls.phase * TAU * Rig.RUN_DISTANCE_PER_RADIAN / 330.0
	rig.queue_redraw()
	queue_redraw()

func _draw() -> void:
	if is_instance_valid(actor) and actor.climbing:
		draw_line(Vector2(-24, -160), Vector2(-24, 20), Color("4a5968"), 2.0)
		draw_line(Vector2(24, -160), Vector2(24, 20), Color("4a5968"), 2.0)
		for y in range(-150, 20, 28):
			draw_line(Vector2(-24, y), Vector2(24, y), Color("8a7a58"), 2.0)
	else:
		draw_line(Vector2(-130, 0), Vector2(130, 0), Color("708392"), 0.5)
