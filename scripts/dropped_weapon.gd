extends Node2D
var world: Node2D
var velocity := Vector2.ZERO
var settled := false
func _ready() -> void:
	var art := preload("res://scripts/vector_part.gd").new()
	art.configure(2)
	art.scale = Vector2(0.99,0.29)
	add_child(art)
func _physics_process(dt: float) -> void:
	if settled or world.paused:
		return
	var previous := position
	velocity.y += 1100*dt
	position += velocity*dt
	rotation += dt*5
	for platform in world.platforms:
		if position.x >= platform.position.x and position.x <= platform.end.x and previous.y <= platform.position.y-8 and position.y >= platform.position.y-8:
			position.y = platform.position.y-8
			rotation = 0
			settled = true
			break
