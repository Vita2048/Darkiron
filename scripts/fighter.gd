extends CharacterBody2D

const Rig = preload("res://scripts/rig.gd")
var enemy := false
var health := 100.0
var facing := 1.0
var climbing := false
var crouching := false
var in_cover := false
var weapon_drawn := true
var weapon_blend := 1.0
var weapon_transition := 0.0
var running := false
var cooldown := 0.0
var hurt_flash := 0.0
var recoil := 0.0
var gait := 0.0
var dead_time := 0.0
var dropped_weapon: Node2D
var coyote := 0.0
var jump_buffer := 0.0
var world: Node2D
var rig: Node2D
var patrol_origin := 0.0
var ai_clock := 0.0

func _ready() -> void:
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 18
	capsule.height = 138
	shape.shape = capsule
	shape.position = Vector2(0, -69)
	add_child(shape)
	collision_layer = 2 if enemy else 4
	collision_mask = 1
	rig = Rig.new()
	rig.fighter = self
	add_child(rig)
	patrol_origin = position.x
	if enemy:
		health = 75
		facing = -1
		cooldown = 1.4
		modulate = Color(0.77, 0.95, 1.0)

func _physics_process(dt: float) -> void:
	cooldown = maxf(0, cooldown - dt)
	hurt_flash = maxf(0, hurt_flash - dt)
	recoil = move_toward(recoil, 0, dt * 7)
	if health <= 0:
		dead_time += dt
		velocity.x = move_toward(velocity.x, 0, dt * 500)
		velocity.y += 1400 * dt
		move_and_slide()
		rig.queue_redraw()
		return
	if world.completed or world.paused:
		rig.queue_redraw()
		return
	weapon_transition = maxf(0, weapon_transition - dt)
	weapon_blend = move_toward(weapon_blend, 1.0 if weapon_drawn else 0.0, dt / 0.28)
	if enemy:
		_update_enemy(dt)
	else:
		_update_player(dt)
	if not climbing:
		velocity.y = minf(velocity.y + 1450 * dt, 900)
	var before_move := position
	move_and_slide()
	if is_on_floor() and absf(velocity.x) > 10:
		gait += absf(position.x-before_move.x) / (Rig.RUN_DISTANCE_PER_RADIAN if running else 35.0)
	elif climbing:
		gait += velocity.y * dt / 25
	else:
		gait = lerpf(gait, roundf(gait / PI) * PI, dt * 8)
	if position.y > 1050:
		take_damage(1000)
	rig.queue_redraw()

func _update_player(dt: float) -> void:
	var direction := Input.get_axis("left", "right")
	if Input.is_action_just_pressed("toggle_weapon") and weapon_transition <= 0 and not climbing:
		weapon_drawn = not weapon_drawn
		weapon_transition = 0.28
	var near_ladder: bool = absf(position.x - world.LADDER_X) < 40 and position.y >= 470 and position.y <= 733
	in_cover = Input.is_action_pressed("up") and is_on_floor() and not climbing and not near_ladder
	crouching = Input.is_action_pressed("down") and is_on_floor() and not climbing
	running = Input.is_action_pressed("run") and direction != 0 and not crouching and not in_cover and not climbing
	var speed := 330.0 if running else 210.0
	if crouching:
		speed = 70
	velocity.x = move_toward(velocity.x, direction * speed, dt * 1600)
	if in_cover:
		velocity.x = 0
	if direction != 0 and not in_cover:
		facing = signf(direction)
	coyote = 0.12 if is_on_floor() else maxf(0, coyote - dt)
	jump_buffer = 0.14 if Input.is_action_just_pressed("jump") else maxf(0, jump_buffer - dt)
	if near_ladder and not weapon_drawn and weapon_transition <= 0 and (Input.is_action_pressed("up") or (Input.is_action_pressed("down") and position.y < 530)):
		climbing = true
		collision_mask = 0
	if climbing:
		position.x = move_toward(position.x, world.LADDER_X, 260 * dt)
		velocity = Vector2(0, Input.get_axis("up", "down") * 145)
		if position.y <= 480 and velocity.y < 0:
			position.y = 479
			_end_climb()
		elif position.y >= 720 and velocity.y > 0:
			position.y = 720
			_end_climb()
		if Input.is_action_just_pressed("jump"):
			_end_climb()
			velocity = Vector2(direction * 230, -430)
	elif jump_buffer > 0 and coyote > 0 and not crouching and not in_cover:
		velocity.y = -570
		jump_buffer = 0
		coyote = 0
		world.sound("jump")
	if Input.is_action_just_released("jump") and velocity.y < -220:
		velocity.y = -220
	if Input.is_action_pressed("shoot") and cooldown <= 0 and can_fire():
		fire()
	if Input.is_action_just_pressed("grenade") and not climbing and not in_cover and weapon_transition <= 0:
		world.throw_grenade(self)

func can_fire() -> bool:
	return health > 0 and weapon_drawn and weapon_transition <= 0 and not climbing and not in_cover

func _end_climb() -> void:
	climbing = false
	collision_mask = 1
	velocity.y = 0

func _update_enemy(dt: float) -> void:
	ai_clock += dt
	var delta: Vector2 = world.player.position - position
	var visible: bool = absf(delta.x) < 520 and absf(delta.y) < 85 and world.player.health > 0
	if visible:
		facing = signf(delta.x)
		velocity.x = move_toward(velocity.x, 0, dt * 500)
		if cooldown <= 0:
			fire()
	else:
		velocity.x = sin(ai_clock * 0.6) * 40
		if absf(velocity.x) > 5:
			facing = signf(velocity.x)

func muzzle() -> Vector2:
	var standing_lift: float = rig.stand_weight * (rig.standing_height()-76.0)
	if is_on_floor() and not crouching and not climbing and not in_cover:
		standing_lift = rig.gait_height(gait)-76.0
	return position + Vector2(facing * 78, -99 - standing_lift + (29 if crouching else 0))

func fire() -> void:
	if not can_fire():
		return
	cooldown = 1.75 if enemy else 0.42
	recoil = 1
	world.fire_bullet(self)

func take_damage(amount: float) -> void:
	if health <= 0:
		return
	health = maxf(0, health - amount)
	hurt_flash = 0.15
	world.burst(position + Vector2(0, -80), Color("ff9b56"), 12)
	if not enemy:
		world.shake = 5
		world.sound("hurt")
	if health <= 0:
		dropped_weapon = preload("res://scripts/dropped_weapon.gd").new()
		dropped_weapon.world = world
		dropped_weapon.position = position + Vector2(facing*35,-115)
		dropped_weapon.velocity = Vector2(facing*110,-150)
		dropped_weapon.scale.x = facing
		world.add_child(dropped_weapon)
		weapon_drawn = false
		weapon_blend = 0
		recoil = 0
		climbing = false
		in_cover = false
		collision_mask = 1
		world.sound("fall")
		if enemy:
			world.kills += 1

