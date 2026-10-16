extends SceneTree
var game: Node2D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func hit(at: Vector2) -> void:
	game.arrows.append({"p":at-Vector2(80,0),"v":Vector2(10000,0),"life":1.0,"stuck":false})
	await frames(2)
func run() -> void:
	game = load("res://debug_bow.tscn").instantiate()
	root.add_child(game)
	game.set_process_input(false)
	await frames(100)
	assert(game.target.health == 75 and game.player.health == 100)
	assert(game.target.position.distance_to(Vector2(850,720)) < 2)
	for i in 3:
		await hit(game.head_rect().get_center())
		assert(is_equal_approx(game.target.health,75.0-(i+1)*25))
	assert(game.target.dropped_weapon == null)
	game.reset_target()
	for i in 4:
		await hit(game.body_rect().get_center())
		assert(is_equal_approx(game.target.health,75.0-(i+1)*18.75))
	game.reset_target()
	game.charge = 0
	game.shoot()
	var weak: float = game.arrows[-1].v.length()
	game.charge = 1
	game.shoot()
	assert(is_equal_approx(weak,640))
	assert(is_equal_approx(game.arrows[-1].v.length(),2080))
	game.reset_target()
	await hit(Vector2(850,400))
	assert(game.target.health == 75)
	game.reset_target()
	game.charging = true
	game.drag_start = Vector2(600,500)
	game.drag_angle = 0
	game.update_mouse(Vector2(490,500))
	assert(is_equal_approx(game.charge,0.5))
	assert(is_zero_approx(game.player.bow_angle))
	await frames(10)
	assert(is_equal_approx(game.charge,0.5),"Holding still must not auto-charge")
	game.update_mouse(Vector2(490,450))
	assert(game.player.bow_angle < 0 and is_equal_approx(game.charge,0.5))
	var angle: float = game.player.bow_angle
	game.update_mouse(Vector2(380,450))
	assert(is_equal_approx(game.charge,1) and is_equal_approx(game.player.bow_angle,angle))
	game.update_mouse(Vector2(700,450))
	assert(is_zero_approx(game.charge))
	game.reset_target()
	var bow = game.player.rig.bow
	for aim in [-1.0,-0.5,0.0,0.6]:
		game.player.bow_angle = aim
		var previous_projection := INF
		for i in 11:
			game.player.bow_charge = i/10.0
			var projection: float = bow.draw_elbow().dot(Vector2.from_angle(aim))
			assert(projection <= previous_projection+0.001,"Elbow must travel backwards along draw direction")
			assert(absf(bow.draw_elbow().distance_to(bow.nock())-44) < 0.1,"Forearm length must remain stable")
			previous_projection = projection
	game.player.bow_charge = 0
	if DisplayServer.get_name() != "headless":
		game.set_physics_process(false)
		game.player.bow_angle = -0.14
		game.player.bow_charge = 0.8
		game.charge = 0.8
		game.queue_redraw()
		await frames(5)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview-bow-range.png")
		for pose in [Vector2(0,0),Vector2(-0.75,1),Vector2(0.45,0),Vector2(-0.14,0.8)]:
			game.player.bow_angle = pose.x
			game.player.bow_charge = pose.y
			game.charge = pose.y
			game.queue_redraw()
			await frames(4)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://preview-bow-pose-%s.png" % str(pose.x))
	print("PASS: passive target, swept head/body hits, three/four hit kills, reset, miss, draw speed, no rifle drop")
	quit()






