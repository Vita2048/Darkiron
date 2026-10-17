@tool
extends Node2D
## Preview uses the actual procedural renderer, with explicit grounded state.
const Actor = preload("res://scripts/cover_preview_actor.gd")
const Rig = preload("res://scripts/rig.gd")
@export var face_left := false
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
		$Controls/AnimationPlayer.play("run_sheathed")
	_process(0)

func _process(_dt: float) -> void:
	if not is_instance_valid(rig): return
	actor.gait = $Controls.phase * TAU
	actor.facing = -1.0 if face_left else 1.0
	# Preview bones live beside the actor; mirror their editor gizmos with the art.
	rig.run_bone_layer.scale.x = actor.facing
	rig.clock = $Controls.phase * TAU * Rig.RUN_DISTANCE_PER_RADIAN / 330.0
	rig.queue_redraw()
	queue_redraw()

func _draw() -> void:
	draw_line(Vector2(-130, 0), Vector2(130, 0), Color("708392"), 0.5)
