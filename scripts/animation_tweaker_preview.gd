@tool
extends Node2D
## The editor and F6 render through exactly the same rig as gameplay.
const Actor = preload("res://scripts/animation_tweaker_actor.gd")
const Rig = preload("res://scripts/rig.gd")
const BowRig = preload("res://scripts/bow_range_rig.gd")
@export_range(-57.2958, 34.3775) var bow_aim_degrees := 0.0
var showing_bow := false
@export var face_left := false
@export_enum("Auto", "Run", "Climb") var preview_mode: String = "Auto"
@export var playback_clip := "run_sheathed"
var actor: CharacterBody2D
var rig: Node2D

func _ready() -> void:
	actor = Actor.new()
	actor.collision_layer = 0
	actor.collision_mask = 0
	add_child(actor, false, Node.INTERNAL_MODE_BACK)
	rig = Rig.new()
	rig.editor_preview = true
	rig.fighter = actor
	rig.run_controls = $Controls
	rig.run_bone_layer = $Controls/Skeleton2D
	actor.add_child(rig)
	if not Engine.is_editor_hint():
		$Controls/AnimationPlayer.play("climb_sheathed" if preview_mode == "Climb" else playback_clip)
	_process(0)

func _process(_dt: float) -> void:
	if not is_instance_valid(rig): return
	var player: AnimationPlayer = $Controls/AnimationPlayer
	var clip: String = player.assigned_animation
	if clip.is_empty(): clip = playback_clip
	if preview_mode == "Climb": clip = "climb_sheathed"
	elif preview_mode == "Run": clip = "run_sheathed"
	var wants_bow := clip.begins_with("bow_")
	if wants_bow != showing_bow:
		rig.free()
		rig = BowRig.new() if wants_bow else Rig.new()
		rig.editor_preview = true
		rig.fighter = actor
		rig.run_controls = $Controls
		rig.run_bone_layer = $Controls/Skeleton2D
		actor.add_child(rig)
		showing_bow = wants_bow
	var phase: float = $Controls.phase
	var length: float = player.get_animation(clip).length if player.has_animation(clip) else 1.0
	actor.climbing = clip.begins_with("climb")
	actor.crouching = clip.begins_with("crouch")
	actor.in_cover = clip.begins_with("cover") or clip == "bow_cover"
	actor.running = clip.begins_with("run")
	actor.health = 0.0 if clip == "death" else 100.0
	actor.dead_time = phase * length if clip == "death" else 0.0
	actor.weapon_blend = 1.0 if clip.ends_with("_drawn") else 0.0
	actor.recoil = 1.0 - phase if clip == "recoil_drawn" else 0.0
	actor.bow_angle = deg_to_rad(bow_aim_degrees)
	actor.bow_charge = phase if clip == "bow_draw" else 0.0
	var moving: bool = actor.running or clip.begins_with("walk")
	actor.velocity = Vector2(330 if actor.running else 210, 0) if moving else Vector2.ZERO
	rig.preview_grounded = not actor.climbing and not clip.begins_with("air")
	rig.run_weight = 1.0 if actor.running else 0.0
	rig.move_weight = 1.0 if moving else 0.0
	rig.cover_weight = 1.0 if actor.in_cover else 0.0
	rig.stand_weight = 1.0 if clip.begins_with("idle") or clip in ["recoil_drawn", "bow_draw"] else 0.0
	rig.run_edit_weight = 1.0
	actor.gait = phase * TAU
	actor.facing = -1.0 if face_left else 1.0
	rig.clock = phase * length
	rig.queue_redraw()
	# Align editor bone gizmos with the rendered cover/death transforms.
	rig.run_bone_layer.transform = Transform2D(
		-actor.facing * minf(actor.dead_time * 4, PI/2) if clip == "death" else 0.0,
		Vector2(actor.facing * lerpf(1.0, .83, rig.cover_weight), lerpf(1.0, .96, rig.cover_weight)),
		0.0, Vector2(0, -12) if clip == "death" else Vector2.ZERO)
