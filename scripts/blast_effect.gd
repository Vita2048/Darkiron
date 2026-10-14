extends Node2D
## Raptor's 16-frame blended blast and baked flame texture, adapted for side-view ground.
const ATLAS = preload("res://assets/raptor-effects/explosion-atlas.png")
const SMOKE = preload("res://assets/raptor-effects/smoke-atlas.png")
const Flame = preload("res://scripts/raptor_flame_texture.gd")
var world: Node2D
var floor_offset := INF
var age := 0.0
var door_debris := false
var flame: Texture2D
var smoke: CPUParticles2D
var embers: CPUParticles2D
func _ready() -> void:
	z_index = 4
	add_to_group("blast_effects")
	# Bound overlapping emitters during successive detonations.
	var active := get_tree().get_nodes_in_group("blast_effects")
	if active.size()>10: active[0].queue_free()
	flame = Flame.flame_texture()
	if is_finite(floor_offset):
		smoke = CPUParticles2D.new()
		var puff := AtlasTexture.new()
		puff.atlas = SMOKE
		puff.region = Rect2(Vector2(SMOKE.get_width()/4.0,SMOKE.get_height()/4.0),SMOKE.get_size()/4.0)
		smoke.texture = puff
		smoke.amount = 20
		smoke.lifetime = 2.0
		smoke.position = Vector2(0,floor_offset-20)
		smoke.direction = Vector2(0,-1)
		smoke.spread = 20
		smoke.gravity = Vector2(10,-18)
		smoke.initial_velocity_min = 25
		smoke.initial_velocity_max = 45
		smoke.scale_amount_min = 80.0/puff.get_width()
		smoke.scale_amount_max = 130.0/puff.get_width()
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([Color(0.4,0.37,0.33,0),Color(0.45,0.42,0.4,0.25),Color(0.3,0.33,0.38,0)])
		ramp.offsets = PackedFloat32Array([0,0.15,1])
		smoke.color_ramp = ramp
		add_child(smoke)
		embers = CPUParticles2D.new()
		embers.texture = Flame.spark_texture()
		embers.position = Vector2(0,floor_offset-8)
		embers.amount = 18
		embers.lifetime = 1.5
		embers.direction = Vector2.UP
		embers.spread = 35
		embers.gravity = Vector2(12,-12)
		embers.initial_velocity_min = 40
		embers.initial_velocity_max = 100
		embers.scale_amount_min = 0.10
		embers.scale_amount_max = 0.25
		embers.color = Color("ff9c38")
		add_child(embers)
func _process(dt: float) -> void:
	var stopped: bool = world.paused or world.completed
	if smoke:
		smoke.speed_scale = 0 if stopped else 1
		embers.speed_scale = smoke.speed_scale
	if stopped: return
	age += dt
	if smoke:
		smoke.emitting = age<8
		embers.emitting = age<7
	if age>12 or (not is_finite(floor_offset) and age>1.5): queue_free()
	queue_redraw()
func _draw() -> void:
	if is_finite(floor_offset):
		var fade := 1.0-smoothstep(8,12,age)
		draw_set_transform(Vector2(0,floor_offset-2),0,Vector2(1,0.18))
		draw_circle(Vector2.ZERO,65,Color(0.025,0.018,0.015,0.8*fade))
		draw_set_transform(Vector2.ZERO)
		if door_debris:
			for i in 7:
				var at := Vector2(-57+i*18,floor_offset)
				var height := 10.0+(i*7)%15
				var shard := PackedVector2Array([at,at+Vector2(-5,-height*0.6),at+Vector2(8,-height),at+Vector2(22,-4),at+Vector2(18,1)])
				draw_colored_polygon(shard,Color(0.19,0.22,0.25,fade))
				draw_polyline(shard,Color(0.43,0.37,0.28,fade),1.5,true)
				draw_line(at+Vector2(2,-4),at+Vector2(9,-height+3),Color(1,0.35,0.06,fade*(1-smoothstep(5,10,age))),2,true)
		var heat := smoothstep(0.1,0.45,age)*(1-smoothstep(4,8,age))
		for i in 9:
			var x := -48.0+i*12
			var at := Vector2(x,floor_offset-3)
			draw_line(at,at+Vector2(7,-4-i%3),Color(0.8,0.21,0.035,fade),3,true)
			var h := (40+sin(age*9+i*2.7)*12+i%3*14)*heat
			if h>0.1:
				draw_texture_rect(flame,Rect2(at-Vector2(18,h),Vector2(36,h+8)),false,Color(1,1,1,heat))
		draw_texture_rect(world.bullet_glow,Rect2(-85,floor_offset-60,170,85),false,Color(1,0.26,0.035,heat*0.45))
	if age<1.05 and not door_debris:
		var t := age/1.05
		var phase := pow(t,0.72)*15
		var frame := mini(int(phase),14)
		var blend := smoothstep(0,1,phase-frame)
		var size := lerpf(140,330,1-pow(1-t,2.5))
		var opacity := 1-smoothstep(0.65,1,t)
		var cell := ATLAS.get_size()/4.0
		for i in 2:
			var index := frame+i
			var source := Rect2(Vector2(index%4,index/4)*cell,cell)
			draw_texture_rect_region(ATLAS,Rect2(Vector2(-size/2,-size/2),Vector2.ONE*size),source,Color(1,1,1,opacity*(blend if i==1 else 1-blend)))
		if age<0.16:
			draw_texture_rect(world.bullet_glow,Rect2(-120,-120,240,240),false,Color(1,0.85,0.55,(1-age/0.16)*0.9))

