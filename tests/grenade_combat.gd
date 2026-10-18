extends SceneTree
var failures := 0
var game: Node2D
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await physics_frame
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func capture(name: String) -> void:
	if not "--visual" in OS.get_cmdline_user_args(): return
	game.camera.position = Vector2(1870,390)
	game.camera_x = 1150
	game.camera.zoom = Vector2(2,2)
	game.ui.hide()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/grenade-"+name+".png")
func settle(guard: CharacterBody2D,at: Vector2) -> void:
	guard.position = at
	guard.velocity = Vector2.ZERO
	guard.health = 75
	guard.dead_time = 0
	guard.weapon_drawn = true
	guard.collision_mask = 1
	guard.cooldown = 999
	guard.grenade_cooldown = 999
	guard.flame_cooldown = 999
	guard.flame_warning = 0
	guard.in_cover = false
	guard.cover_reaction = 0
	guard.cover_remaining = 0
	guard.noticed_grenade = {}
	guard.grenade_reaction = 0
	guard.set_physics_process(true)
	await frames(8)
	guard.set_physics_process(false)
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	for enemy in game.enemies: enemy.set_physics_process(false)
	for drone in game.drones: drone.health = 0
	var red = game.enemies[0]
	var blue = game.enemies[1]
	game.player.position = Vector2(1500,480)
	await settle(blue,Vector2(1850,480))
	blue.grenade_cooldown = 0
	game.grenades_left = 2
	blue._update_enemy(.01)
	check(blue.grenade_warning>0 and game.grenades.is_empty(),"Blue guard warns before throwing")
	await capture("windup")
	blue._update_enemy(blue.GRENADE_WINDUP)
	check(game.grenades.size()==1 and game.grenades[0].enemy,"Blue guard throws hostile grenade")
	check(game.grenades_left==2,"Enemy throw does not consume player bombs")
	check(blue.grenade_cooldown>=8 and blue.grenade_cooldown<=14,"Throw starts cooldown of at least eight seconds")
	game.grenades.clear()
	blue.grenade_cooldown = 8
	blue._update_enemy(7.9)
	check(game.grenades.is_empty() and blue.grenade_warning==0,"No repeat grenade before eight seconds")
	blue._update_enemy(.2)
	check(blue.grenade_warning>0,"New grenade becomes eligible after cooldown")
	var delays: Array[float] = []
	for attempt in 8:
		blue.grenade_warning = 0
		blue.grenade_cooldown = 0
		blue._update_enemy(.01)
		blue._update_enemy(blue.GRENADE_WINDUP)
		delays.append(blue.grenade_cooldown)
		game.grenades.clear()
	check(delays.max()-delays.min()>1 and delays.min()>=8,"Successive grenade delays vary without violating minimum")
	blue.grenade_warning = 0
	blue.grenade_cooldown = 999
	await settle(red,Vector2(1900,480))
	red.grenade_cooldown = 0
	red.flame_cooldown = 999
	red._update_enemy(20)
	check(red.grenade_warning==0 and game.grenades.is_empty(),"Drake never winds up a grenade")
	# An actual thrown projectile must hurt a covered player after its fuse.
	game.player.health = 100
	game.player.in_cover = true
	game.throw_enemy_grenade(blue)
	game.set_physics_process(true)
	await frames(82)
	game.set_physics_process(false)
	check(game.player.health==35,"Enemy grenade arc and explosion damage player through cover")
	game.player.health = 100
	game.explode(game.player.position+Vector2(0,-30),true)
	check(game.player.health==35,"Cover never blocks hostile blast damage")
	game.player.position = Vector2(1400,480)
	game.player.health = 100
	game.explode(Vector2(1850,450),true)
	check(game.player.health==100,"Moving outside blast radius avoids damage")
	check(not game.barriers[0].destroyed,"Hostile blast does not clear demolition objective")
	# A guard can escape a grenade at the edge of its radius after reacting.
	game.grenades.clear()
	for effect in get_nodes_in_group("blast_effects"): effect.queue_free()
	await settle(red,Vector2(1850,480))
	red.in_cover = true
	red.cover_remaining = 5
	var start: float = red.position.x
	game.grenades = [{"p":Vector2(start-90,475),"v":Vector2.ZERO,"fuse":1.45}]
	red.set_physics_process(true)
	game.set_physics_process(true)
	await frames(10)
	check(not red.grenade_fleeing,"Reaction delay prevents instant perfect evasion")
	await frames(38)
	check(red.grenade_fleeing and red.running and not red.in_cover and red.position.x>start+20,"Guard leaves cover and visibly runs from grenade")
	await capture("escape")
	await frames(50)
	red.set_physics_process(false)
	game.set_physics_process(false)
	check(red.health==75,"Early peripheral grenade can be escaped")
	# A close late-fuse bomb still kills, including a guard trying to hide.
	game.grenades.clear()
	await settle(red,Vector2(1850,480))
	red.in_cover = true
	red.cover_remaining = 5
	game.grenades = [{"p":red.position+Vector2(0,-5),"v":Vector2.ZERO,"fuse":.25}]
	red.set_physics_process(true)
	game.set_physics_process(true)
	await frames(22)
	game.set_physics_process(false)
	red.set_physics_process(false)
	check(red.health==0,"Well-placed late-fuse player bomb kills covered guard")
	# Edge safety limits escape instead of giving immunity or jumping into abyss.
	game.grenades.clear()
	await settle(blue,Vector2(1180,480))
	game.grenades = [{"p":Vector2(1230,475),"v":Vector2.ZERO,"fuse":1.45}]
	blue.set_physics_process(true)
	game.set_physics_process(true)
	await frames(100)
	game.set_physics_process(false)
	blue.set_physics_process(false)
	check(blue.health==0 and blue.position.x>=1160,"Trapped guard stays on platform and can be bombed")
	game.player.health = 100
	game.grenades.clear()
	await settle(blue,Vector2(1800,480))
	game.grenades = [{"p":Vector2(1770,475),"v":Vector2.ZERO,"fuse":1.45}]
	game.paused = true
	var fuse: float = game.grenades[0].fuse
	game._physics_process(1)
	check(game.grenades[0].fuse==fuse,"Pause freezes grenade fuse")
	game.paused = false
	game.respawn()
	check(game.grenades.is_empty() and red.grenade_warning==0 and red.grenade_cooldown>=8 and red.flame_cooldown==15,"Recovery clears bombs and resets throw timers")
	game.queue_free()
	await process_frame
	print("GRENADE COMBAT: ",failures," failures")
	quit(failures)
