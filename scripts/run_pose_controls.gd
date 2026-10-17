@tool
extends Node2D
## Additive edits in character-local pixels/degrees. Zero reproduces the original.
@export_range(0, 1) var phase := 0.0
@export var hip_offset := Vector2.ZERO
@export var torso_offset := Vector2.ZERO
@export var torso_lean_degrees := 0.0
@export var head_tilt_degrees := 0.0
@export var front_foot_offset := Vector2.ZERO
@export var back_foot_offset := Vector2.ZERO
@export var front_foot_pitch_degrees := 0.0
@export var back_foot_pitch_degrees := 0.0
@export var front_arm_swing_degrees := 0.0
@export var back_arm_swing_degrees := 0.0
@export var front_elbow_bend_degrees := 0.0
@export var back_elbow_bend_degrees := 0.0
@export var weapon_offset := Vector2.ZERO
@export var weapon_tilt_degrees := 0.0
