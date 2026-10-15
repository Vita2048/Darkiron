extends SceneTree
var game: Node2D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func capture(label: String) -> void:
	game.player.rig.queue_redraw()
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview-joints-"+label+".png")
func run() -> void:
	var art = preload("res://scripts/svg_body.gd")
	for texture in [art.HEAD,art.TORSO,art.ARMS,art.LEGS]:
		assert(texture.get_image().get_pixel(0,0).a == 0,"Body atlas background must remain transparent")
	# Hinge interiors must stay filled (allow antialiased SVG path seams).
	assert(art.ARMS.get_image().get_pixel(1010,198).a > 0.75)
	assert(art.LEGS.get_image().get_pixel(1087,634).a > 0.75)
	game = load("res://debug_movement.tscn").instantiate()
	root.add_child(game)
	await frames(20)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,900)
	game.set_process(false)
	game.set_physics_process(false)
	game.ui_layer.visible = false
	var p = game.player
	p.set_physics_process(false)
	p.rig.set_process(false)
	game.camera.position = p.position+Vector2(0,-90)
	game.camera.zoom = Vector2(4,4)
	p.weapon_drawn = false
	p.weapon_blend = 0
	p.velocity = Vector2(210,0)
	p.rig.move_weight = 1
	p.rig.stand_weight = 0
	for direction in [1,-1]:
		p.facing = direction
		for mode in ["walk","run"]:
			p.rig.run_weight = 1 if mode=="run" else 0
			for i in 4:
				p.gait = TAU*(i*2+1)/8.0
				await capture(mode+"-"+str(direction)+"-"+str(i))
	p.facing = 1
	p.rig.run_weight = 0
	p.rig.move_weight = 0
	p.rig.stand_weight = 1
	p.velocity = Vector2.ZERO
	await capture("idle")
	p.weapon_drawn = true
	p.weapon_blend = 1
	await capture("aim")
	p.weapon_blend = 0
	p.climbing = true
	p.rig.stand_weight = 0
	await capture("climb")
	print("PASS: white-background joint review")
	game.queue_free()
	await frames(3)
	quit()
