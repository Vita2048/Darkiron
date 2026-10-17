extends "res://scripts/rig.gd"

# Capture the original renderer's geometry without drawing or changing it.
var captured: Array[Dictionary] = []
func part(index: int, at: Vector2, size: Vector2, angle := 0.0, tint := Color.WHITE) -> void:
	captured.append({"index": index, "at": at, "size": size, "angle": angle, "tint": tint})
