extends SceneTree
var failures := 0
var game: Node2D
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in count: await physics_frame
func capture(name: String) -> void:
	if not "--visual" in OS.get_cmdline_user_args(): return
	game.camera_x = 1150
	game.camera.position = Vector2(1750,380)
	game.camera.zoom = Vector2(2.4,2.4)
	game.ui.hide()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/drake-"+name+".png")
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	for enemy in game.enemies: enemy.set_physics_process(false)
	for drone in game.drones: drone.health = 0
	game.camera_x = 1150
	game.player.position = Vector2(1500,480)
	var drake = game.enemies[0]
	drake.position = Vector2(1850,480)
	drake.cooldown = 999
	drake.flame_cooldown = 999
	drake.set_physics_process(true)
	await frames(8)
	drake.set_physics_process(false)
	drake.flame_cooldown = 0
	drake._update_enemy(.01)
	check(drake.flame_warning>0 and drake.grenade_warning==0,"Drake telegraphs flame instead of grenade")
	await capture("charge")
	game.player.position.x = 1450 # Moving during wind-up must change release aim.
	drake._update_enemy(drake.FLAME_WINDUP)
	check(game.drone_bolts.size()==1 and game.grenades.is_empty(),"Drake releases a flame ball without a grenade")
	var shot: Dictionary = game.drone_bolts[0]
	check(shot.drake and shot.p.distance_to(drake.mouth_position())<.01,"Flame originates at rendered mouth")
	check(is_equal_approx(shot.aim.x,game.player.head_position().x),"Aim samples Darkiron head at release")
	check(shot.aim.y<=game.player.position.y-135,"Flame aims at head height")
	var release_aim: Vector2 = shot.aim
	game.player.position.x += 35
	game._update_drone_bolts(.1)
	check(shot.aim==release_aim and is_zero_approx(shot.v.cross((release_aim-drake.mouth_position()).normalized())),"Flame does not home after release")
	game.drone_bolts.clear()
	# Test whole projectile flight, cover and crouch from both facing directions.
	for fps in [30,60,120]:
		for side in [-1.0,1.0]:
			for pose in ["standing","cover","crouch","cover_crouch"]:
				game.player.position = Vector2(1700,480)
				game.player.health = 100
				game.player.in_cover = pose in ["cover","cover_crouch"]
				game.player.crouching = pose in ["crouch","cover_crouch"]
				drake.position = Vector2(1700+side*300,480)
				drake.facing = -side
				drake.rig.visible = true
				drake.rig.queue_redraw()
				game.player.rig.queue_redraw()
				await process_frame
				await process_frame
				game.fire_drake_flame(drake)
				for frame in fps*2:
					game._update_drone_bolts(1.0/fps)
				var expected := 100 if game.player.crouching else 70
				check(game.player.health==expected,"Flame %s at %d FPS, side %s" % [pose,fps,side])
				game.drone_bolts.clear()
	game.player.position = Vector2(2000,480)
	game.player.crouching = false
	game.player.in_cover = false
	game.player.health = 100
	drake.position = Vector2(2400,480)
	drake.facing = -1
	drake.rig.queue_redraw()
	await process_frame
	await process_frame
	game.fire_drake_flame(drake)
	for frame in 120: game._update_drone_bolts(1.0/60)
	check(game.player.health==100 and game.drone_bolts.is_empty(),"Solid blast seal stops Drake fire")
	for effect in get_nodes_in_group("blast_effects"): effect.queue_free()
	game.particles.clear()
	game.drone_embers.clear()
	game.drone_damage_flash = 0
	game.player.position = Vector2(1650,480)
	game.player.crouching = true
	game.player.in_cover = false
	game.player.health = 100
	drake.position = Vector2(1900,480)
	drake.facing = -1
	drake.rig.queue_redraw()
	game.player.rig.queue_redraw()
	await process_frame
	await process_frame
	game.fire_drake_flame(drake)
	game._update_drone_bolts(.3)
	await capture("duck")
	game.paused = true
	var at: Vector2 = game.drone_bolts[0].p
	game._physics_process(1)
	check(game.drone_bolts[0].p==at,"Pause freezes flame balls")
	game.paused = false
	game.respawn()
	check(game.drone_bolts.is_empty() and drake.flame_warning==0,"Respawn clears flames and wind-up")
	for enemy in game.enemies:
		check(enemy.cover_chance==.8,"All guards have improved cover chance")
	game.queue_free()
	await process_frame
	print("DRAKE FLAME: ",failures," failures")
	quit(failures)
