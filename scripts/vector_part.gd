extends Node2D
## Shared, retained vector meshes. Only transforms change during animation.
const Armor = preload("res://scripts/vector_armor.gd")
const Baker = preload("res://scripts/vector_mesh.gd")
static var meshes: Dictionary = {}
var index := -1
func configure(value: int) -> void:
	if index != value:
		index = value
		if not meshes.has(index):
			var baker := Baker.new()
			Armor.new().paint(baker,index,Color.WHITE)
			meshes[index] = baker.build()
		queue_redraw()
func _draw() -> void:
	draw_mesh(meshes[index],null)
