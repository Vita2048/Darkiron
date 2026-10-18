extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): freeze(child)
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	freeze(game)
	for hunter in game.drones:
		hunter.advance(4.0)
	var drone = game.drones[0]
	for other in game.drones.slice(1): other.health = 0
	for side in [-1.0,1.0]:
		drone.position = Vector2(700,480)
		game.player.position = Vector2(250 if side < 0 else 1000,720)
		drone.warning = .01
		game.drone_bolts.clear()
		drone.advance(.02)
		check(drone.facing == -side,"Drone faces player on either side of abyss")
		check(game.drone_bolts.size() == 1,"Wind-up fires on both sides")
		var bolt: Dictionary = game.drone_bolts[-1]
		check(signf(bolt.v.x) == side,"Fireball travels toward player")
		var target: Vector2 = game.player.position+Vector2(0,-110)
		var travel: float = absf(target.x-bolt.p.x)/absf(bolt.v.x)
		check((bolt.p+bolt.v*travel+Vector2(0,.5*game.DRONE_BOLT_GRAVITY*travel*travel)).distance_to(target)<.01,"Fireball ballistic trajectory reaches target")
		var start: Vector2 = drone.position
		for i in 60: drone.advance(1.0/60)
		check((drone.position.x-start.x)*side < -30,"Drone retreats away from player within visible space on both banks")
		# Shoot straight into the sensor using the drone's mirrored/rotated space.
		drone.health = 75
		var from: Vector2 = drone.to_global(Vector2(-100,3))
		var to: Vector2 = drone.to_global(Vector2(10,3))
		game.arrows = [{"p":from,"v":(to-from)/.01,"life":5.0,"stuck":false}]
		game._update_arrows(.01)
		check(is_equal_approx(drone.health,50),"Sensor takes critical damage facing either way")
		check(game.arrows.is_empty(),"Impact consumes arrow")
		var effects := get_nodes_in_group("drone_arrow_impacts")
		check(not effects.is_empty() and effects[-1].critical,"Sensor creates enhanced plasma effect")
		check(drone.knockback.length()>0,"Impact knocks drone back")
		for effect in effects:
			effect._process(.8)
		await process_frame
		check(get_nodes_in_group("drone_arrow_impacts").is_empty(),"Impact effects clean themselves up")
	# Settle at the original long firing distance, then leave the open yard.
	for i in 240: drone.advance(1.0/60)
	check(absf(drone.position.x-game.player.position.x)>300,"Drone keeps firing distance within visible space")
	# Follow a crossing with the same scrolling camera as gameplay, for all slots.
	for hunter in game.drones:
		hunter.health = 75
		hunter.position = Vector2(760+hunter.slot*120,470+hunter.slot*60)
	game.camera_x = 0
	for frame in 360:
		game.player.position.x = lerpf(525,1140,minf(1,frame/240.0))
		game.camera_x = lerpf(game.camera_x,maxf(0,game.player.position.x-500),1-exp(-4.0/60))
		for hunter in game.drones:
			hunter.advance(1.0/60)
			check(hunter.position.x-game.camera_x>=84.9,"Whole drone remains inside left screen edge during crossing")
			check(hunter.position.x<=1080,"Visible drone stays in open yard")
	for hunter in game.drones:
		check(hunter.position.x<game.player.position.x-200,"Drone retains spacing on left of player")
		check(hunter.position.y<470+hunter.slot*62,"Drone flies higher when horizontal space is restricted")
	game.player.position.x = 1800
	game.drone_bolts.clear()
	for i in 300: drone.advance(1.0/60)
	check(drone.position.x<=1080 and drone.position.x>=80,"Drone stays before the overhead platforms")
	check(game.drone_bolts.is_empty(),"Drone stops engaging outside starting yard")
	if "--visual" in OS.get_cmdline_user_args():
		game.ui.hide()
		drone.health = 75
		drone.position = Vector2(600,480)
		drone.scale.x = -1
		drone.rotation = 0
		drone.flash = .18
		drone.queue_redraw()
		game.camera.position = drone.position
		game.camera.zoom = Vector2(5,5)
		var effect = load("res://scripts/drone_arrow_impact.gd").new()
		effect.world = game
		effect.position = drone.to_global(Vector2(-50,3))
		effect.incoming = Vector2.LEFT
		effect.critical = true
		game.add_child(effect)
		effect.set_process(false)
		effect.age = .08
		effect.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/drone-arrow-impact.png")
	game.queue_free()
	await process_frame
	print("PLATFORM DRONE COMBAT: ",failures," failures")
	quit(failures)

