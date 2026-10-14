extends SceneTree
var game: Node2D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview-drake-"+label+".png")
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(15)
	game.set_process(false)
	game.set_physics_process(false)
	game.ui.visible = false
	for e in game.enemies: e.set_physics_process(false)
	game.player.set_physics_process(false)
	var guard = game.enemies[0]
	guard.position = Vector2(825,720)
	guard.velocity = Vector2.ZERO
	guard.facing = -1
	game.camera.position = Vector2(810,627)
	game.camera.zoom = Vector2(4,4)
	await frames(20)
	await capture("idle")
	guard.velocity.x = 155
	guard.gait = 1.2
	await frames(25)
	await capture("stride")
	guard.facing = 1
	guard.gait = 3.5
	await frames(15)
	await capture("turned")
	guard.velocity.x = 0
	guard.in_cover = true
	await frames(20)
	await capture("cover")
	guard.in_cover = false
	guard.set_physics_process(true)
	guard.take_damage(1000)
	await frames(90)
	await capture("fallen")
	var ok: bool = guard.drake and not game.enemies[1].drake and is_instance_valid(guard.dropped_weapon) and guard.dropped_weapon.drake and guard.dropped_weapon.settled
	print("HYBRID ENEMY / DROPPED WEAPON: ","PASS" if ok else "FAIL")
	game.queue_free()
	await frames(3)
	quit(0 if ok else 1)
