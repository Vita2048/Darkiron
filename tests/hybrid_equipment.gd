extends SceneTree
var game: Node2D
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool,label: String) -> void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures += 1
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview-hybrid-"+label+".png")
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(15)
	game.set_process(false)
	game.set_physics_process(false)
	game.ui.visible = false
	for e in game.enemies: e.set_physics_process(false)
	var hero = game.player
	var drake = game.enemies[0]
	hero.set_physics_process(false)
	hero.rig.procedural_override = true
	hero.position = Vector2(700,720)
	hero.velocity = Vector2.ZERO
	hero.facing = 1
	drake.position = Vector2(1010,720)
	drake.velocity = Vector2.ZERO
	drake.facing = -1
	game.camera_x = 500
	game.camera.position = Vector2(850,625)
	game.camera.zoom = Vector2(3.1,3.1)
	await frames(20)
	await capture("equipment")
	var hero_head := false
	var hero_gun := false
	var enemy_gun := false
	for part in hero.rig.parts:
		if part.visible and part.index==0: hero_head = part.hero
		if part.visible and part.index==2: hero_gun = part.hero
	for part in drake.rig.parts:
		if part.visible and part.index==2: enemy_gun = part.drake
	check(hero_head and hero_gun and enemy_gun,"hero head and both rifles use their matching hybrid assets")
	check(not game.enemies[1].drake,"other guard variants remain unchanged")
	hero.recoil = 1
	drake.recoil = 1
	await frames(3)
	await capture("recoil")
	hero.recoil = 0
	drake.recoil = 0
	hero.facing = -1
	drake.facing = 1
	await frames(4)
	await capture("turned")
	hero.in_cover = true
	drake.in_cover = true
	await frames(20)
	await capture("cover")
	hero.in_cover = false
	drake.in_cover = false
	hero.weapon_drawn = false
	hero.weapon_blend = 0
	await frames(20)
	await capture("sheathed")
	hero.weapon_drawn = true
	hero.weapon_blend = 1
	hero.take_damage(1000)
	drake.take_damage(1000)
	hero.set_physics_process(true)
	drake.set_physics_process(true)
	await frames(100)
	await capture("dropped")
	check(is_instance_valid(hero.dropped_weapon) and hero.dropped_weapon.hero and hero.dropped_weapon.settled,"hero drops matching raster rifle")
	check(is_instance_valid(drake.dropped_weapon) and drake.dropped_weapon.drake and drake.dropped_weapon.settled,"enemy drops matching raster rifle")
	print("HYBRID EQUIPMENT FAILURES: ",failures)
	game.queue_free()
	await frames(3)
	quit(failures)
