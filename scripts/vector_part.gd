extends Node2D
## Shared, retained vector meshes. Only transforms change during animation.
const Armor = preload("res://scripts/vector_armor.gd")
const Baker = preload("res://scripts/vector_mesh.gd")
static var meshes: Dictionary = {}
var index := -1
var drake := false
var mesh_key := -1
const Drake = preload("res://scripts/drake_armor.gd")
const DrakeHead = preload("res://assets/drake-head.png")
func configure(value: int,variant := false) -> void:
	if index != value or drake != variant:
		index = value
		drake = variant
		mesh_key = index+(100 if drake else 0)
		if not meshes.has(mesh_key):
			var baker := Baker.new()
			(Drake.new() if drake else Armor.new()).paint(baker,index,Color.WHITE)
			# Shape the chest and lower thigh without widening the hip socket.
			for i in baker.vertices.size():
				var vertex: Vector3 = baker.vertices[i]
				if index == 1:
					vertex.x *= lerpf(0.90,1.0,clampf(vertex.y/65.0,0,1))
				elif index == 6:
					vertex.x *= 1.0+0.16*smoothstep(15.0,65.0,vertex.y)
				baker.vertices[i] = vertex
			if drake:
				for i in baker.colors.size():
					var c: Color = baker.colors[i]
					if c.r>c.g*1.4 and c.g>c.b*1.3:
						baker.colors[i] = Color(c.r,c.g*0.45,c.r,c.a)
					elif c.b>c.r and c.g>c.r:
						var light := c.v
						baker.colors[i] = Color(light*0.78,light*0.58,light*0.81,c.a)
			meshes[mesh_key] = baker.build()
		queue_redraw()
func _draw() -> void:
	if drake and index==0:
		draw_texture_rect_region(DrakeHead,Rect2(-54,-8,108,108),Rect2(55,115,1100,1035))
	else:
		draw_mesh(meshes[mesh_key],null)
