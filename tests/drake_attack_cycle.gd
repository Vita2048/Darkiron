extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in count: await physics_frame
func run() -> void:
	for fps in [30,60,120]:
		var game = load("res://main.tscn").instantiate()
		root.add_child(game)
		game.set_process(false)
		game.set_physics_process(false)
		game.player.set_physics_process(false)
		for enemy in game.enemies: enemy.set_physics_process(false)
		for drone in game.drones: drone.health = 0
		game.camera_x = 1150
		game.player.position = Vector2(1500,480)
		game.player.in_cover = true
		var red = game.enemies[0]
		red.position = Vector2(1850,480)
		red.cooldown = 999
		red.flame_cooldown = 999
		red.set_physics_process(true)
		await frames(8)
		red.set_physics_process(false)
		red.cooldown = 0
		red.flame_cooldown = 0
		game.fire_bullet(red)
		game.fire_drake_flame(red)
		check(game.drone_bolts.is_empty(),"Direct flame call cannot overlap existing rifle round")
		var flame_count := 0
		var rifle_count := 0
		var last_flame_clear := -10.0
		var last_rifle_clear := -10.0
		var saw_flame := false
		for frame in fps*32:
			var t: float = float(frame)/fps
			var old_bullets: int = game.bullets.size()
			var old_flames: int = game.drone_bolts.size()
			red.cooldown = maxf(0,red.cooldown-1.0/fps)
			red._update_enemy(1.0/fps)
			if game.bullets.size()>old_bullets:
				rifle_count += 1
				if saw_flame:
					check(t-last_flame_clear>=red.ATTACK_SWITCH_GRACE-.04,"Safe switch gap before rifle resumes at %d FPS" % fps)
			if game.drone_bolts.size()>old_flames:
				flame_count += 1
				saw_flame = true
				check(t-last_rifle_clear>=red.ATTACK_SWITCH_GRACE+red.FLAME_WINDUP-.05,"Rifle clears before flame warning/release at %d FPS" % fps)
			var rifle_active: bool = game.drake_projectiles_active(red,false)
			var flame_active: bool = game.drake_projectiles_active(red,true)
			check(not (rifle_active and flame_active),"No overlapping rifle/fireball threats at %d FPS" % fps)
			if flame_active or red.flame_warning>0:
				check(not red.can_fire(),"Rifle disabled during flame charge and flight")
				var before: int = game.bullets.size()
				game.fire_bullet(red)
				check(game.bullets.size()==before,"Direct rifle call also respects flame lock")
			game._physics_process(1.0/fps)
			if rifle_active and not game.drake_projectiles_active(red,false): last_rifle_clear = t
			if flame_active and not game.drake_projectiles_active(red,true): last_flame_clear = t
		check(flame_count>=2 and rifle_count>=5,"Drake retains both attack types across multiple cycles")
		# Duck after the head-targeted release to evade it, then return to cover.
		game.bullets.clear()
		game.drone_bolts.clear()
		red.rifle_recovery = 0
		red.flame_recovery = 0
		red.flame_warning = 0
		game.player.health = 100
		game.player.in_cover = false
		game.player.crouching = false
		game.player.rig.queue_redraw()
		red.rig.queue_redraw()
		await frames(2)
		game.fire_drake_flame(red)
		game.player.crouching = true
		game.player.rig.queue_redraw()
		await frames(3)
		for frame in fps*2: game._update_drone_bolts(1.0/fps)
		check(game.player.health==100,"Ducking after release dodges the fireball at %d FPS" % fps)
		game.player.in_cover = true
		game.player.crouching = false
		red.flame_recovery = 0
		game.drone_bolts.clear()
		game.fire_bullet(red)
		for frame in fps*2: game._physics_process(1.0/fps)
		check(game.player.health==100,"Returning to cover avoids the rifle phase")
		game.respawn()
		check(red.rifle_recovery==0 and red.flame_recovery==0,"Respawn resets attack switching")
		game.queue_free()
		await process_frame
	print("DRAKE ATTACK CYCLE: ",failures," failures")
	quit(failures)

