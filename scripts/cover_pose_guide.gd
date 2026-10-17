@tool
extends Node2D
## Actual game renderer, driven by the same pose anchors the timeline edits.
const PreviewActor = preload("res://scripts/animation_tweaker_actor.gd")
const Rig = preload("res://scripts/rig.gd")
@export var preview_face_left := false:
	set(value):
		preview_face_left = value
		if is_instance_valid(preview_actor):
			preview_actor.facing = -1.0 if value else 1.0
var preview_actor: CharacterBody2D
var preview_rig: Node2D

func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("create_preview")

func create_preview() -> void:
	if is_instance_valid(preview_actor) or not has_node("Torso/RightShoulder"):
		return
	preview_actor = PreviewActor.new()
	preview_actor.name = "EditorCharacterPreview"
	preview_actor.facing = -1.0 if preview_face_left else 1.0
	preview_actor.collision_layer = 0
	preview_actor.collision_mask = 0
	# Internal, ownerless children are neither saved nor exposed as editable scene data.
	add_child(preview_actor, false, Node.INTERNAL_MODE_BACK)
	preview_rig = Rig.new()
	preview_rig.name = "PreviewRig"
	preview_rig.editor_preview = true
	preview_rig.fighter = preview_actor
	preview_rig.cover_pose = self
	preview_rig.cover_weight = 1.0
	preview_rig.stand_weight = 0.0
	preview_actor.add_child(preview_rig)
