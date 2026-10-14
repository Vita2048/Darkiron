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
	game.player.position = Vector2(1100,720)
	guard.position = Vector2(600,720)
	guard.velocity = Vector2.ZERO
	guard.facing = -1
	guard.cooldown = 1
	guard.take_damage(1)
	check(guard.facing==1 and guard.cooldown<=0.08,"hit from behind immediately turns guard and readies shot")
	guard.set_physics_process(true)
	await frames(15)
	check(guard.position.x>610 and guard.cooldown>0.8,"alert guard shoots and pursues")
	game.player.position = Vector2(260,720)
	guard.position = Vector2(565,720)
	await frames(90)
	check(guard.position.x>525 and guard.position.y<725,"pursuit brakes before abyss")
	guard.set_physics_process(false)
	game.player.position = Vector2(467,750)
	game.player.velocity = Vector2.ZERO
	await frames(55)
	check(game.player.health<=0,"abyss is an actual fall hazard")
	game.explode(Vector2(467,760))
	var airborne = get_nodes_in_group("blast_effects")[0]
	check(not is_finite(airborne.floor_offset),"abyss explosions do not leave floating fire")
	await frames(100)
	game.respawn()
	game.player.position = Vector2(3550,720)
	game.player.set_physics_process(false)
	game.camera_x = 3000
	game.explode(Vector2(3610,695))
	await frames(15)
	await capture("raptor-blast")
	var effect = get_nodes_in_group("blast_effects")[0]
	check(is_finite(effect.floor_offset),"burning debris anchors to platform")
	game.paused = true
	var age: float = effect.age
	await frames(15)
	check(effect.age==age,"effects pause with gameplay")
	game.paused = false
	await frames(100)
	await capture("burning-residue")
	check(effect.smoke.emitting,"smoke and embers linger after blast")
	await frames(650)
	check(get_nodes_in_group("blast_effects").is_empty(),"effects expire and release emitters")
	game.player.position = Vector2(2000,480)
	game.camera_x = 1500
	game.explode(Vector2(2110,430))
	var wreckage: Node2D
	for node in get_nodes_in_group("blast_effects"):
		if node.door_debris: wreckage = node
	check(game.barriers[0].destroyed and is_instance_valid(wreckage),"destroyed door creates its own burning wreckage")
	if is_instance_valid(wreckage):
		check(wreckage.position==Vector2(2242.5,480) and wreckage.floor_offset==0,"door fire anchors to door base rather than grenade location")
		await frames(100)
		await capture("door-wreckage")
		check(wreckage.smoke.emitting,"destroyed door debris keeps burning after blast")
	print("UPGRADE FAILURES: ",failures)
	game.queue_free()
	await frames(3)
	quit(failures)

