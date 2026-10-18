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
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview-"+label+".png")
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(10)
	for e in game.enemies: e.set_physics_process(false)
	var guard = game.enemies[0]
	# Isolate rifle cover on the gallery; the yard now starts with a bow and abyss.
	game.weapons = ["RIFLE"]
	game.player.weapon_kind = "RIFLE"
	game.player.position = Vector2(1450,480)
	game.player.facing = 1
	guard.position = Vector2(1900,480)
	guard.velocity = Vector2.ZERO
	guard.facing = -1
	guard.cover_chance = 1.0
	guard.cover_recovery = 0
	guard.cooldown = 2
	guard.set_physics_process(true)
	await frames(3)
	game.player.fire()
	check(guard.cover_reaction>0 and not guard.in_cover,"incoming shot starts delayed cover reaction")
	await frames(17)
	check(guard.in_cover and not guard.can_fire() and guard.velocity.x==0,"cover stops guard movement and firing")
	var health: float = guard.health
	await frames(8)
	check(guard.health==health,"bullet passes covered enemy without damage")
	await capture("enemy-cover")
	await frames(60)
	check(not guard.in_cover and guard.cooldown>0.2,"guard emerges and returns fire")
	guard.set_physics_process(false)
	guard.cover_reaction = 0
	guard.cover_remaining = 0
	guard.cover_recovery = 0
	guard.cover_chance = 0
	guard.notice_shot(game.player.position)
	check(guard.cover_reaction==0 and guard.cover_recovery>0,"missed reaction leaves guard exposed")
	guard.cover_chance = 0.80
	var successes := 0
	for i in 100:
		guard.cover_recovery = 0
		guard.cover_reaction = 0
		guard.notice_shot(game.player.position)
		if guard.cover_reaction>0: successes += 1
	check(successes>65 and successes<95,"normal chance produces both cover and missed reactions")
	guard.cover_reaction = 0
	guard.cover_recovery = 0
	guard.cover_chance = 1
	guard.notice_shot(guard.position+Vector2(100,0))
	check(guard.cover_reaction==0,"guard does not anticipate shots from behind")
	game.bullets.clear()
	game.player.position = Vector2(1700,480)
	game.player.facing = 1
	guard.position = Vector2(1950,480)
	guard.in_cover = false
	guard.cover_recovery = 3
	game.player.fire()
	await frames(11)
	check(guard.health<health and not get_nodes_in_group("bullet_impacts").is_empty(),"armor hit damages enemy and spawns impact")
	await capture("armor-impact")
	game.paused = true
	var impact = get_nodes_in_group("bullet_impacts")[0]
	var age: float = impact.age
	await frames(10)
	check(impact.age==age,"impact animation respects pause")
	game.paused = false
	await frames(35)
	check(get_nodes_in_group("bullet_impacts").is_empty(),"impact fragments expire")
	game.player.position = Vector2(2000,480)
	game.player.velocity = Vector2.ZERO
	game.player.set_physics_process(false)
	game.camera_x = 1500
	game.player.fire()
	await frames(9)
	check(not get_nodes_in_group("bullet_impacts").is_empty(),"reinforced door produces impact without being destroyed")
	await capture("door-impact")
	check(not game.barriers[0].destroyed,"bullet spark effect preserves explosives-only door")
	print("COVER / IMPACT FAILURES: ",failures)
	game.queue_free()
	await frames(3)
	quit(failures)
