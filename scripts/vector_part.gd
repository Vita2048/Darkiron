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
			# Shape the chest and lower thigh without widening the hip socket.
			for i in baker.vertices.size():
				var vertex: Vector3 = baker.vertices[i]
				if index == 1:
					vertex.x *= lerpf(0.90,1.0,clampf(vertex.y/65.0,0,1))
				elif index == 6:
					vertex.x *= 1.0+0.16*smoothstep(15.0,65.0,vertex.y)
				baker.vertices[i] = vertex
			meshes[index] = baker.build()
		queue_redraw()
func _draw() -> void:
	draw_mesh(meshes[index],null)
