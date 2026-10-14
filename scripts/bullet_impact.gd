extends Node2D
## Short, bounded impact burst: shared glow texture and ballistic metal sparks.
var world: Node2D
var incoming := Vector2.RIGHT
var energy := Color("59d8ff")
var armor := false
var age := 0.0
var shards: Array[Vector2] = []
func _ready() -> void:
	z_index = 30
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	add_to_group("bullet_impacts")
	var active := get_tree().get_nodes_in_group("bullet_impacts")
	if active.size()>24: active[0].queue_free()
	for i in 12:
		var angle: float = (-incoming).angle()+world.rng.randf_range(-1.35,1.35)
		shards.append(Vector2.from_angle(angle)*world.rng.randf_range(65,260))
func _process(dt: float) -> void:
	if world.paused or world.completed: return
	age += dt
	if age>0.42: queue_free()
	queue_redraw()
func _draw() -> void:
	var fade := 1-age/0.42
	var flash := maxf(0,1-age/0.18)
	var bloom := pow(maxf(0,1-age/0.34),1.7)
	var radius := lerpf(24,58,age/0.42)
	draw_texture_rect(world.bullet_glow,Rect2(-radius,-radius,radius*2,radius*2),false,Color(energy,bloom*0.8))
	draw_texture_rect(world.bullet_glow,Rect2(-18,-28,36,56),false,Color(energy,flash))
	draw_texture_rect(world.bullet_glow,Rect2(-9,-9,18,18),false,Color(0.8+energy.r*0.2,0.8+energy.g*0.2,0.8+energy.b*0.2,flash))
	draw_texture_rect(world.bullet_glow,Rect2(-37,-37,74,74),false,Color(energy,flash*0.9))
	if flash>0:
		draw_line(Vector2(-11,0)*flash,Vector2(11,0)*flash,Color(1,0.97,0.8,flash),2,true)
		draw_line(Vector2(0,-17)*flash,Vector2(0,17)*flash,Color(1,0.97,0.8,flash),2,true)
		draw_circle(Vector2.ZERO,4*flash,Color(1,0.98,0.85,flash))
	for i in shards.size():
		var velocity := shards[i]
		var at := velocity*age+Vector2(0,260*age*age)
		var tint := energy.lerp(Color.WHITE,0.25 if i%3==0 else 0.0)
		draw_line(at-velocity*0.035,at,Color(tint,fade*0.18),5,true)
		draw_line(at-velocity*0.025,at,Color(tint,fade),1.5,true)
		if i%3==0:
			draw_texture_rect(world.bullet_glow,Rect2(at-Vector2(7,7),Vector2(14,14)),false,Color(tint,fade*0.65))
			draw_circle(at,1.2,Color(energy.lerp(Color.WHITE,0.7),fade))

