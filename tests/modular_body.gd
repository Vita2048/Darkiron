extends SceneTree
var game: Node2D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func capture(label: String) -> void:
	game.player.rig.queue_redraw()
	await frames(3)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview-body-"+label+".png")
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(20)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	# Traced SVGs must not bring an opaque canvas into any animated atlas crop.
	var svg = preload("res://scripts/svg_body.gd")
	for texture in [svg.HEAD,svg.TORSO,svg.ARMS,svg.LEGS,svg.RIFLE]:
		assert(texture.get_image().get_pixel(0,0).a == 0,"SVG canvas must be transparent")
	game.set_process(false)
	game.set_physics_process(false)
	game.ui.visible = false
	for actor in [game.player]+game.enemies:
		actor.set_physics_process(false)
		actor.rig.set_process(false)
		actor.rig.procedural_override = true
	for enemy in game.enemies: enemy.visible = false
	var p = game.player
	p.position = Vector2(700,720)
	game.camera_x = 500
	game.camera.position = Vector2(700,625)
	game.camera.zoom = Vector2(4,4)
	p.weapon_drawn = false
	p.weapon_blend = 0
	p.velocity = Vector2(210,0)
	p.rig.move_weight = 1
	p.rig.stand_weight = 0
	for mode in ["walk","run"]:
		p.rig.run_weight = 1 if mode=="run" else 0
		for i in 8:
			p.gait = TAU*i/8.0
			await capture(mode+"-"+str(i))
	p.rig.run_weight = 0
	p.climbing = true
	for i in 2:
		p.gait = PI*0.5+i*PI
		await capture("climb-"+str(i))
	p.climbing = false
	p.velocity = Vector2.ZERO
	p.rig.move_weight = 0
	p.rig.stand_weight = 1
	await capture("idle")
	p.weapon_drawn = true
	p.weapon_blend = 1
	await capture("aim")
	p.recoil = 1
	await capture("recoil")
	p.recoil = 0
	p.facing = -1
	await capture("left")
	p.facing = 1
	p.crouching = true
	p.rig.stand_weight = 0
	await capture("crouch")
	p.crouching = false
	p.in_cover = true
	await capture("cover")
	p.in_cover = false
	p.hybrid_body = false
	await capture("vector-fallback")
	for part in p.rig.parts:
		if not part.visible: continue
		assert(not part.hybrid_body,"Fallback must clear the body variant on every part")
	p.hybrid_body = true
	await capture("restored")
	p.health = 0
	p.dead_time = 0.4
	await capture("death")
	p.health = 100
	p.dead_time = 0
	p.rig.rotation = 0
	p.rig.position.y = 0
	game.camera.zoom = Vector2.ONE
	await capture("gameplay-scale")
	print("PASS: modular body pose captures and reversible vector fallback")
	game.queue_free()
	await frames(3)
	quit()
