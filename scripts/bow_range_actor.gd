extends "res://scripts/fighter.gd"
## Stationary range actor; deliberately bypasses combat AI and gun damage/death drops.
## bow_angle / bow_charge are inherited from fighter.gd; this range still aims its bow.

func _ready() -> void:
	super._ready()
	rig.free()
	rig = preload("res://scripts/bow_range_rig.gd").new()
	rig.fighter = self
	add_child(rig)
	weapon_drawn = false
	weapon_blend = 0

func _update_player(_dt: float) -> void:
	velocity.x = 0

func _update_enemy(_dt: float) -> void:
	velocity.x = 0

func take_damage(amount: float, _hit_color := Color("44ccff")) -> void:
	if health <= 0: return
	health = maxf(0, health - amount)
	hurt_flash = 0.15
	if health <= 0 and enemy:
		world.kills += 1

func _physics_process(dt: float) -> void:
	if world.paused: return
	super._physics_process(dt)

