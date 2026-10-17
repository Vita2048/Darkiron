extends CharacterBody2D

const Rig = preload("res://scripts/rig.gd")
const HeroRig = preload("res://scripts/hero_rig.gd")
var enemy := false
var drake := false
var azure := false
# Reversible rendering choice; does not change collision or animation bones.
var hybrid_body := true
var health := 100.0
var facing := 1.0
var climbing := false
var active_ladder := Vector3.ZERO
var crouching := false
var in_cover := false
var weapon_drawn := true
var weapon_blend := 1.0
var weapon_transition := 0.0
var weapon_kind := "RIFLE"
# Plasma bow state: aim tilt (positive looks toward the facing ground) and draw amount.
var bow_angle := -0.08
var bow_charge := 0.0
# Debug-range style drag: hold left mouse to aim, drag left for power, release to fire.
var mouse_charging := false
var drag_start := Vector2.ZERO
var drag_angle := 0.0
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
var cover_pose: Node2D
var skeleton_character: Node2D
var patrol_origin := 0.0
var ai_clock := 0.0
var alert_time := 0.0
var cover_reaction := 0.0
var cover_remaining := 0.0
var cover_recovery := 0.0
var cover_chance := 0.65

func notice_shot(origin: Vector2) -> void:
	if not enemy or health<=0 or not is_on_floor() or in_cover or cover_reaction>0 or cover_recovery>0:
		return
	# A guard must see the attacker; shots from behind still catch him exposed.
	if (origin.x-position.x)*facing<=0: return
	cover_recovery = 1.2
	if world.rng.randf()<cover_chance:
		cover_reaction = world.rng.randf_range(0.12,0.24)


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
	rig = HeroRig.new() if not enemy else Rig.new()
	rig.fighter = self
	rig.cover_pose = cover_pose
	rig.skeleton_character = skeleton_character
	add_child(rig)
	patrol_origin = position.x
	if enemy:
		health = 75
		facing = -1
		cooldown = 1.4
		modulate = Color.WHITE if (drake or azure) else Color(0.77, 0.95, 1.0)

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
		gait += absf(position.x-before_move.x) / (Rig.RUN_DISTANCE_PER_RADIAN if running else Rig.WALK_DISTANCE_PER_RADIAN)
	elif climbing:
		gait += velocity.y * dt / 25
	else:
		gait = lerpf(gait, roundf(gait / PI) * PI, dt * 8)
	if not enemy:
		position.x = clampf(position.x,30,world.LEVEL_END-40)
	if position.y > 1050:
		take_damage(1000)
	rig.queue_redraw()

func _update_player(dt: float) -> void:
	var direction := Input.get_axis("left", "right")
	if Input.is_action_just_pressed("toggle_weapon") and weapon_transition <= 0 and not climbing:
		weapon_drawn = not weapon_drawn
		weapon_transition = 0.28
	if world.has_method("current_weapon"):
		if Input.is_action_just_pressed("weapon_prev"):
			world.select_weapon(-1)
		elif Input.is_action_just_pressed("weapon_next"):
			world.select_weapon(1)
		elif world.weapon_selecting and Input.is_action_just_pressed("weapon_confirm"):
			world.confirm_weapon()
			return
	var candidate: Vector3 = world.ladder_at(position)
	var near_ladder := candidate != Vector3.ZERO
	in_cover = Input.is_action_pressed("up") and is_on_floor() and not climbing and (weapon_drawn or not near_ladder)
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
	if near_ladder and not weapon_drawn and weapon_transition <= 0 and (Input.is_action_pressed("up") or (Input.is_action_pressed("down") and position.y < candidate.y+50)):
		active_ladder = candidate
		climbing = true
		collision_mask = 0
	if climbing:
		position.x = move_toward(position.x, active_ladder.x, 260 * dt)
		velocity = Vector2(0, Input.get_axis("up", "down") * 145)
		if position.y <= active_ladder.y and velocity.y < 0:
			position.y = active_ladder.y-1
			_end_climb()
		elif position.y >= active_ladder.z and velocity.y > 0:
			position.y = active_ladder.z
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
	var bow_gun: bool = world.has_method("current_weapon") and world.current_weapon() == "BOW"
	if bow_gun and weapon_drawn and weapon_transition <= 0 and not climbing and health > 0:
		_update_mouse_bow()
	else:
		mouse_charging = false
		bow_charge = 0
	if bow_gun:
		if Input.is_action_just_pressed("shoot_key") and cooldown <= 0 and can_fire():
			bow_charge = 1.0
			fire()
			bow_charge = 0
	elif Input.is_action_pressed("shoot") and cooldown <= 0 and can_fire():
		fire()
	if Input.is_action_just_pressed("grenade") and not climbing and not in_cover and weapon_transition <= 0:
		world.throw_grenade(self)

func _update_mouse_bow() -> void:
	# Cover resets the drag like debug_drones; aim follows the mouse otherwise.
	if in_cover or world.weapon_selecting:
		mouse_charging = false
		bow_charge = 0
		return
	var mouse := get_global_mouse_position()
	var origin := position+Vector2(0,-126)
	if mouse_charging:
		bow_angle = clampf(drag_angle+(mouse.y-drag_start.y)*0.0035,-1.0,0.6)
		bow_charge = clampf((drag_start.x-mouse.x)/220.0,0,1)
	else:
		bow_angle = clampf((mouse.y-origin.y)*0.0035,-1.0,0.6)
		bow_charge = 0
	var pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if pressed and not mouse_charging:
		mouse_charging = true
		drag_start = mouse
		drag_angle = bow_angle
	elif not pressed and mouse_charging:
		mouse_charging = false
		if cooldown <= 0 and can_fire():
			fire()
		bow_charge = 0

func can_fire() -> bool:
	if health <= 0 or not weapon_drawn or weapon_transition > 0 or climbing or in_cover:
		return false
	if world.has_method("current_weapon") and world.weapon_selecting:
		return false
	return true

func _end_climb() -> void:
	climbing = false
	collision_mask = 1
	velocity.y = 0

func _update_enemy(dt: float) -> void:
	ai_clock += dt
	cover_recovery = maxf(0,cover_recovery-dt)
	if world.player.health<=0:
		cover_reaction = 0
		cover_remaining = 0
		in_cover = false
	if cover_reaction>0:
		cover_reaction = maxf(0,cover_reaction-dt)
		if cover_reaction<=0 and is_on_floor():
			cover_remaining = world.rng.randf_range(0.45,0.85)
			in_cover = true
	if in_cover:
		cover_remaining = maxf(0,cover_remaining-dt)
		velocity.x = 0
		if cover_remaining>0: return
		in_cover = false
		cover_recovery = 1.2
		cooldown = minf(cooldown,0.12)

	var delta: Vector2 = world.player.position-position
	var sight: bool = absf(delta.y)<85 and absf(delta.x)<650 and world.player.health>0
	for barrier in world.barriers:
		if not barrier.destroyed and Geometry2D.segment_intersects_segment(position+Vector2(0,-100),world.player.position+Vector2(0,-100),barrier.rect.position,Vector2(barrier.rect.position.x,barrier.rect.end.y)) != null:
			sight = false
	if sight: alert_time = 8.0
	else: alert_time = maxf(0,alert_time-dt)
	var desired := 0.0
	if alert_time>0 and world.player.health>0:
		if absf(delta.x)>4: facing = signf(delta.x)
		if absf(delta.x)>180: desired = facing*155.0
		if sight and cooldown<=0: fire()
	else:
		desired = sin(ai_clock*0.6)*40
		if absf(desired)>5: facing = signf(desired)
	# Keep pursuit on the current connected platform, including braking distance.
	var safe := false
	var ahead := position+Vector2(signf(desired)*40,0)
	for platform in world.platforms:
		if ahead.x>platform.position.x+8 and ahead.x<platform.end.x-8 and absf(position.y-platform.position.y)<12:
			safe = true
	if not safe: desired = 0
	velocity.x = move_toward(velocity.x,desired,dt*1000)

func muzzle() -> Vector2:
	var standing_lift: float = rig.stand_weight * (rig.standing_height()-76.0)
	if is_on_floor() and not crouching and not climbing and not in_cover:
		standing_lift = rig.gait_height(gait)-76.0
	return position + Vector2(facing * 78, -99 - standing_lift + (29 if crouching else 0))

func fire() -> void:
	if not can_fire():
		return
	if not enemy and world.has_method("current_weapon") and world.current_weapon() == "BOW":
		cooldown = 0.55
		world.fire_arrow(self,bow_charge)
		return
	cooldown = 1.15 if enemy else 0.42
	recoil = 1
	world.fire_bullet(self)

func take_damage(amount: float,hit_color := Color("ff9b56")) -> void:
	if health <= 0:
		return
	health = maxf(0, health - amount)
	hurt_flash = 0.15
	if enemy and health>0:
		var toward: float = world.player.position.x-position.x
		if alert_time<=0 or toward*facing<0: cooldown = minf(cooldown,0.08)
		if absf(toward)>1: facing = signf(toward)
		alert_time = 8.0
	world.burst(position + Vector2(0, -80), hit_color, 12)
	if not enemy:
		world.shake = 5
		world.sound("hurt")
	if health <= 0:
		dropped_weapon = preload("res://scripts/dropped_weapon.gd").new()
		dropped_weapon.world = world
		dropped_weapon.drake = drake
		dropped_weapon.azure = azure
		dropped_weapon.hero = not enemy
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
