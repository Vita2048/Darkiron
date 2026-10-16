extends SceneTree
var game: Node2D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func run() -> void:
	game = load("res://debug_drones.tscn").instantiate()
	root.add_child(game)
	game.set_process_input(false)
	game.cover_held = true
	await frames(300)
	assert(game.player.health == 100,"Cover must block live enemy fire")
	assert(game.player.in_cover and not game.player.crouching,"Cover must use the gun stance without extra crouch")
	assert(game.drones[0].position.distance_to(Vector2(730,430)) > 10)
	game.hit_player()
	assert(game.player.health == 100)
	var shots: int = game.shot_count
	game.shoot()
	assert(game.shot_count == shots,"Cannot shoot from cover")
	game.set_physics_process(false)
	game.bolts = [{"p":Vector2(257,610),"v":Vector2(-510,0),"life":2.0}]
	game._physics_process(0.03)
	assert(game.player.health == 100 and game.bolts.size() == 1,"Covered body must not stop incoming fire")
	assert(game.bolts[0].p.x < 252)
	game.bolts = [{"p":Vector2(150,715),"v":Vector2(-80,400),"life":2.0}]
	game._physics_process(0.03)
	assert(game.bolts.is_empty(),"Fireball must be consumed on ground contact")
	var ground_blast := false
	for effect in get_nodes_in_group("blast_effects"):
		if absf(effect.position.y-720) < 0.01: ground_blast = true
	assert(ground_blast,"Ground impact must spawn an explosion at ground height")
	assert(game.player.rig.bow.visible,"Bow stays visible in cover")
	game.set_physics_process(true)
	game.cover_held = false
	game.hit_player()
	assert(game.player.health == 80)
	for i in 4: game.hit_player()
	assert(game.player.health == 0 and game.kills == 0,"Player death must not count as drone kill")
	game.paused = true
	var before: Vector2 = game.drones[0].position
	await frames(10)
	assert(game.drones[0].position == before)
	game.paused = false
	game.reset_target()
	assert(game.player.health == 100 and game.drones.size() == 3 and game.bolts.is_empty())
	game.set_physics_process(false)
	var d = game.drones[0]
	d.position = Vector2(800,500)
	game.arrows.append({"p":Vector2(730,500),"v":Vector2(10000,0),"life":1.0,"stuck":false})
	game._physics_process(0.016)
	assert(d.health == 50,"Swept arrow must hit sensor")
	game.arrows.append({"p":d.position+Vector2(-70,21),"v":Vector2(10000,0),"life":1.0,"stuck":false})
	game._physics_process(0.016)
	assert(d.health == 31.25,"Armor hit must remove a quarter of max health")
	for drone in game.drones: drone.hit(100)
	assert(game.combat_won and game.kills == 3 and game.bolts.is_empty())
	game.reset_target()
	game.cover_held = true
	game.set_physics_process(true)
	await frames(150)
	if DisplayServer.get_name() != "headless":
		game.drones[1].warning = 0.45
		await frames(4)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview-drone-cover.png")
		game.cover_held = false
		game.player.bow_angle = -0.25
		game.charge = 0.8
		game.shoot()
		await frames(8)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview-drone-encounter.png")
		game.set_physics_process(false)
		game.bolts = [{"p":Vector2(520,550),"v":Vector2(-480,130),"life":3.0}]
		game.queue_redraw()
		await frames(3)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview-drone-fireball.png")
		var health_before: float = game.player.health
		game.bolts = [{"p":Vector2(257,610),"v":Vector2(-510,0),"life":1.0}]
		game._physics_process(0.02)
		assert(game.player.health == health_before-20)
		assert(not get_nodes_in_group("blast_effects").is_empty(),"Fireball must create an impact blast")
		await frames(5)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview-drone-fireball-impact.png")
	print("PASS: drone flight, live cover, damage, firing restriction, pause, reset, swept sensor hit, victory")
	quit()




